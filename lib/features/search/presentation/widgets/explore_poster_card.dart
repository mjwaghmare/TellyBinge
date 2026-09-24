import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../cubit/tv_status_cubit.dart';
import 'explore_quick_actions_sheet.dart';

/// Poster tile used across Explore: feed rows, See All and search results.
///
/// Sizes itself to its parent — the poster takes whatever height is left
/// after the title and rating lines.
class ExplorePosterCard extends StatelessWidget {
  const ExplorePosterCard({
    super.key,
    required this.item,
    required this.defaultType,
    this.posterOnly = false,
  });

  final dynamic item;
  final String defaultType;

  /// Drops the title and rating lines, leaving just the poster (Top 5).
  final bool posterOnly;

  static final Map<String, String> _formattedDateCache = {};

  static String _formatDateCached(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return _formattedDateCache.putIfAbsent(dateStr, () {
      try {
        final dt = DateTime.parse(dateStr);
        const months = [
          'JAN',
          'FEB',
          'MAR',
          'APR',
          'MAY',
          'JUN',
          'JUL',
          'AUG',
          'SEP',
          'OCT',
          'NOV',
          'DEC',
        ];
        return '${months[dt.month - 1]}, ${dt.year}';
      } catch (_) {
        return dateStr.length >= 4 ? dateStr.substring(0, 4) : '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String title = item['name'] ?? item['title'] ?? 'Unknown';
    final String? posterPath = item['poster_path'];
    final double voteAverage =
        (item['vote_average'] as num?)?.toDouble() ?? 0.0;
    final int id = item['id'];
    final String mediaType = item['media_type'] ?? defaultType;
    final String? dateStr = item['release_date'] ?? item['first_air_date'];
    final String formattedDate = _formatDateCached(dateStr);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final secondaryColor =
        Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    final placeholderIcon = Skeleton.ignore(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 32,
        color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
      ),
    );

    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: isLight
                ? AppColors.lightSurfaceElevated
                : AppColors.surfaceLight,
            width: double.infinity,
            height: double.infinity,
            child: posterPath != null && posterPath.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: AppConstants.tmdbImageUrl(
                      posterPath,
                      size: 'w185',
                    ),
                    fit: BoxFit.cover,
                    memCacheWidth: 250,
                    placeholder: (context, url) => const SizedBox.shrink(),
                    errorWidget: (context, url, error) => placeholderIcon,
                  )
                : placeholderIcon,
          ),
          if (mediaType == 'tv' &&
              Skeletonizer.maybeOf(context)?.enabled != true)
            TvStatusPill(tvId: id),
        ],
      ),
    );

    return GestureDetector(
      onTap: () => openExploreDetails(
        context,
        mediaId: id,
        mediaType: mediaType,
        title: title,
        posterPath: posterPath,
        backdropPath: item['backdrop_path'] as String?,
      ),
      onLongPress: () => showExploreQuickActions(
        context,
        item: item,
        defaultType: defaultType,
      ),
      child: posterOnly
          ? poster
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: poster),
                AppSpacing.gapH4,
                // Title
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.xsBold.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                AppSpacing.gapH4,
                // Rating & Release Date row
                Row(
                  children: [
                    if (voteAverage >= 1.0) ...[
                      Icon(Icons.star, color: AppColors.primary, size: 10.0),
                      AppSpacing.gapW4,
                      Text(
                        voteAverage.toStringAsFixed(1),
                        style: AppTextStyles.xs.copyWith(color: secondaryColor),
                      ),
                      if (formattedDate.isNotEmpty) ...[
                        AppSpacing.gapW4,
                        Text(
                          '•',
                          style: AppTextStyles.xs.copyWith(
                            color: secondaryColor,
                          ),
                        ),
                        AppSpacing.gapW4,
                        Expanded(
                          child: Text(
                            formattedDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.xs.copyWith(
                              color: secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ] else if (formattedDate.isNotEmpty) ...[
                      Expanded(
                        child: Text(
                          formattedDate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.xs.copyWith(
                            color: secondaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}

void openExploreDetails(
  BuildContext context, {
  required int mediaId,
  required String mediaType,
  required String title,
  String? posterPath,
  String? backdropPath,
}) {
  if (mediaType == 'movie') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsPage(
          movieId: mediaId,
          title: title,
          posterPath: posterPath,
          backdropPath: backdropPath,
        ),
      ),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider<ShowDetailsCubit>(
          create: (context) =>
              ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
          child: ShowDetailsPage(
            mediaId: mediaId,
            mediaType: mediaType,
            title: title,
          ),
        ),
      ),
    );
  }
}

/// Status pill over a TV poster.
///
/// Never fetches itself. When first built it queues its id with
/// [TvStatusCubit], which dedupes and resolves in the background, so only
/// posters that lazy lists actually build (on screen or just off it) cost a
/// lookup. The selector narrows the rebuild to this one show, so a batch of
/// resolutions only repaints the tiles it actually answered.
class TvStatusPill extends StatefulWidget {
  const TvStatusPill({super.key, required this.tvId});

  final int tvId;

  @override
  State<TvStatusPill> createState() => _TvStatusPillState();
}

class _TvStatusPillState extends State<TvStatusPill> {
  @override
  void initState() {
    super.initState();
    _queue();
  }

  @override
  void didUpdateWidget(TvStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tvId != widget.tvId) _queue();
  }

  /// Deferred past the frame so building a tile never emits mid-build.
  void _queue() {
    final id = widget.tvId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TvStatusCubit>().resolveAll([id]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tvId = widget.tvId;
    return BlocSelector<
      TvStatusCubit,
      Map<int, TvStatusLabel?>,
      TvStatusLabel?
    >(
      selector: (statuses) => statuses[tvId],
      builder: (context, label) {
        if (label == null) {
          // Kept positioned so the Stack's children stay uniformly positioned.
          return const Positioned(top: 6, right: 6, child: SizedBox.shrink());
        }
        final (String text, Color color) = switch (label) {
          TvStatusLabel.ended => ('ENDED', AppColors.error),
          TvStatusLabel.cancelled => ('CANCELLED', AppColors.error),
          TvStatusLabel.upcoming => ('UPCOMING', AppColors.airing),
        };
        return Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              text,
              style: AppTextStyles.xsBold.copyWith(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
