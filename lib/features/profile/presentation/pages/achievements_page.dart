import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../domain/models/achievement.dart';
import '../cubit/achievements_cubit.dart';
import '../cubit/achievements_state.dart';
import '../widgets/achievement_detail_bottom_sheet.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AchievementsView();
  }
}

class _AchievementsView extends StatefulWidget {
  const _AchievementsView();

  @override
  State<_AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends State<_AchievementsView> {
  @override
  void initState() {
    super.initState();
    _evaluateAchievements();
  }

  void _evaluateAchievements() {
    AchievementsCubit.evaluateFromContext(context, notify: true);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return MultiBlocListener(
      listeners: [
        BlocListener<MovieWatchlistCubit, MovieWatchlistState>(
          listenWhen: (previous, current) => current is MovieWatchlistSuccess,
          listener: (context, state) => _evaluateAchievements(),
        ),
        BlocListener<TvShowWatchlistCubit, TvShowWatchlistState>(
          listenWhen: (previous, current) => current is TvShowWatchlistSuccess,
          listener: (context, state) => _evaluateAchievements(),
        ),
      ],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isLight
                  ? AppColors.lightTextPrimary
                  : AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Achievements',
            style: AppTextStyles.xl.copyWith(
              color: isLight
                  ? AppColors.lightTextPrimary
                  : AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: false,
        ),
        body: BlocBuilder<AchievementsCubit, AchievementsState>(
          builder: (context, state) {
            if (state is! AchievementsLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return Column(
              children: [
                // Unlocked summary
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs + 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: AppColors.primaryLight,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${state.unlockedCount} / ${state.totalCount} Unlocked',
                              style: AppTextStyles.xsMedium.copyWith(
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Category filter chips
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: state.activeFilter == null,
                        onTap: () =>
                            context.read<AchievementsCubit>().setFilter(null),
                      ),
                      ...AchievementCategory.values.map(
                        (cat) => _FilterChip(
                          label: _categoryLabel(cat),
                          isSelected: state.activeFilter == cat,
                          onTap: () =>
                              context.read<AchievementsCubit>().setFilter(cat),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // 3-column grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: AppSpacing.md,
                          crossAxisSpacing: AppSpacing.sm,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: state.filtered.length,
                    itemBuilder: (context, index) {
                      final achievement = state.filtered[index];
                      return _AchievementGridTile(
                        achievement: achievement,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          AchievementDetailBottomSheet.show(
                            context,
                            achievement,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _categoryLabel(AchievementCategory cat) {
    return switch (cat) {
      AchievementCategory.volume => 'Volume',
      AchievementCategory.habits => 'Habits',
      AchievementCategory.genres => 'Genres',
      AchievementCategory.streaks => 'Streaks',
      AchievementCategory.special => 'Special',
    };
  }
}

// ── FILTER CHIP ──

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isLight ? AppColors.borderLight : AppColors.borderDark),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.xsMedium.copyWith(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isLight
                        ? AppColors.lightTextSecondary
                        : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

// ── GRID TILE ──

class _AchievementGridTile extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;

  const _AchievementGridTile({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Derive badge diameter responsively from available tile constraints,
        // leaving enough vertical room for text and spacing
        const textReserve = 34.0;
        const spacing = AppSpacing.xs;
        final maxH = (constraints.maxHeight - textReserve - spacing).clamp(
          48.0,
          96.0,
        );
        final maxW = (constraints.maxWidth - AppSpacing.xs).clamp(48.0, 96.0);
        final badgeSize = maxH < maxW ? maxH : maxW;

        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge circle
              _buildBadgeCircle(isLight, badgeSize),
              const SizedBox(height: spacing),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.xsMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: achievement.isUnlocked
                        ? (isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary)
                        : (isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary),
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeCircle(bool isLight, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ColorFiltered(
              colorFilter: achievement.isUnlocked
                  ? const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    )
                  : const ColorFilter.matrix(<double>[
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      0,
                      0,
                      0,
                      0,
                      0.35,
                      0,
                    ]),
              child: Image.asset(
                achievement.assetPath,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: size,
                  height: size,
                  color: isLight ? Colors.grey[300] : Colors.grey[800],
                  child: Icon(
                    achievement.icon,
                    size: size * 0.4,
                    color: achievement.isUnlocked
                        ? AppColors.primary
                        : (isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
          if (!achievement.isUnlocked)
            Container(
              width: (size * 0.3).clamp(18.0, 26.0),
              height: (size * 0.3).clamp(18.0, 26.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.65),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: (size * 0.15).clamp(10.0, 14.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
