import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../sync/sync_status_cubit.dart';
import '../sync/sync_status_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A Dynamic Island–style pill informing users when Firestore writes are
/// queued offline, syncing, or synced.
///
/// On iPhones with a Dynamic Island the pill grows out of the Island and
/// expands below it; elsewhere it drops in from the top edge. Place it at the
/// top of the screen without a SafeArea, since it handles the inset itself.
class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({super.key});

  /// Hardware Island size on iPhone 14 Pro and later, in logical pixels.
  static const Size islandSize = Size(126, 37);

  /// Gap between the screen top and the hardware Island.
  static const double islandTop = 11;

  /// How far the body tucks under the neck so the two read as one shape.
  static const double _neckOverlap = 12;

  /// There is no API for this, so it is inferred from the top inset: Island
  /// iPhones report 59pt or more, notched iPhones 50pt or less. A wrong guess
  /// only shifts the pill a little.
  @visibleForTesting
  static bool hasDynamicIsland(MediaQueryData mediaQuery) =>
      defaultTargetPlatform == TargetPlatform.iOS && mediaQuery.padding.top >= 54;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatusState>(
      builder: (context, state) {
        final mediaQuery = MediaQuery.of(context);
        final hasIsland = hasDynamicIsland(mediaQuery);
        final isVisible = state.shouldShowBanner;
        final isReduced = AppMotion.isReducedMotion(context);
        final duration = isReduced ? AppMotion.instant : AppMotion.medium;

        final isSynced = state.justSynced;
        final iconData = isSynced
            ? Icons.check_circle_rounded
            : state.isSyncing
                ? Icons.cloud_upload_rounded
                : Icons.cloud_off_rounded;
        // The pill is always black like the Island, so dark tokens apply in
        // both themes.
        final iconColor = isSynced ? AppColors.success : AppColors.primaryLight;
        final textStyle = AppTextStyles.xsBold.copyWith(
          color: AppColors.textPrimary,
          letterSpacing: 0.3,
        );

        final content = Padding(
          key: const ValueKey('sync-banner-content'),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            // Under the Island the body starts behind the neck; see below.
            AppSpacing.sm + (hasIsland ? _neckOverlap : 0),
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 14, color: iconColor),
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
        );

        // The decoration and rounded clip sit outside AnimatedSize so the
        // corners stay rounded while it grows or shrinks. On hide the text
        // fades out first, then the body collapses.
        final body = AnimatedContainer(
          duration: duration,
          curve: AppMotion.emphasized,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppSpacing.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedSize(
            duration: duration,
            curve: AppMotion.emphasized,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: isReduced ? AppMotion.instant : AppMotion.fast,
              child: isVisible ? content : const SizedBox.shrink(),
            ),
          ),
        );

        // On Island iPhones a neck the Island's exact size sits over the
        // hardware Island and the body hangs below it, so the pill never
        // covers the clock or battery beside the Island.
        final pill = !hasIsland
            ? body
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: islandSize.width,
                    height: islandSize.height,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(islandSize.height / 2),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -_neckOverlap),
                    child: body,
                  ),
                ],
              );

        return Padding(
          padding: EdgeInsets.only(
            top: hasIsland ? islandTop : mediaQuery.padding.top + AppSpacing.xs,
          ),
          child: AnimatedSlide(
            // Island devices grow in place; others drop in from the top.
            offset: (isReduced || isVisible || hasIsland) ? Offset.zero : const Offset(0, -1.2),
            duration: duration,
            curve: AppMotion.emphasized,
            child: AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: AppMotion.fadeDuration(
                context,
                normalDuration: AppMotion.medium,
              ),
              child: IgnorePointer(
                ignoring: !isVisible,
                child: Center(heightFactor: 1, child: pill),
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
