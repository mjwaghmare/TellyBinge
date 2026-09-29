import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../sync/sync_status_cubit.dart';
import '../sync/sync_status_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A subtle, non-intrusive banner informing users when Firestore writes
/// are queued offline and will automatically synchronize when reconnected.
class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, state) {
        final isLight = AppColors.isLight(context);
        final isVisible = state.shouldShowBanner;
        final isReduced = AppMotion.isReducedMotion(context);

        final isSynced = state.justSynced;
        final iconData = isSynced
            ? Icons.check_circle_rounded
            : state.isSyncing
                ? Icons.cloud_upload_rounded
                : Icons.cloud_off_rounded;
        final textStyle = AppTextStyles.xsBold.copyWith(
          color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
          letterSpacing: 0.3,
        );
        final iconColor = isSynced
            ? (isLight ? AppColors.lightOnSuccessContainer : AppColors.success)
            : (isLight ? AppColors.lightPrimary : AppColors.primary);

        return AnimatedSlide(
          offset: (isReduced || isVisible) ? Offset.zero : const Offset(0, -1.2),
          duration: isReduced ? AppMotion.instant : AppMotion.medium,
          curve: AppMotion.emphasized,
          child: AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: AppMotion.fadeDuration(
              context,
              normalDuration: AppMotion.normal,
            ),
            child: IgnorePointer(
              ignoring: !isVisible,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightSurface
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.xxl),
                    border: Border.all(
                      color: isSynced
                          ? (isLight
                              ? AppColors.lightSuccessContainer
                              : AppColors.success.withValues(alpha: 0.3))
                          : (isLight
                              ? AppColors.borderLight
                              : AppColors.borderDark),
                      width: 1,
                    ),
                    boxShadow: isLight
                        ? AppColors.lightCardShadow
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconData,
                        size: 14,
                        color: iconColor,
                      ),
                      AppSpacing.gapW8,
                      Text(state.bannerText, style: textStyle),
                      if (state.isSyncing)
                        _SyncPercent(
                          progress: state.progress,
                          style: textStyle,
                          animate: !isReduced,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// " · 42%", counting smoothly toward [progress]. Firestore confirms writes
/// in batches, so the real value jumps; animating it shows steady movement.
class _SyncPercent extends StatelessWidget {
  final double progress;
  final TextStyle style;
  final bool animate;

  const _SyncPercent({
    required this.progress,
    required this.style,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: animate ? const Duration(milliseconds: 600) : Duration.zero,
      curve: Curves.easeOut,
      builder: (context, value, _) {
        // Starts at 1% so it reads as under way rather than stalled.
        final percent = (value * 100).round().clamp(1, 100);
        return Text(
          ' · $percent%',
          style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        );
      },
    );
  }
}
