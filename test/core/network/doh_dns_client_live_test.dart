import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/network/doh_dns_client.dart';

void main() {
  final bool runIntegrationTests =
      const bool.fromEnvironment('RUN_INTEGRATION_TESTS') ||
          Platform.environment['RUN_INTEGRATION_TESTS'] == 'true';

  group('DohDnsClient Live Network Integration Tests', () {
    test(
      'live DoH resolution against public resolvers returns IPv4 addresses',
      () async {
        final client = DohDnsClient.instance;
        final ips = await client.resolve('image.tmdb.org');
        expect(ips, isNotEmpty);
        expect(
          ips.first,
          matches(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'),
        );
      },
      skip: runIntegrationTests
          ? false
          : 'Opt-in required via RUN_INTEGRATION_TESTS=true',
    );
  });
}
