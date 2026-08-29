import 'package:flutter/material.dart';
import '../models/app_version_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppVersionInfo versionInfo;
  final String installedVersion;
  final bool isForceUpdate;
  final VoidCallback onUpdate;
  final VoidCallback? onLater;

  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.installedVersion,
    required this.isForceUpdate,
    required this.onUpdate,
    this.onLater,
  });

  static Future<void> show(
    BuildContext context, {
    required AppVersionInfo versionInfo,
    required String installedVersion,
    required bool isForceUpdate,
    required VoidCallback onUpdate,
    VoidCallback? onLater,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (dialogContext) {
        return AppUpdateDialog(
          versionInfo: versionInfo,
          installedVersion: installedVersion,
          isForceUpdate: isForceUpdate,
          onUpdate: onUpdate,
          onLater: () {
            Navigator.of(dialogContext, rootNavigator: true).pop();
            onLater?.call();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);

    final cardBg = isLight ? AppColors.lightSurface : AppColors.surfaceElevated;
    final borderColor = isLight ? AppColors.borderLight : AppColors.borderDark;
    final primaryText = isLight ? AppColors.lightTextPrimary : AppColors.textPrimary;
    final secondaryText = isLight ? AppColors.lightTextSecondary : AppColors.textSecondary;

    const titleText = 'New Update Available';

    final descriptionText = isForceUpdate
        ? 'A required update is available to keep PopVerse running smoothly. Please update to the latest version to continue.'
        : 'A new version of PopVerse is available with performance improvements and new features.';

    final dialogContent = Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.xxl,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.65),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
              if (!isLight)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hero Icon with Glowing Rings
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: isLight ? 0.1 : 0.12),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: isLight ? 0.18 : 0.22),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ],
              ),
              AppSpacing.gapH20,

              // Title
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: AppTextStyles.lg.copyWith(
                  color: primaryText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              AppSpacing.gapH12,

              // Description
              Text(
                descriptionText,
                textAlign: TextAlign.center,
                style: AppTextStyles.sm.copyWith(
                  color: secondaryText,
                  height: 1.45,
                ),
              ),
              AppSpacing.gapH24,

              // Buttons
              if (isForceUpdate) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Update Now',
                          style: AppTextStyles.mdBold.copyWith(
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                        AppSpacing.gapW8,
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.textOnPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: onLater,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: secondaryText,
                            padding: EdgeInsets.zero,
                            side: BorderSide(color: borderColor, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: AppTextStyles.smBold.copyWith(
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.gapW12,
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: onUpdate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textOnPrimary,
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Update',
                            style: AppTextStyles.smBold.copyWith(
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isForceUpdate) {
      return PopScope(
        canPop: false,
        child: dialogContent,
      );
    }

    return dialogContent;
  }
}
