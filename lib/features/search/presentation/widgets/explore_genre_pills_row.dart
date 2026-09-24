import 'package:flutter/material.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/explore_genres.dart';

/// Lightweight horizontal chip bar for quick genre filtering on Explore.
class ExploreGenrePillsRow extends StatelessWidget {
  const ExploreGenrePillsRow({
    super.key,
    required this.genres,
    required this.selectedGenre,
    required this.onGenreSelected,
  });

  final List<GenreOption> genres;
  final GenreOption selectedGenre;
  final ValueChanged<GenreOption> onGenreSelected;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SizedBox(
      height: 44.0,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6.0,
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final genre = genres[index];
          final isSelected = genre == selectedGenre;

          final backgroundColor = isSelected
              ? AppColors.primary
              : (isLight
                  ? AppColors.lightSurfaceElevated
                  : AppColors.surfaceElevated);

          final borderColor = isSelected
              ? AppColors.primary
              : (isLight ? AppColors.borderLight : AppColors.borderDark);

          final textColor = isSelected
              ? AppColors.textOnPrimary
              : (isLight
                  ? AppColors.lightTextSecondary
                  : AppColors.textSecondary);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                AppHaptics.selectionClick();
                onGenreSelected(genre);
              },
              borderRadius: BorderRadius.circular(20.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 6.0,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  genre.displayName,
                  style: isSelected
                      ? AppTextStyles.xsBold.copyWith(
                          color: textColor,
                          height: 1.1,
                        )
                      : AppTextStyles.xsMedium.copyWith(
                          color: textColor,
                          height: 1.1,
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
