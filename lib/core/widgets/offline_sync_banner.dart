import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../sync/sync_status_cubit.dart';
import '../sync/sync_status_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Tells users when Firestore writes are queued offline, syncing, or synced.
///
/// On iPhones with a Dynamic Island it is drawn on the Island itself: a black
/// pill of the Island's height that widens sideways, with content either side
/// of the camera, while the status bar hides. Elsewhere it is a pill that
/// drops in below the status bar. Place it at the top of the screen without a
/// SafeArea, since it handles the inset itself.
class OfflineSyncBanner extends StatefulWidget {
  const OfflineSyncBanner({super.key});

  /// Hardware Island size, in logical pixels.
  static const Size islandSize = Size(126, 37);

  /// There is no API for this, so it is inferred from the top inset: Island
  /// iPhones report 59pt or more, notched iPhones 50pt or less.
  @visibleForTesting
  static bool hasDynamicIsland(MediaQueryData mediaQuery) =>
      defaultTargetPlatform == TargetPlatform.iOS && mediaQuery.padding.top >= 54;

  /// Gap between the screen top and the Island: 11pt on 59pt-inset models
  /// (iPhone 14 Pro to 16), 14pt on 62pt-inset models (16 Pro and later).
  @visibleForTesting
  static double islandTopFor(MediaQueryData mediaQuery) =>
      (mediaQuery.padding.top - 48).clamp(8.0, 16.0);

  @override
  State<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends State<OfflineSyncBanner> {
  // Island geometry is latched on first detection: hiding the status bar
  // may change the reported inset, which must not flip the layout mid-show.
  bool? _hasIsland;
  double _islandTop = 11;
  bool _statusBarHidden = false;

  void _setStatusBarHidden(bool hidden) {
    if (_statusBarHidden == hidden) return;
    _statusBarHidden = hidden;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: hidden ? const [SystemUiOverlay.bottom] : SystemUiOverlay.values,
    );
  }

  @override
  void dispose() {
    _setStatusBarHidden(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    if (_hasIsland == null && mediaQuery.padding.top > 0) {
      _hasIsland = OfflineSyncBanner.hasDynamicIsland(mediaQuery);
      _islandTop = OfflineSyncBanner.islandTopFor(mediaQuery);
    }
    final hasIsland = _hasIsland ?? false;

    return BlocConsumer<SyncStatusCubit, SyncStatusState>(
      listenWhen: (previous, current) => previous.shouldShowBanner != current.shouldShowBanner,
      listener: (context, state) {
        if (hasIsland) _setStatusBarHidden(state.shouldShowBanner);
      },
      builder: (context, state) => hasIsland
          ? _IslandBanner(state: state, top: _islandTop)
          : _PillBanner(state: state, top: mediaQuery.padding.top),
    );
  }
}

IconData _iconFor(SyncStatusState state) => state.justSynced
    ? Icons.check_circle_rounded
    : state.isSyncing
        ? Icons.cloud_upload_rounded
        : Icons.cloud_off_rounded;

/// Drawn on the Dynamic Island: the Island's height, widened sideways.
class _IslandBanner extends StatelessWidget {
  final SyncStatusState state;
  final double top;

  const _IslandBanner({required this.state, required this.top});

  /// Width of the content area on each side of the camera.
  static const double _sideWidth = 104;

  @override
  Widget build(BuildContext context) {
    final isVisible = state.shouldShowBanner;
    final isReduced = AppMotion.isReducedMotion(context);
    final duration = isReduced ? AppMotion.instant : AppMotion.medium;
    final island = OfflineSyncBanner.islandSize;
    // Always black like the Island, so dark tokens apply in both themes.
    final textStyle = AppTextStyles.xsBold.copyWith(color: AppColors.textPrimary, letterSpacing: 0.3);
    final iconColor = state.justSynced ? AppColors.success : AppColors.primaryLight;

    final (String leading, Widget? trailing) = switch (state) {
      _ when state.justSynced => ('Synced', null),
      _ when state.isSyncing => (
          'Syncing',
          _SyncPercent(progress: state.progress, style: textStyle, animate: !isReduced, prefix: ''),
        ),
      _ => (
          'Offline',
          state.pendingCount > 0 ? Text('${state.pendingCount} waiting', style: textStyle) : null,
        ),
    };

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Center(
          heightFactor: 1,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: AppMotion.fadeDuration(context, normalDuration: AppMotion.medium),
            // Grows sideways out of the Island and shrinks back into it.
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.emphasized,
              width: isVisible ? island.width + 2 * _sideWidth : island.width,
              height: island.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(island.height / 2),
              ),
              child: OverflowBox(
                minWidth: island.width + 2 * _sideWidth,
                maxWidth: island.width + 2 * _sideWidth,
                child: AnimatedOpacity(
                  opacity: isVisible ? 1 : 0,
                  duration: isReduced ? AppMotion.instant : AppMotion.fast,
                  child: Row(
                    children: [
                      SizedBox(
                        width: _sideWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.md),
                          child: Row(
                            children: [
                              Icon(_iconFor(state), size: 14, color: iconColor),
                              AppSpacing.gapW8,
                              Flexible(
                                child: Text(leading, style: textStyle, maxLines: 1, overflow: TextOverflow.fade),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // The camera sits here.
                      SizedBox(width: island.width),
                      SizedBox(
                        width: _sideWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: Align(alignment: Alignment.centerRight, child: trailing),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The original banner: a themed pill that drops in below the status bar.
class _PillBanner extends StatelessWidget {
  final SyncStatusState state;
  final double top;

  const _PillBanner({required this.state, required this.top});

  @override
  Widget build(BuildContext context) {
    final isLight = AppColors.isLight(context);
    final isVisible = state.shouldShowBanner;
    final isReduced = AppMotion.isReducedMotion(context);
    final isSynced = state.justSynced;
    final textStyle = AppTextStyles.xsBold.copyWith(
      color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
      letterSpacing: 0.3,
    );
    final iconColor = isSynced
        ? (isLight ? AppColors.lightOnSuccessContainer : AppColors.success)
        : (isLight ? AppColors.lightPrimary : AppColors.primary);

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: AnimatedSlide(
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
              heightFactor: 1,
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
                      _iconFor(state),
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
      ),
    );
  }
}

/// " · 42%", counting smoothly toward [progress]. Firestore confirms writes
/// in batches, so the real value jumps; animating it shows steady movement.
class _SyncPercent extends StatelessWidget {
  final double progress;
  final TextStyle style;
  final bool animate;
  final String prefix;

  const _SyncPercent({
    required this.progress,
    required this.style,
    required this.animate,
    this.prefix = ' · ',
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
          '$prefix$percent%',
          style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        );
      },
    );
  }
}
