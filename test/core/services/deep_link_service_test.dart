import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/services/deep_link_service.dart';

void main() {
  group('DeepLinkService Provider Normalization', () {
    test('normalizes Hotstar ID 122 to JioHotstar', () {
      final name = DeepLinkService.normalizeProviderName(
        122,
        'Disney+ Hotstar',
      );
      expect(name, 'JioHotstar');
    });

    test('normalizes JioCinema ID 220 to JioHotstar', () {
      final name = DeepLinkService.normalizeProviderName(220, 'JioCinema');
      expect(name, 'JioHotstar');
    });

    test('normalizes string name containing hotstar or jiocinema', () {
      expect(
        DeepLinkService.normalizeProviderName(null, 'Hotstar VIP'),
        'JioHotstar',
      );
      expect(
        DeepLinkService.normalizeProviderName(null, 'JioCinema Premium'),
        'JioHotstar',
      );
    });

    test('preserves other provider names', () {
      expect(
        DeepLinkService.normalizeProviderName(8, 'Netflix'),
        'Netflix',
      );
      expect(
        DeepLinkService.normalizeProviderName(9, 'Amazon Prime Video'),
        'Amazon Prime Video',
      );
      expect(
        DeepLinkService.normalizeProviderName(237, 'SonyLIV'),
        'SonyLIV',
      );
    });
  });

  group('DeepLinkService Launching', () {
    test('launchProvider handles empty inputs gracefully without throwing', () async {
      final result = await DeepLinkService.launchProvider(
        providerId: 0,
        providerName: '',
        title: '',
        fallbackWebUrl: null,
      );
      expect(result, isFalse);
    });
  });
}
