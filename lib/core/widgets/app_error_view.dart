import 'package:flutter/material.dart';
import '../constants/app_assets.dart';
import '../errors/failures.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Centralized, premium error view widget used across the application.
/// Displays a stylized illustration, user-friendly error headline,
/// human-readable failure message, and an optional retry action.
class AppErrorView extends StatelessWidget {
  final Failure failure;
  final VoidCallback? onRetry;
  final String? title;
  final String? retryLabel;
  final Widget? image;

  const AppErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.title,
    this.retryLabel,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);

    final errorTitle = title ??
        (failure is NetworkFailure
            ? 'Connection Error'
            : (failure is ServerFailure && failure.code == '404')
                ? 'Item Not Found'
                : 'Oops! Something went wrong');

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.allXXL,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            image ??
                Image.asset(
                  AppAssets.errorDevices,
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
            AppSpacing.gapH32,
            Text(
              errorTitle,
              style: AppTextStyles.lg.copyWith(
                color: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapH12,
            Text(
              failure.message,
              style: AppTextStyles.md.copyWith(
                color: isLight
                    ? AppColors.lightTextSecondary
                    : AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              AppSpacing.gapH32,
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.sm,
                  ),
                ),
                child: Text(
                  retryLabel ?? 'RETRY',
                  style: AppTextStyles.smBold.copyWith(
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
