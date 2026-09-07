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

  Widget _buildRightSide(BuildContext context) {
    final daysLeft = enrichedShow.upcomingDaysLeft;
    final networkName = enrichedShow.upcomingNetworkName;

    if (daysLeft != null && daysLeft >= 7) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$daysLeft',
            style: AppTextStyles.xl.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            daysLeft == 1 ? 'DAY' : 'DAYS',
            style: AppTextStyles.xs.copyWith(
              color: context.adaptiveColor(
                light: AppColors.lightTextTertiary,
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
                light: AppColors.lightTextTertiary,
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
        margin: AppSpacing.cardMargin,
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
                      placeholder: (context, url) => Container(
                        width: 130,
                        height: cardHeight,
                        color: context.adaptiveColor(
                          light: AppColors.lightSurfaceElevated,
                          dark: AppColors.surfaceLight,
                        ),
                      ),
                    )
                  : Container(
                      width: 130,
                      height: cardHeight,
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
            AppSpacing.gapW12,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  right: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    Text(
                      show.upcomingEpisodeCode,
                      style: AppTextStyles.smBold.copyWith(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      show.upcomingEpisodeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.xs.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                        fontSize: 11.0,
                      ),
                    ),
                    if (hasChips) ...[
                      AppSpacing.gapH4,
                      Row(
                        children: [
                          if (show.upcomingIsPremiere)
                            _buildPillBadge(context, 'PREMIERE', false),
                          if (show.upcomingIsPremiere && show.upcomingIsNew)
                            AppSpacing.gapW8,
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
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _buildRightSide(context),
            ),
          ],
        ),
      ),
    );
  }
}
