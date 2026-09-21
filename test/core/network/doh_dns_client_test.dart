import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/network/app_http_overrides.dart';
import 'package:popverse/core/network/doh_dns_client.dart';

void main() {
  group('DohDnsClient Domain Target Filtering', () {
    final client = DohDnsClient.instance;

    test('correctly identifies target hosts', () {
      expect(
        client.isTargetHost(
          'restless-bar-82ccpopverse-tmdb-proxy.mjwaghmare.workers.dev',
        ),
        isTrue,
      );
      expect(client.isTargetHost('api.themoviedb.org'), isTrue);
      expect(client.isTargetHost('image.tmdb.org'), isTrue);
      expect(client.isTargetHost('secure.tmdb.org'), isTrue);
      expect(client.isTargetHost('SOME-WORKER.WORKERS.DEV'), isTrue);
    });

    test('correctly rejects non-target hosts', () {
      expect(client.isTargetHost('www.google.com'), isFalse);
      expect(client.isTargetHost('firebase.googleapis.com'), isFalse);
      expect(client.isTargetHost('res.cloudinary.com'), isFalse);
      expect(client.isTargetHost('apple.com'), isFalse);
    });
  });

  group('DohDnsClient Caching & Fixture Resolution', () {
    test(
      'resolves IPv4 addresses from DoH fixture and caches result',
      () async {
        int transportCallCount = 0;
        final fixtureClient = DohDnsClient(
          transport: (baseUrl, host) async {
            transportCallCount++;
            return '{"Status":0,"Answer":[{"name":"$host","type":1,"TTL":300,"data":"172.67.136.46"},{"name":"$host","type":1,"TTL":300,"data":"104.21.62.135"}]}';
          },
        );

        final ips = await fixtureClient.resolve('image.tmdb.org');
        expect(ips, equals(['172.67.136.46', '104.21.62.135']));
        expect(transportCallCount, equals(1));

        // Second call returns cached IPs without hitting transport
        final cachedIps = await fixtureClient.resolve('image.tmdb.org');
        expect(cachedIps, equals(['172.67.136.46', '104.21.62.135']));
        expect(transportCallCount, equals(1));

        // After invalidation, transport is called again
        fixtureClient.invalidate('image.tmdb.org');
        final freshIps = await fixtureClient.resolve('image.tmdb.org');
        expect(freshIps, equals(['172.67.136.46', '104.21.62.135']));
        expect(transportCallCount, equals(2));
      },
    );

    test('falls back to stale cache when upstream transport fails', () async {
      bool shouldFail = false;
      final fixtureClient = DohDnsClient(
        transport: (baseUrl, host) async {
          if (shouldFail) {
            throw const SocketException('Network offline');
          }
          return '{"Status":0,"Answer":[{"name":"$host","type":1,"TTL":300,"data":"1.2.3.4"}]}';
        },
      );

      // Initial resolution succeeds and populates cache
      final initialIps = await fixtureClient.resolve('image.tmdb.org');
      expect(initialIps, equals(['1.2.3.4']));

      // Simulate cache expiration
      fixtureClient.expireCache('image.tmdb.org');

      // Now upstream fails
      shouldFail = true;

      // Client should fall back to the stale cached IPs rather than returning empty
      final fallbackIps = await fixtureClient.resolve('image.tmdb.org');
      expect(fallbackIps, equals(['1.2.3.4']));
    });

    test(
      'enforces overall resolution deadline and returns stale cache when transport hangs',
      () async {
        final hangingCompleter = Completer<String?>();
        bool shouldHang = false;
        int transportCallCount = 0;

        final client = DohDnsClient(
          resolutionTimeout: const Duration(milliseconds: 100),
          transport: (baseUrl, host) async {
            transportCallCount++;
            if (shouldHang) {
              return await hangingCompleter.future; // Never completes
            }
            return '{"Status":0,"Answer":[{"name":"$host","type":1,"TTL":300,"data":"10.0.0.1"}]}';
          },
        );

        // Populate initial cache
        final initialIps = await client.resolve('image.tmdb.org');
        expect(initialIps, equals(['10.0.0.1']));
        expect(transportCallCount, equals(1));

        // Expire cache
        client.expireCache('image.tmdb.org');

        // Transport now hangs indefinitely
        shouldHang = true;

        final stopwatch = Stopwatch()..start();
        final fallbackIps = await client.resolve('image.tmdb.org');
        stopwatch.stop();

        // Verified bounded execution (< 800ms) and returned stale cached IP
        expect(fallbackIps, equals(['10.0.0.1']));
        expect(stopwatch.elapsedMilliseconds, lessThan(800));

        // Verified that later endpoint attempts (endpoints 2, 3, 4) were NOT started
        expect(transportCallCount, equals(2));
      },
    );

    test(
      'prevents timed-out work from updating cache after resolution finishes or is cleared',
      () async {
        final delayedCompleter = Completer<String?>();
        bool firstCall = true;

        final client = DohDnsClient(
          resolutionTimeout: const Duration(milliseconds: 50),
          transport: (baseUrl, host) async {
            if (firstCall) {
              firstCall = false;
              return await delayedCompleter.future;
            }
            return '{"Status":0,"Answer":[{"name":"$host","type":1,"TTL":300,"data":"2.2.2.2"}]}';
          },
        );

        // First call starts hanging transport and times out after 50ms
        final firstIps = await client.resolve('image.tmdb.org');
        expect(firstIps, isEmpty);

        // Late completion arrives AFTER in-flight resolution was cleared
        delayedCompleter.complete(
          '{"Status":0,"Answer":[{"name":"image.tmdb.org","type":1,"TTL":300,"data":"99.99.99.99"}]}',
        );

        // Allow any pending async turns to finish
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Second call should NOT return late '99.99.99.99' from cache;
        // it should invoke the fresh transport and return '2.2.2.2'.
        final secondIps = await client.resolve('image.tmdb.org');
        expect(secondIps, equals(['2.2.2.2']));
      },
    );
  });

  group('AppHttpOverrides', () {
    test('createHttpClient returns configured HttpClient', () {
      final overrides = AppHttpOverrides();
      final client = overrides.createHttpClient(null);
      expect(client, isNotNull);
      client.close();
    });

    test('invalidates DNS cache when all resolved IPs fail to connect', () async {
      int transportCalls = 0;
      final dohClient = DohDnsClient(
        transport: (baseUrl, host) async {
          transportCalls++;
          return '{"Status":0,"Answer":[{"name":"$host","type":1,"TTL":300,"data":"127.0.0.1"}]}';
        },
      );

      // Populate cache
      final initialIps = await dohClient.resolve('api.themoviedb.org');
      expect(initialIps, equals(['127.0.0.1']));
      expect(transportCalls, equals(1));

      // Second call uses cache
      await dohClient.resolve('api.themoviedb.org');
      expect(transportCalls, equals(1));

      final overrides = AppHttpOverrides(dnsClient: dohClient);
      final httpClient = overrides.createHttpClient(null);

      try {
        // Port 61234 on 127.0.0.1 will immediately refuse connection
        final uri = Uri.parse('http://api.themoviedb.org:61234');
        final request = await httpClient.getUrl(uri);
        await request.close();
      } catch (_) {
        // Connection refused as expected
      } finally {
        httpClient.close();
      }

      // Since all IPs failed, cache was invalidated; next resolve will hit transport
      await dohClient.resolve('api.themoviedb.org');
      expect(transportCalls, equals(2));
    });
  });
}
