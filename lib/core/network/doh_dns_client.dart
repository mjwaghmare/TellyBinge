import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Pass-through HTTP overrides to ensure DoH resolution queries bypass
/// [AppHttpOverrides] to prevent infinite recursion.
class PassThroughHttpOverrides extends HttpOverrides {}

/// Signature for a custom DoH transport function, primarily used for testing.
typedef DohTransport = Future<String?> Function(String baseUrl, String host);

/// In-app DNS-over-HTTPS (DoH) client.
///
/// Resolves TMDB and Cloudflare Worker domains directly using public DoH providers
/// (Cloudflare 1.1.1.1 and Google 8.8.8.8) to bypass ISP-level DNS poisoning
/// and blackholing on Wi-Fi networks in regions like India.
class DohDnsClient {
  final DohTransport? transport;
  final Duration resolutionTimeout;

  DohDnsClient({
    this.transport,
    this.resolutionTimeout = const Duration(seconds: 4),
  });

  static final DohDnsClient instance = DohDnsClient();

  final Map<String, List<String>> _cache = {};
  final Map<String, DateTime> _cacheExpiry = {};
  final Map<String, Future<List<String>>> _inFlightResolutions = {};

  /// Target domain suffixes that are prone to ISP DNS blocking.
  static const Set<String> _targetSuffixes = {
    'workers.dev',
    'themoviedb.org',
    'tmdb.org',
  };

  /// Upstream DoH resolver endpoints queried directly by IP over HTTPS.
  static const List<String> _dohEndpoints = [
    'https://1.1.1.1/dns-query',
    'https://1.0.0.1/dns-query',
    'https://8.8.8.8/resolve',
    'https://8.8.4.4/resolve',
  ];

  /// Checks whether a given host should be resolved via DoH.
  bool isTargetHost(String host) {
    final lower = host.toLowerCase().trim();
    for (final suffix in _targetSuffixes) {
      if (lower == suffix || lower.endsWith('.$suffix')) {
        return true;
      }
    }
    return false;
  }

  /// Resolves the IPv4 addresses (A records) for [host] via DoH.
  ///
  /// Results are cached in-memory adhering to TTL (defaulting to 5 minutes, max 1 hour).
  /// Concurrent resolutions for the same host are automatically deduplicated.
  /// Enforces [resolutionTimeout] across all upstream attempts, falling back to stale cache on timeout.
  Future<List<String>> resolve(String host) async {
    final cleanHost = host.toLowerCase().trim();
    final now = DateTime.now();

    // Check cache
    if (_cache.containsKey(cleanHost) &&
        _cacheExpiry[cleanHost] != null &&
        now.isBefore(_cacheExpiry[cleanHost]!)) {
      return _cache[cleanHost]!;
    }

    // Deduplicate in-flight resolutions
    if (_inFlightResolutions.containsKey(cleanHost)) {
      return await _inFlightResolutions[cleanHost]!;
    }

    final completer = Completer<List<String>>();
    _inFlightResolutions[cleanHost] = completer.future;

    try {
      final results = await _resolveWithDeadline(cleanHost);
      completer.complete(results);
      return results;
    } catch (e, st) {
      completer.completeError(e, st);
      rethrow;
    } finally {
      final removed = _inFlightResolutions.remove(cleanHost);
      if (removed != null) {
        unawaited(removed);
      }
    }
  }

  Future<List<String>> _resolveWithDeadline(String cleanHost) async {
    final deadline = DateTime.now().add(resolutionTimeout);
    HttpClient? activeHttpClient;
    bool isTimedOut = false;

    // Timer to force-close active HTTP client immediately when deadline expires
    final deadlineTimer = Timer(resolutionTimeout, () {
      isTimedOut = true;
      try {
        activeHttpClient?.close(force: true);
      } catch (_) {}
    });

    try {
      final results = await _resolveFromUpstream(
        cleanHost,
        deadline: deadline,
        isCancelled: () => isTimedOut,
        onClientCreated: (client) => activeHttpClient = client,
      );
      if (results.isNotEmpty) {
        return results;
      }
    } catch (e) {
      debugPrint('[DohDnsClient] Upstream resolution error for $cleanHost: $e');
    } finally {
      deadlineTimer.cancel();
      try {
        activeHttpClient?.close(force: true);
      } catch (_) {}
    }

    // If upstream resolution failed or timed out, fall back to stale cache if available
    if (_cache.containsKey(cleanHost) && _cache[cleanHost]!.isNotEmpty) {
      debugPrint(
        '[DohDnsClient] Using stale DNS cache for $cleanHost as emergency fallback',
      );
      return _cache[cleanHost]!;
    }
    return [];
  }

  Future<List<String>> _resolveFromUpstream(
    String host, {
    required DateTime deadline,
    required bool Function() isCancelled,
    required void Function(HttpClient?) onClientCreated,
  }) async {
    for (final baseUrl in _dohEndpoints) {
      // Stop before starting any later endpoint attempt once deadline expires or resolution is cleared
      if (isCancelled() ||
          DateTime.now().isAfter(deadline) ||
          !_inFlightResolutions.containsKey(host)) {
        debugPrint(
          '[DohDnsClient] Deadline reached or resolution cleared before querying $baseUrl for $host',
        );
        break;
      }

      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        break;
      }

      // Bound attempt timeout to remaining time or 2000ms
      final attemptTimeout = remaining < const Duration(milliseconds: 2000)
          ? remaining
          : const Duration(milliseconds: 2000);

      try {
        final String? body;
        if (transport != null) {
          body = await transport!(baseUrl, host).timeout(attemptTimeout);
        } else {
          final dohClient = HttpOverrides.runWithHttpOverrides(
            () => HttpClient(),
            PassThroughHttpOverrides(),
          );
          onClientCreated(dohClient);

          try {
            dohClient.connectionTimeout = attemptTimeout;
            final uri = Uri.parse('$baseUrl?name=$host&type=A');
            final request = await dohClient.getUrl(uri).timeout(attemptTimeout);
            request.headers.set('Accept', 'application/dns-json');

            final response = await request.close().timeout(attemptTimeout);
            if (response.statusCode == 200) {
              body = await response
                  .transform(utf8.decoder)
                  .join()
                  .timeout(attemptTimeout);
            } else {
              body = null;
            }
          } finally {
            onClientCreated(null);
            dohClient.close(force: true);
          }
        }

        if (body != null) {
          // Prevent timed-out work from updating _cache after deadline or after resolution finished
          if (isCancelled() ||
              DateTime.now().isAfter(deadline) ||
              !_inFlightResolutions.containsKey(host)) {
            debugPrint(
              '[DohDnsClient] Discarding late resolution result for $host after deadline or cancellation',
            );
            return [];
          }

          final json = jsonDecode(body) as Map<String, dynamic>;
          final answers = json['Answer'] as List<dynamic>?;

          if (answers != null && answers.isNotEmpty) {
            final ips = <String>[];
            int minTtl = 300;

            for (final ans in answers) {
              if (ans['type'] == 1 && ans['data'] != null) {
                ips.add(ans['data'] as String);
                final ttl = ans['TTL'] as int?;
                if (ttl != null && ttl > 10 && ttl < minTtl) {
                  minTtl = ttl;
                }
              }
            }

            if (ips.isNotEmpty) {
              // Clamp TTL between 60s and 3600s
              final clampedTtl = minTtl.clamp(60, 3600).toInt();

              // Prevent writing to cache if cancelled, deadline expired, or in-flight cleared
              if (!isCancelled() &&
                  DateTime.now().isBefore(deadline) &&
                  _inFlightResolutions.containsKey(host)) {
                _cache[host] = ips;
                _cacheExpiry[host] =
                    DateTime.now().add(Duration(seconds: clampedTtl));
                debugPrint(
                  '[DohDnsClient] Resolved $host -> $ips (TTL: ${clampedTtl}s via $baseUrl)',
                );
                return ips;
              }
            }
          }
        }
      } catch (e) {
        // Continue to fallback resolver unless deadline has expired or in-flight cleared
        debugPrint('[DohDnsClient] Endpoint $baseUrl failed for $host: $e');
        if (isCancelled() ||
            DateTime.now().isAfter(deadline) ||
            !_inFlightResolutions.containsKey(host)) {
          break;
        }
      }
    }

    debugPrint('[DohDnsClient] All DoH endpoints completed/exhausted for $host');
    return [];
  }

  /// Invalidates cached entries for [host] if a connection failure occurs.
  void invalidate(String host) {
    final cleanHost = host.toLowerCase().trim();
    _cache.remove(cleanHost);
    _cacheExpiry.remove(cleanHost);
  }

  /// Marks the cache for [host] as expired without removing the cached data (for testing stale fallback).
  @visibleForTesting
  void expireCache(String host) {
    final cleanHost = host.toLowerCase().trim();
    if (_cacheExpiry.containsKey(cleanHost)) {
      _cacheExpiry[cleanHost] =
          DateTime.now().subtract(const Duration(minutes: 1));
    }
  }

  /// Clears all cached DNS entries (useful for unit testing).
  @visibleForTesting
  void clearCache() {
    _cache.clear();
    _cacheExpiry.clear();
    _inFlightResolutions.clear();
  }
}
