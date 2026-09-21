import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'doh_dns_client.dart';

/// Global HTTP overrides that route TMDB and Cloudflare Worker requests
/// through in-app DNS-over-HTTPS (DoH).
///
/// Ensures both [Dio] TMDB API calls and [CachedNetworkImage] poster loads
/// succeed seamlessly on Wi-Fi and ISP networks that poison or block
/// `*.workers.dev` and TMDB domains without requiring any user intervention.
class AppHttpOverrides extends HttpOverrides {
  final DohDnsClient _dnsClient;

  AppHttpOverrides({DohDnsClient? dnsClient})
      : _dnsClient = dnsClient ?? DohDnsClient.instance;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    client.connectionFactory =
        (Uri uri, String? proxyHost, int? proxyPort) async {
      // If a system/debugging proxy is active, return raw socket so HttpClient
      // can establish the CONNECT tunnel and handle TLS negotiation natively.
      if (proxyHost != null && proxyHost.isNotEmpty) {
        final targetPort = proxyPort ?? (uri.scheme == 'https' ? 443 : 80);
        Socket? rawSocket;
        try {
          rawSocket = await Socket.connect(
            proxyHost,
            targetPort,
            timeout: const Duration(seconds: 8),
          );
          return ConnectionTask.fromSocket(
            Future.value(rawSocket),
            () => rawSocket?.destroy(),
          );
        } catch (e) {
          rawSocket?.destroy();
          rethrow;
        }
      }

      final isHttps = uri.scheme.toLowerCase() == 'https';
      final port = uri.port == 0 ? (isHttps ? 443 : 80) : uri.port;

      // Only route targeted domains (TMDB API, TMDB images, workers.dev) through DoH
      if (_dnsClient.isTargetHost(uri.host)) {
        final ips = await _dnsClient.resolve(uri.host);
        if (ips.isNotEmpty) {
          for (final ip in ips) {
            Socket? rawSocket;
            try {
              rawSocket = await Socket.connect(
                ip,
                port,
                timeout: const Duration(seconds: 5),
              );

              if (isHttps) {
                final secureSocket = await SecureSocket.secure(
                  rawSocket,
                  host: uri.host, // Crucial for SNI certificate negotiation
                  context: context,
                );
                return ConnectionTask.fromSocket(
                  Future.value(secureSocket),
                  () => secureSocket.destroy(),
                );
              }

              return ConnectionTask.fromSocket(
                Future.value(rawSocket),
                () => rawSocket?.destroy(),
              );
            } catch (e) {
              rawSocket?.destroy();
              debugPrint(
                '[AppHttpOverrides] Connect to $ip for ${uri.host} failed: $e',
              );
            }
          }
          // Invalidate cached DNS only when every resolved IP connection attempt fails
          _dnsClient.invalidate(uri.host);
        }
      }

      // Default connection path (for non-target hosts or as DoH fallback)
      Socket? rawSocket;
      try {
        rawSocket = await Socket.connect(
          uri.host,
          port,
          timeout: const Duration(seconds: 8),
        );

        if (isHttps) {
          final secureSocket = await SecureSocket.secure(
            rawSocket,
            host: uri.host,
            context: context,
          );
          return ConnectionTask.fromSocket(
            Future.value(secureSocket),
            () => secureSocket.destroy(),
          );
        }

        return ConnectionTask.fromSocket(
          Future.value(rawSocket),
          () => rawSocket?.destroy(),
        );
      } catch (e) {
        rawSocket?.destroy();
        rethrow;
      }
    };

    return client;
  }
}
