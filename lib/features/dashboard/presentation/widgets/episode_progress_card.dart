import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
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

  @override
  void didUpdateWidget(EpisodeProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the show data changes (e.g., from the cloud function updating the watchlist status),
    // reset the marking state so the loader goes away.
    if (widget.enrichedShow != oldWidget.enrichedShow) {
      if (_isMarkingAsWatched) {
        setState(() {
          _isMarkingAsWatched = false;
        });
      }
    }
  }

  Future<void> _markAsWatched() async {
    final show = widget.enrichedShow;
    if (show.isUpToDate ||
        show.targetSeason == 0 ||
        show.targetEpisode == 0 ||
        _isMarkingAsWatched) {
      return;
    }

    setState(() {
      _isMarkingAsWatched = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

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
      // Let the cubit trigger a refresh which will recreate this widget
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
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.stop_circle_outlined,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Stop Watching?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: showName,
                      style: TextStyle(
                        color: Colors.white,
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
              const SizedBox(height: 28),
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'STOP WATCHING',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
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
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: isYellow
            ? AppColors.primary
            : (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isYellow
              ? Colors.black
              : (isDark ? Colors.white : Colors.black87),
          fontSize: 8.0,
          fontWeight: FontWeight.bold,
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

    final imageUrl =
        show.rawShowData['backdropPath'] != null &&
            show.rawShowData['backdropPath'].toString().isNotEmpty
        ? 'https://image.tmdb.org/t/p/w500${show.rawShowData['backdropPath']}'
        : (show.rawShowData['posterPath'] != null &&
                  show.rawShowData['posterPath'].toString().isNotEmpty
              ? 'https://image.tmdb.org/t/p/w500${show.rawShowData['posterPath']}'
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
          HapticFeedback.lightImpact();
        }
        if (details.progress < 0.05) {
          _hasFiredSlideHaptic = false;
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(6.0),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.stop_circle_outlined, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'STOP WATCHING',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(6.0),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text(
              'WATCHED',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(width: 10),
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
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
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  BlocProvider<ShowDetailsCubit>(
                    create: (context) => ShowDetailsCubit(
                      tmdbClient: context.read<TmdbClient>(),
                    ),
                    child: ShowDetailsPage(
                      mediaId: showId,
                      mediaType: 'tv',
                      title: show.rawShowData['name'] ?? '',
                    ),
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(0.0, 1.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          clipBehavior: Clip.antiAlias,
          height: cardHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: _isMarkingAsWatched
              ? Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF6B8E23)),
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
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: cardHeight,
                                color: Theme.of(context).brightness == Brightness.light ? Colors.grey[200] : AppColors.surfaceLight,
                                child: Icon(
                                  Icons.tv,
                                  color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                                ),
                              ),
                              placeholder: (context, url) => Container(
                                width: 100,
                                height: cardHeight,
                                color: Theme.of(context).brightness == Brightness.light ? Colors.grey[200] : AppColors.surfaceLight,
                              ),
                            )
                          : Container(
                              width: 100,
                              height: cardHeight,
                              color: Theme.of(context).brightness == Brightness.light ? Colors.grey[200] : AppColors.surfaceLight,
                              child: Icon(
                                Icons.tv,
                                color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          0.0,
                          16.0,
                          16.0,
                          16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: isDummy
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.symmetric(
                                      horizontal: 10.0,
                                      vertical: 4.0,
                                    ),
                              decoration: BoxDecoration(
                                border: isDummy
                                    ? null
                                    : Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12,
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
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  if (!isDummy) const SizedBox(width: 4),
                                  if (!isDummy)
                                    Icon(
                                      Icons.chevron_right,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54,
                                      size: 14,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: show.episodeCode,
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (show.extraCount != null && !isWatched)
                                    TextSpan(
                                      text: ' ${show.extraCount}',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondary : Colors.black54,
                                        fontSize: 11.0,
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
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.textSecondary : Colors.black54,
                                fontSize: 11.0,
                              ),
                            ),
                            if (hasChips) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  if (show.isPremiere)
                                    _buildPillBadge(context, 'PREMIERE', false),
                                  if (show.isNew) ...[
                                    const SizedBox(width: 4),
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
                          padding: const EdgeInsets.only(right: 16.0),
                          child: GestureDetector(
                            onTap: () {
                              if (!isWatched &&
                                  !isDummy &&
                                  !_isMarkingAsWatched) {
                                _markAsWatched();
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isWatched
                                    ? AppColors.success
                                    : (Theme.of(context).brightness == Brightness.light ? Colors.transparent : Colors.white),
                                border: isWatched
                                    ? null
                                    : Border.all(
                                        color: Theme.of(context).brightness == Brightness.light ? Colors.grey[400]! : Colors.transparent,
                                        width: 1.5,
                                      ),
                              ),
                              child: isWatched
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    )
                                  : Icon(
                                      Icons.check,
                                      color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                                      size: 24,
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
