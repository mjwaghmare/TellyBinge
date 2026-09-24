import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'explore_poster_card.dart';
import 'explore_quick_actions_sheet.dart';

/// 16:9 widescreen cinematic card for backdrop-led Explore feed rows
/// (such as "Coming Soon"), featuring a release date badge, dark gradient
/// scrim, and metadata overlay.
class ExploreBackdropCard extends StatelessWidget {
  const ExploreBackdropCard({
    super.key,
    required this.item,
    required this.defaultType,
  });

  final dynamic item;
  final String defaultType;

  static const _months = [
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

  static (String, String)? _parseDateBadge(String? dateStr) {
    if (dateStr == null || dateStr.length < 10) return null;
    try {
      final dt = DateTime.parse(dateStr);
      final currentYear = DateTime.now().year;
      final month = dt.year != currentYear
          ? '${_months[dt.month - 1]} \'${dt.year.toString().substring(2)}'
          : _months[dt.month - 1];
      final day = dt.day.toString();
      return (month, day);
    } catch (_) {
      return null;
    }
  }

  static String _formatSubtitle(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final releaseDay = DateTime(dt.year, dt.month, dt.day);
      final diff = releaseDay.difference(today).inDays;
      if (diff == 0) return 'Premieres today';
      if (diff == 1) return 'Releases tomorrow';
      if (diff > 1 && diff <= 60) return 'In $diff days';
      const monthsFull = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${monthsFull[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = item['name'] ?? item['title'] ?? 'Unknown';
    final String? backdropPath = item['backdrop_path'];
    final String? posterPath = item['poster_path'];
    final int id = item['id'] ?? 0;
    final String mediaType = item['media_type'] ?? defaultType;
    final String? dateStr = item['release_date'] ?? item['first_air_date'];
    final dateBadge = _parseDateBadge(dateStr);
    final subtitle = _formatSubtitle(dateStr);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isSkeleton = Skeletonizer.maybeOf(context)?.enabled == true;

    final imagePath = (backdropPath != null && backdropPath.isNotEmpty)
        ? backdropPath
        : posterPath;

    final placeholder = Container(
      color: isLight
          ? AppColors.lightSurfaceElevated
          : AppColors.surfaceLight,
      alignment: Alignment.center,
      child: Icon(
        Icons.movie_creation_outlined,
        size: 36,
        color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
      ),
    );

    return GestureDetector(
      onTap: () {
        AppHaptics.lightImpact();
        openExploreDetails(
          context,
          mediaId: id,
          mediaType: mediaType,
          title: title,
          posterPath: posterPath,
          backdropPath: backdropPath,
        );
      },
      onLongPress: () => showExploreQuickActions(
        context,
        item: item,
        defaultType: defaultType,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          decoration: BoxDecoration(
            color: isLight
                ? AppColors.lightSurfaceElevated
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isLight ? AppColors.borderLight : AppColors.borderDark,
              width: 1.0,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Backdrop image with memory cache optimization
              if (imagePath != null && imagePath.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: AppConstants.tmdbImageUrl(
                    imagePath,
                    size: backdropPath != null && backdropPath.isNotEmpty
                        ? 'w780'
                        : 'w342',
                  ),
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  placeholder: (context, url) => const SizedBox.shrink(),
                  errorWidget: (context, url, error) => placeholder,
                )
              else
                placeholder,

              // 2. Cinematic vertical gradient scrim for high legibility
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.3, 0.65, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Calendar Release Date Badge (top right)
              if (dateBadge != null && !isSkeleton)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          dateBadge.$1,
                          style: AppTextStyles.xsBold.copyWith(
                            color: AppColors.primaryLight,
                            fontSize: 10.0,
                            height: 1.0,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateBadge.$2,
                          style: AppTextStyles.smBold.copyWith(
                            color: Colors.white,
                            height: 1.0,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Title & Countdown/Date Subtitle (bottom overlay)
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.smBold.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4.0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.xs.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          shadows: const [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 4.0,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
