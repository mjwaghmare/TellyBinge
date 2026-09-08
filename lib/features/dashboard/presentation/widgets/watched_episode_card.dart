import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../../../features/auth/presentation/cubit/auth_state.dart';
import '../../domain/models/watch_history_item.dart';
import '../cubit/tv_show_watchlist_cubit.dart';

class WatchedEpisodeCard extends StatefulWidget {
  final WatchHistoryItem item;

  const WatchedEpisodeCard({super.key, required this.item});

  @override
  State<WatchedEpisodeCard> createState() => _WatchedEpisodeCardState();
}

class _WatchedEpisodeCardState extends State<WatchedEpisodeCard> {
  bool _isReverting = false;
  DateTime? _revertStartTime;
  Timer? _revertTimer;

  @override
  void dispose() {
    _revertTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(WatchedEpisodeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item != oldWidget.item) {
      if (_isReverting) {
        _revertTimer?.cancel();
        final elapsed = _revertStartTime != null
            ? DateTime.now().difference(_revertStartTime!)
            : const Duration(milliseconds: 500);
        const minDuration = Duration(milliseconds: 500);
        if (elapsed < minDuration) {
          final remaining = minDuration - elapsed;
          _revertTimer = Timer(remaining, () {
            if (mounted) {
              setState(() {
                _isReverting = false;
                _revertStartTime = null;
              });
            }
          });
        } else {
          setState(() {
            _isReverting = false;
            _revertStartTime = null;
          });
        }
      }
    }
  }

  void _handleUnwatch() async {
    if (_isReverting) return;
    _revertStartTime = DateTime.now();
    setState(() => _isReverting = true);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      unawaited(
        context.read<TvShowWatchlistCubit>().toggleEpisodeWatched(
          uid: authState.user.uid,
          showId: widget.item.showId,
          episodeKey: widget.item.episodeKey,
          isWatched: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posterPath = widget.item.showPoster;
    final imageUrl = (posterPath != null && posterPath.isNotEmpty)
        ? AppConstants.tmdbImageUrl(posterPath, size: 'w500')
        : null;

    final showName = widget.item.showName.isNotEmpty
        ? widget.item.showName.toUpperCase()
        : 'UNKNOWN';

    final displayCode = widget.item.displayCode;
    final episodeTitle = widget.item.episodeTitle;

    return Opacity(
      opacity: _isReverting ? 0.3 : 0.6,
      child: Container(
        margin: AppSpacing.cardMargin,
        clipBehavior: Clip.antiAlias,
        height: 96.0,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                width: 100,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 300,
                        placeholder: (context, url) => Container(
                          color: context.adaptiveColor(
                            light: AppColors.lightSurfaceElevated,
                            dark: AppColors.surfaceLight,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: context.adaptiveColor(
                            light: AppColors.lightSurfaceElevated,
                            dark: AppColors.surfaceLight,
                          ),
                          child: Icon(
                            Icons.tv,
                            color: context.adaptiveColor(
                              light: AppColors.lightTextTertiary,
                              dark: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: context.adaptiveColor(
                          light: AppColors.lightSurfaceElevated,
                          dark: AppColors.surfaceLight,
                        ),
                        child: Icon(
                          Icons.tv,
                          color: context.adaptiveColor(
                            light: AppColors.lightTextTertiary,
                            dark: AppColors.textTertiary,
                          ),
                        ),
                      ),
              ),
            ),
            AppSpacing.gapW12,

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0.0,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Show Name Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              showName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.xsBold.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textPrimary
                                    : AppColors.lightTextPrimary,
                                fontSize: 9.0,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          AppSpacing.gapW4,
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppColors.textSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapH4,

                    // Episode Code
                    Text(
                      displayCode,
                      style: AppTextStyles.smMedium.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),

                    // Episode Title
                    Text(
                      episodeTitle.isNotEmpty ? episodeTitle : 'TBA',
                      style: AppTextStyles.xs.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 11.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // Checkmark
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Center(
                child: GestureDetector(
                  onTap: _handleUnwatch,
                  behavior: HitTestBehavior.opaque,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48.0,
                      minHeight: 48.0,
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen, // TV Time Green
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.brandGreen, width: 2),
                        ),
                        child: _isReverting
                            ? const Padding(
                                padding: AppSpacing.allXS,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.textOnPrimary,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check, color: AppColors.textOnPrimary, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
