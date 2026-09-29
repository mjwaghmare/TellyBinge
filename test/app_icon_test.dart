import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popverse/core/constants/app_storage_keys.dart';
import 'package:popverse/core/models/app_icon_option.dart';
import 'package:popverse/core/services/app_icon_service.dart';
import 'package:popverse/features/profile/presentation/cubit/app_icon_cubit.dart';
import 'package:popverse/features/profile/presentation/cubit/app_icon_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppIconOption', () {
    test('has exactly 9 icon variants', () {
      expect(AppIconOption.values.length, 9);
    });

    test('has exactly 3 free and 6 premium variants', () {
      final freeIcons = AppIconOption.values.where((o) => !o.isPremium).toList();
      final premiumIcons = AppIconOption.values.where((o) => o.isPremium).toList();

      expect(freeIcons.length, 3);
      expect(premiumIcons.length, 6);

      expect(freeIcons.map((i) => i.id).toSet(), {
        'default',
        'midnight',
        'minimal',
      });

      expect(premiumIcons.map((i) => i.id).toSet(), {
        'neon_pink',
        'golden_luxe',
        'ocean_blue',
        'sunset',
        'holographic',
        'snow_white',
      });
    });

    test('resolves fromId properly with fallback to default', () {
      expect(AppIconOption.fromId('midnight'), AppIconOption.midnight);
      expect(AppIconOption.fromId('golden_luxe'), AppIconOption.goldenLuxe);
      expect(AppIconOption.fromId('unknown_id'), AppIconOption.defaultIcon);
      expect(AppIconOption.fromId(null), AppIconOption.defaultIcon);
    });

    test('all variants have valid preview assets and fully qualified androidAliasName', () {
      for (final option in AppIconOption.values) {
        expect(option.previewAsset, startsWith('assets/images/app_icons/preview_'));
        expect(option.previewAsset, endsWith('.png'));
        if (option != AppIconOption.defaultIcon) {
          expect(option.androidAliasName, startsWith('com.mwstudio.popverse.MainActivity'));
          expect(option.resolvedAndroidAlias('com.example.custom'), startsWith('com.example.custom.MainActivity'));
        }
      }
    });
  });

  group('AppIconService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getCurrentIcon returns default when nothing is saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = AppIconService(prefs);

      final icon = await service.getCurrentIcon();
      expect(icon, AppIconOption.defaultIcon);
    });

    test('getCurrentIcon returns saved icon option', () async {
      SharedPreferences.setMockInitialValues({
        AppStorageKeys.selectedAppIcon: 'midnight',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = AppIconService(prefs);

      final icon = await service.getCurrentIcon();
      expect(icon, AppIconOption.midnight);
    });

    test('setAppIcon returns false when platform is not supported', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = AppIconService(prefs);

      // In macOS test runner without mocks, alternate icons platform calls return false/unsupported
      final result = await service.setAppIcon(AppIconOption.midnight);
      expect(result, isFalse);
      // Preference should not be set when unsupported
      expect(prefs.getString(AppStorageKeys.selectedAppIcon), isNull);
    });
  });

  group('AppIconService Android aliases', () {
    test('every option maps to a manifest alias and back', () {
      for (final option in AppIconOption.values) {
        final alias = AppIconService.androidAliasFor(option);
        expect(alias, startsWith('MainActivity'));
        expect(AppIconService.optionForAndroidAlias(alias), option);
      }
    });

    test('default uses the MainActivityDefault alias', () {
      expect(AppIconService.androidAliasFor(AppIconOption.defaultIcon), AppIconService.androidDefaultAlias);
    });

    test('unknown or missing alias falls back to default', () {
      expect(AppIconService.optionForAndroidAlias(null), AppIconOption.defaultIcon);
      expect(AppIconService.optionForAndroidAlias('Nope'), AppIconOption.defaultIcon);
    });
  });

  group('AppIconCubit', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to isProUser = false', () {
      const state = AppIconState();
      expect(state.isProUser, isFalse);
    });

    test('blocks non-pro users from selecting premium icons', () async {
      final cubit = AppIconCubit(isProUser: false);
      final result = await cubit.selectIcon(AppIconOption.goldenLuxe);

      expect(result, isFalse);
      expect(cubit.state.errorMessage, contains('reserved for Popverse Pro users'));
      await cubit.close();
    });

    test('rejects new selection while isApplying is true', () async {
      final cubit = AppIconCubit(isProUser: true);
      cubit.emit(cubit.state.copyWith(isApplying: true));

      final result = await cubit.selectIcon(AppIconOption.minimal);
      expect(result, isFalse);
      await cubit.close();
    });
  });
}
