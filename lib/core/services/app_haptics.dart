import 'package:flutter/services.dart';

/// Centralized haptic feedback service.
///
/// Respects user settings and provides standard haptic feedback patterns
/// across the application. When [isEnabled] is `false`, all feedback calls
/// safely no-op.
abstract final class AppHaptics {
  AppHaptics._();

  /// Whether haptic feedback is currently enabled.
  static bool isEnabled = true;

  /// Provides a subtle light impact vibration.
  static Future<void> lightImpact() async {
    if (isEnabled) {
      await HapticFeedback.lightImpact();
    }
  }

  /// Provides a medium impact vibration.
  static Future<void> mediumImpact() async {
    if (isEnabled) {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Provides a strong heavy impact vibration.
  static Future<void> heavyImpact() async {
    if (isEnabled) {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Provides a selection click feedback (e.g., picker or slider change).
  static Future<void> selectionClick() async {
    if (isEnabled) {
      await HapticFeedback.selectionClick();
    }
  }

  /// Provides a standard vibrate feedback.
  static Future<void> vibrate() async {
    if (isEnabled) {
      await HapticFeedback.vibrate();
    }
  }
}
