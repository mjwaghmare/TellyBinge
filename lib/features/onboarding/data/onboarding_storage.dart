import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_storage_keys.dart';

/// Remembers whether the intro carousel has already been shown, so it only ever
/// runs once per install — whether the user skipped it or read it through.
class OnboardingStorage {
  const OnboardingStorage(this._prefs);

  static const String seenKey = AppStorageKeys.hasSeenOnboarding;

  final SharedPreferences _prefs;

  bool get hasSeenOnboarding => _prefs.getBool(seenKey) ?? false;

  /// Writing is fire-and-forget from the caller's point of view: the carousel
  /// dismisses on the same frame either way, and a failed write only costs the
  /// user seeing the intro once more.
  Future<void> markSeen() async {
    try {
      await _prefs.setBool(seenKey, true);
    } catch (e) {
      debugPrint('OnboardingStorage: failed to persist $seenKey: $e');
    }
  }

  Future<void> reset() async {
    try {
      await _prefs.setBool(seenKey, false);
    } catch (e) {
      debugPrint('OnboardingStorage: failed to reset $seenKey: $e');
    }
  }
}
