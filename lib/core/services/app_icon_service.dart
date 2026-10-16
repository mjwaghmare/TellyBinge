import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_storage_keys.dart';
import '../models/app_icon_option.dart';

/// Service responsible for managing dynamic launcher app icons.
///
/// iOS uses flutter_dynamic_icon_plus. Android uses AppIconSwitcher.kt over
/// [_androidChannel], which applies the icon immediately; the plugin only
/// switches on Android once the app is swiped away.
class AppIconService {
  final SharedPreferences? _prefs;

  AppIconService([this._prefs]);

  static const _androidChannel = MethodChannel('com.mwstudio.popverse/app_icon');

  /// Name AppIconSwitcher.kt uses for the default icon, which MainActivity
  /// itself carries on Android.
  static const androidDefaultAlias = 'MainActivity';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Checks if the current device/platform supports alternate app icons.
  Future<bool> get supportsAlternateIcons async {
    try {
      if (kIsWeb) return false;
      if (Platform.isAndroid) return true;
      return await FlutterDynamicIconPlus.supportsAlternateIcons;
    } catch (e) {
      debugPrint('[AppIconService] supportsAlternateIcons error: $e');
      return false;
    }
  }

  /// The launcher entry (simple name) that shows [option] on Android.
  @visibleForTesting
  static String androidAliasFor(AppIconOption option) =>
      option.androidAliasSuffix ?? androidDefaultAlias;

  /// Maps an enabled Android alias back to its option.
  @visibleForTesting
  static AppIconOption optionForAndroidAlias(String? alias) {
    return AppIconOption.values.firstWhere(
      (opt) => alias != null && opt.androidAliasSuffix == alias,
      orElse: () => AppIconOption.defaultIcon,
    );
  }

  /// Retrieves the currently active [AppIconOption].
  Future<AppIconOption> getCurrentIcon() async {
    try {
      // On Android the enabled launcher entry is the truth: the saved choice
      // can be stale if a launcher killed the app mid-switch, or after a
      // backup restore (which restores prefs but not component state).
      if (!kIsWeb && Platform.isAndroid) {
        try {
          return optionForAndroidAlias(await _androidChannel.invokeMethod<String>('currentIcon'));
        } catch (e) {
          debugPrint('[AppIconService] currentIcon channel error: $e');
        }
      }

      // On iOS the active alternate icon name reported by the system is the truth.
      if (!kIsWeb && Platform.isIOS) {
        try {
          final platformName = await FlutterDynamicIconPlus.alternateIconName;
          if (platformName == null) {
            return AppIconOption.defaultIcon;
          }
          for (final opt in AppIconOption.values) {
            if (opt.iosIconName == platformName) return opt;
          }
        } catch (e) {
          debugPrint('[AppIconService] iOS alternateIconName error: $e');
        }
      }

      final prefs = await _getPrefs();
      final savedId = prefs.getString(AppStorageKeys.selectedAppIcon);
      if (savedId != null) {
        return AppIconOption.fromId(savedId);
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

      if (Platform.isAndroid) {
        final applied = await _androidChannel.invokeMethod<bool>(
          'setIcon',
          {'alias': androidAliasFor(option)},
        );
        if (applied != true) return false;
      } else {
        await FlutterDynamicIconPlus.setAlternateIconName(iconName: option.iosIconName);
      }

      final prefs = await _getPrefs();
      await prefs.setString(AppStorageKeys.selectedAppIcon, option.id);
      return true;
    } catch (e) {
      debugPrint('[AppIconService] setAppIcon failed: $e');
      return false;
    }
  }
}
