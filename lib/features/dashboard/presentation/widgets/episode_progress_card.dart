import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/tv_show_watchlist_cubit.dart';
import '../models/enriched_show.dart';

class EpisodeProgressCard extends StatefulWidget {
  final EnrichedShow enrichedShow;
  final bool isGridView;

  const EpisodeProgressCard({
    super.key,
    required this.enrichedShow,
    this.isGridView = false,
  });

  @override
  State<EpisodeProgressCard> createState() => _EpisodeProgressCardState();
}

class _EpisodeProgressCardState extends State<EpisodeProgressCard> {
  bool _isMarkingAsWatched = false;
  bool _hasFiredSlideHaptic = false;
  String? _lastMarkedEpisodeCode;
  Timer? _markingSafetyTimer;
  DateTime? _markStartTime;

  @override
  void dispose() {
    _markingSafetyTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(EpisodeProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMarkingAsWatched) {
      final hasAdvanced =
          widget.enrichedShow.episodeCode != _lastMarkedEpisodeCode ||
          widget.enrichedShow.isUpToDate;
      if (hasAdvanced) {
        _markingSafetyTimer?.cancel();
        final elapsed = _markStartTime != null
            ? DateTime.now().difference(_markStartTime!)
            : const Duration(milliseconds: 500);
        const minDuration = Duration(milliseconds: 500);
        if (elapsed < minDuration) {
          final remaining = minDuration - elapsed;
          _markingSafetyTimer = Timer(remaining, () {
            if (mounted) {
              setState(() {
                _isMarkingAsWatched = false;
                _lastMarkedEpisodeCode = null;
                _markStartTime = null;
              });
            }
          });
        } else {
          setState(() {
            _isMarkingAsWatched = false;
            _lastMarkedEpisodeCode = null;
            _markStartTime = null;
          });
        }
      }
    }
  }

  Future<void> _markAsWatched() async {
    final show = widget.enrichedShow;
    if (show.isUpToDate ||
        show.targetSeason <= 0 ||
        show.targetEpisode <= 0 ||
        _isMarkingAsWatched) {
      return;
    }

    _lastMarkedEpisodeCode = show.episodeCode;
    _markStartTime = DateTime.now();
    setState(() {
      _isMarkingAsWatched = true;
    });

    _markingSafetyTimer?.cancel();
    _markingSafetyTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isMarkingAsWatched) {
        setState(() {
          _isMarkingAsWatched = false;
          _lastMarkedEpisodeCode = null;
          _markStartTime = null;
        });
      }
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      final uid = authState.user.uid;
      final showId = show.rawShowData['id'];
      final episodeKey = '${show.targetSeason}-${show.targetEpisode}';

      context.read<TvShowWatchlistCubit>().toggleEpisodeWatched(
        uid: uid,
        showId: showId,
        episodeKey: episodeKey,
        isWatched: true,
        showName: show.rawShowData['name']?.toString(),
        showPoster: show.rawShowData['posterPath']?.toString(),
        episodeTitle: show.episodeTitle,
      );
    }
  }

  Future<void> _showStopWatchingSheet() async {
    final showName = (widget.enrichedShow.rawShowData['name'] ?? 'this show')
        .toString();
    final showId = widget.enrichedShow.rawShowData['id'] as int;

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color:
                Theme.of(context).bottomSheetTheme.backgroundColor ??
                (context.isLight
                    ? AppColors.lightSurfaceElevated
                    : AppColors.surfaceDarkAlt),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.isLight ? AppColors.borderLight : AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.gapH24,
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              AppSpacing.gapH16,
              Text(
                'Stop Watching?',
                style: AppTextStyles.lg.copyWith(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.gapH8,
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: AppTextStyles.xs.copyWith(
                    color: context.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: showName,
                      style: AppTextStyles.xsMedium.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' will be removed from your Shows tab.\nYour episode progress is saved.',
                    ),
                  ],
                ),
              ),
              AppSpacing.gapH24,
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    final authState = context.read<AuthCubit>().state;
                    if (authState is Authenticated) {
                      HapticFeedback.mediumImpact();
                      context.read<TvShowWatchlistCubit>().stopWatchingShow(
                        uid: authState.user.uid,
                        showId: showId,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'STOP WATCHING',
                    style: AppTextStyles.smBold.copyWith(
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              AppSpacing.gapH12,
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.md.copyWith(
                      color: context.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPillBadge(BuildContext context, String label, bool isYellow) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isYellow
            ? AppColors.primary
            : (isDark ? AppColors.borderDark : AppColors.borderLight),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        label,
        style: AppTextStyles.xsBold.copyWith(
          color: isYellow
              ? AppColors.textOnPrimary
              : (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary),
          fontSize: 8.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.enrichedShow;
    final dismissibleKey = ValueKey(
      'swipe_${show.rawShowData['id']}_${show.episodeCode}',
    );
    final showTitle = (show.rawShowData['name'] ?? 'Unknown').toUpperCase();

    final String rawBackdrop = show.rawShowData['backdropPath']?.toString() ?? '';
    final String rawPoster = show.rawShowData['posterPath']?.toString() ?? '';
    final imageUrl = rawBackdrop.isNotEmpty
        ? AppConstants.tmdbImageUrl(rawBackdrop, size: 'w500')
        : (rawPoster.isNotEmpty
            ? AppConstants.tmdbImageUrl(rawPoster, size: 'w500')
            : '');

    bool isWatched = show.isUpToDate;
    final hasChips = (show.isPremiere || show.isNew) && !isWatched;
    final cardHeight = hasChips ? 115.0 : 96.0;

    // Skeletonizer inside DashboardPage controls the overall shimmer,
    // so we don't need a local isLoading state here anymore!
    // But we check if the ID is -1 (dummy skeleton) to hide the action circle.
    final isDummy = show.rawShowData['id'] == -1;

    return Dismissible(
      key: dismissibleKey,
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          if (!isWatched && !isDummy && !_isMarkingAsWatched) {
            unawaited(_markAsWatched());
          }
        } else {
          await _showStopWatchingSheet();
        }
        return false;
      },
      onUpdate: (details) {
        if (details.progress > 0.05 && !_hasFiredSlideHaptic) {
          _hasFiredSlideHaptic = true;
        }
        if (details.progress < 0.05) {
          _hasFiredSlideHaptic = false;
        }
      },
      background: Container(
        margin: AppSpacing.cardMargin,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(6.0),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.xl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stop_circle_outlined, color: AppColors.textOnPrimary, size: 28),
            AppSpacing.gapW8,
            Text(
              'STOP WATCHING',
              style: AppTextStyles.smBold.copyWith(
                color: AppColors.textOnPrimary,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: AppSpacing.cardMargin,
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(6.0),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'WATCHED',
              style: AppTextStyles.smBold.copyWith(
                color: AppColors.textOnPrimary,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            AppSpacing.gapW8,
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.textOnPrimary,
              size: 28,
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (isDummy) return;
          final showId = show.rawShowData['id'];
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => BlocProvider<ShowDetailsCubit>(
                create: (context) =>
                    ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
                child: ShowDetailsPage(
                  mediaId: showId,
                  mediaType: 'tv',
                  title: show.rawShowData['name'] ?? '',
                ),
              ),
            ),
          );
        },
        child: Container(
          margin: AppSpacing.cardMargin,
          clipBehavior: Clip.antiAlias,
          height: cardHeight,
          decoration: BoxDecoration(
            color: _isMarkingAsWatched
                ? context.adaptiveColor(
                    light: AppColors.lightSurfaceElevated,
                    dark: AppColors.surface,
                  )
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: _isMarkingAsWatched
              ? Center(
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.brandGreen,
                    ),
                  ),
                )
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 100,
                              height: cardHeight,
                              fit: BoxFit.cover,
                              memCacheWidth: 300,
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: cardHeight,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppColors.lightSurfaceElevated
                                    : AppColors.surfaceLight,
                                child: Icon(
                                  Icons.tv,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppColors.lightTextTertiary
                                      : AppColors.textTertiary,
                                ),
                              ),
                              placeholder: (context, url) => Container(
                                width: 100,
                                height: cardHeight,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppColors.lightSurfaceElevated
                                    : AppColors.surfaceLight,
                              ),
                            )
                          : Container(
                              width: 100,
                              height: cardHeight,
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppColors.lightSurfaceElevated
                                  : AppColors.surfaceLight,
                              child: Icon(
                                Icons.tv,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppColors.lightTextTertiary
                                    : AppColors.textTertiary,
                              ),
                            ),
                    ),
                    AppSpacing.gapW12,
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
                            Container(
                              padding: isDummy
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                      vertical: AppSpacing.xxs,
                                    ),
                              decoration: BoxDecoration(
                                border: isDummy
                                    ? null
                                    : Border.all(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
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
                                      showTitle,
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
                                  if (!isDummy) AppSpacing.gapW4,
                                  if (!isDummy)
                                    Icon(
                                      Icons.chevron_right,
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? AppColors.textSecondary
                                          : AppColors.lightTextSecondary,
                                      size: 14,
                                    ),
                                ],
                              ),
                            ),
                            AppSpacing.gapH4,
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: show.episodeCode,
                                    style: AppTextStyles.sm.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (show.extraCount != null && !isWatched)
                                    TextSpan(
                                      text: ' ${show.extraCount}',
                                      style: AppTextStyles.xs.copyWith(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.textSecondary
                                            : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              show.episodeTitle.isNotEmpty
                                  ? show.episodeTitle
                                  : 'TBA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.xs.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textSecondary
                                    : AppColors.lightTextSecondary,
                                fontSize: 11.0,
                              ),
                            ),
                            if (hasChips) ...[
                              AppSpacing.gapH4,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (show.isPremiere)
                                    _buildPillBadge(context, 'PREMIERE', false),
                                  if (show.isNew) ...[
                                    AppSpacing.gapW4,
                                    _buildPillBadge(context, 'NEW', true),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: isDummy ? 0.0 : 1.0,
                      child: Skeleton.ignore(
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: GestureDetector(
                            onTap: () {
                              if (!isWatched &&
                                  !isDummy &&
                                  !_isMarkingAsWatched) {
                                _markAsWatched();
                              }
                            },
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
                                    shape: BoxShape.circle,
                                    color: isWatched
                                        ? AppColors.success
                                        : context.adaptiveColor(
                                            light: Colors.transparent,
                                            dark: AppColors.surface,
                                          ),
                                    border: isWatched
                                        ? null
                                        : Border.all(
                                            color: context.adaptiveColor(
                                              light: AppColors.lightTextTertiary,
                                              dark: Colors.transparent,
                                            ),
                                            width: 1.5,
                                          ),
                                  ),
                                  child: _isMarkingAsWatched
                                      ? const CircularProgressIndicator.adaptive()
                                      : (isWatched
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.textOnPrimary,
                                                size: 24,
                                              )
                                            : Icon(
                                                Icons.check,
                                                color: context.adaptiveColor(
                                                  light: AppColors.lightTextTertiary,
                                                  dark: AppColors.textTertiary,
                                                ),
                                                size: 24,
                                              )),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
