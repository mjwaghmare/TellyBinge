import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../models/enriched_show.dart';

class UpcomingEpisodeCard extends StatelessWidget {
  final EnrichedShow enrichedShow;

  const UpcomingEpisodeCard({super.key, required this.enrichedShow});

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

  Widget _buildRightSide(BuildContext context) {
    final daysLeft = enrichedShow.upcomingDaysLeft;
    final networkName = enrichedShow.upcomingNetworkName;

    if (daysLeft != null && daysLeft >= 7) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$daysLeft',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            daysLeft == 1 ? 'DAY' : 'DAYS',
            style: AppTextStyles.xs.copyWith(
              color: context.adaptiveColor(
                light: Colors.grey[500]!,
                dark: AppColors.textTertiary,
              ),
              fontSize: 10.0,
              letterSpacing: 1.0,
            ),
          ),
        ],
      );
    } else if (networkName != null && networkName.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppSpacing.gapH12,
          Text(
            networkName,
            style: AppTextStyles.xs.copyWith(
              color: context.adaptiveColor(
                light: Colors.grey[500]!,
                dark: AppColors.textTertiary,
              ),
              fontSize: 11.0,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final show = enrichedShow;
    final isDummy = show.rawShowData['id'] == -1;
    final showTitle = (show.rawShowData['name'] ?? 'Unknown').toUpperCase();

    final String rawBackdrop = show.rawShowData['backdropPath']?.toString() ?? '';
    final String rawPoster = show.rawShowData['posterPath']?.toString() ?? '';
    final imageUrl = rawBackdrop.isNotEmpty
        ? AppConstants.tmdbImageUrl(rawBackdrop, size: 'w500')
        : (rawPoster.isNotEmpty
            ? AppConstants.tmdbImageUrl(rawPoster, size: 'w500')
            : '');

    final bool hasChips = show.upcomingIsPremiere || show.upcomingIsNew;
    final double cardHeight = hasChips ? 115.0 : 96.0;

    return GestureDetector(
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
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        clipBehavior: Clip.antiAlias,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 130,
                      height: cardHeight,
                      fit: BoxFit.cover,
                      memCacheWidth: 390,
                      errorWidget: (context, url, error) => Container(
                        width: 130,
                        height: cardHeight,
                        color: context.adaptiveColor(
                          light: Colors.grey[200]!,
                          dark: AppColors.surfaceLight,
                        ),
                        child: Icon(
                          Icons.tv,
                          color: context.adaptiveColor(
                            light: Colors.grey[500]!,
                            dark: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        width: 130,
                        height: cardHeight,
                        color: context.adaptiveColor(
                          light: Colors.grey[200]!,
                          dark: AppColors.surfaceLight,
                        ),
                      ),
                    )
                  : Container(
                      width: 130,
                      height: cardHeight,
                      color: context.adaptiveColor(
                        light: Colors.grey[200]!,
                        dark: AppColors.surfaceLight,
                      ),
                      child: Icon(
                        Icons.tv,
                        color: context.adaptiveColor(
                          light: Colors.grey[500]!,
                          dark: AppColors.textTertiary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                  bottom: 8.0,
                  right: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white24
                                    : Colors.black12,
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
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
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
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white70
                                  : Colors.black54,
                              size: 14,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      show.upcomingEpisodeCode,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      show.upcomingEpisodeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondary
                            : Colors.black54,
                        fontSize: 11.0,
                      ),
                    ),
                    if (hasChips) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (show.upcomingIsPremiere)
                            _buildPillBadge(context, 'PREMIERE', false),
                          if (show.upcomingIsPremiere && show.upcomingIsNew)
                            const SizedBox(width: 6),
                          if (show.upcomingIsNew)
                            _buildPillBadge(context, 'LATEST', false),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _buildRightSide(context),
            ),
          ],
        ),
      ),
    );
  }
}
