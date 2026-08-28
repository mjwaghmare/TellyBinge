import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppSnackbarType {
  info,
  success,
  error,
}

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    required AppSnackbarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      create(
        context,
        message: message,
        type: type,
        duration: duration,
      ),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.info,
      duration: duration,
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.success,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppSnackbarType.error,
      duration: duration,
    );
  }

  static SnackBar create(
    BuildContext context, {
    required String message,
    required AppSnackbarType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    final isLight = AppColors.isLight(context);

    final (Color accentColor, IconData icon) = switch (type) {
      AppSnackbarType.info => (AppColors.primary, Icons.info_outline_rounded),
      AppSnackbarType.success => (
          AppColors.success,
          Icons.check_circle_outline_rounded
        ),
      AppSnackbarType.error => (AppColors.error, Icons.error_outline_rounded),
    };

    return SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isLight ? AppColors.lightSurface : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLight ? AppColors.borderLight : AppColors.borderDark,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: accentColor,
                size: 18,
              ),
            ),
            AppSpacing.gapW12,
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.smMedium.copyWith(
                  color: isLight
                      ? AppColors.lightTextPrimary
                      : AppColors.textPrimary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
