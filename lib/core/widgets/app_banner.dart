import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../theme/app_colors.dart';

class AppBanner {
  AppBanner._();

  static bool _isBannerShowing = false;
  static Timer? _autoDismissTimer;

  /// Show banner when device is offline
  static void showOfflineBanner({
    String message = 'No internet connection. Operating in offline mode.',
  }) {
    showNetworkBanner(message: message);
  }

  /// Show banner when network request is slow / timing out
  static void showSlowNetworkBanner({
    String message = 'Slow network connection detected...',
  }) {
    showNetworkBanner(message: message);
  }

  /// Display a yellow MaterialBanner with black text & dismiss action
  static void showNetworkBanner({
    required String message,
    Duration autoDismissDuration = const Duration(seconds: 4),
  }) {
    if (_isBannerShowing) return;
    _isBannerShowing = true;

    scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    scaffoldMessengerKey.currentState?.showMaterialBanner(
      MaterialBanner(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        actions: [
          TextButton(
            onPressed: () {
              hideBanner();
            },
            child: const Text(
              'DISMISS',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );

    // Auto-dismiss after specified duration
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(autoDismissDuration, () {
      hideBanner();
    });
  }

  /// Explicitly hide current material banner
  static void hideBanner() {
    scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    _isBannerShowing = false;
    _autoDismissTimer?.cancel();
  }
}
