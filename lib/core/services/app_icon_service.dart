import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_storage_keys.dart';
import '../models/app_icon_option.dart';

/// Service responsible for managing dynamic launcher app icons.
class AppIconService {
  final SharedPreferences? _prefs;

  AppIconService([this._prefs]);

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Checks if the current device/platform supports alternate app icons.
  Future<bool> get supportsAlternateIcons async {
    try {
      if (kIsWeb) return false;
      return await FlutterDynamicIconPlus.supportsAlternateIcons;
    } catch (e) {
      debugPrint('[AppIconService] supportsAlternateIcons error: $e');
      return false;
    }
  }

  Future<String?> _resolveAndroidAlias(AppIconOption option) async {
    if (option.androidAliasSuffix == null) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      return option.resolvedAndroidAlias(info.packageName);
    } catch (_) {
      return option.androidAliasName;
    }
  }

  /// Retrieves the currently active [AppIconOption].
  Future<AppIconOption> getCurrentIcon() async {
    try {
      final prefs = await _getPrefs();
      final savedId = prefs.getString(AppStorageKeys.selectedAppIcon);
      if (savedId != null) {
        return AppIconOption.fromId(savedId);
      }

      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        final platformName = await FlutterDynamicIconPlus.alternateIconName;
        if (platformName == null || platformName.isEmpty) {
          return AppIconOption.defaultIcon;
        }

        // Match against platform names
        for (final opt in AppIconOption.values) {
          if (Platform.isIOS && opt.iosIconName == platformName) {
            return opt;
          } else if (Platform.isAndroid) {
            if (opt.androidAliasName == platformName ||
                (opt.androidAliasSuffix != null &&
                    platformName.endsWith(opt.androidAliasSuffix!))) {
              return opt;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AppIconService] getCurrentIcon error: $e');
    }
    return AppIconOption.defaultIcon;
  }

  /// Changes the app icon to the selected [option].
  Future<bool> setAppIcon(AppIconOption option) async {
    try {
      if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) {
        return false;
      }

      final isSupported = await supportsAlternateIcons;
      if (!isSupported) {
        return false;
      }

      final targetName = Platform.isIOS
          ? option.iosIconName
          : await _resolveAndroidAlias(option);

      await FlutterDynamicIconPlus.setAlternateIconName(
        iconName: targetName,
        blacklistBrands: const ['Redmi'],
        blacklistManufactures: const ['Xiaomi'],
      );

      final prefs = await _getPrefs();
      await prefs.setString(AppStorageKeys.selectedAppIcon, option.id);
      return true;
    } catch (e) {
      debugPrint('[AppIconService] setAppIcon failed: $e');
      return false;
    }
  }
}
