import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../domain/models/achievement.dart';
import '../cubit/achievements_cubit.dart';
import '../cubit/achievements_state.dart';
import '../widgets/achievement_detail_bottom_sheet.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AchievementsCubit(),
      child: const _AchievementsView(),
    );
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
    final movieState = context.read<MovieWatchlistCubit>().state;
    final showState = context.read<TvShowWatchlistCubit>().state;

    final movies = movieState is MovieWatchlistSuccess ? movieState.movies : <Map<String, dynamic>>[];
    final shows = showState is TvShowWatchlistSuccess ? showState.shows : <Map<String, dynamic>>[];

    context.read<AchievementsCubit>().evaluate(
      movies: movies,
      shows: shows,
    );
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
              color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Achievements',
            style: AppTextStyles.xl.copyWith(
              color: isLight ? AppColors.lightTextPrimary : AppColors.textPrimary,
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
                height: 44,
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
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: state.filtered.length,
                  itemBuilder: (context, index) {
                    final achievement = state.filtered[index];
                    return _AchievementGridTile(
                      achievement: achievement,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AchievementDetailBottomSheet.show(
                            context, achievement);
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
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isLight
                    ? Colors.black.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(20),
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

  const _AchievementGridTile({
    required this.achievement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final tierColors = _tierGradient(achievement.tier, achievement.isUnlocked);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isLight ? Colors.white : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: achievement.isUnlocked
                ? tierColors.first.withValues(alpha: 0.3)
                : (isLight
                    ? AppColors.borderLight
                    : Colors.white.withValues(alpha: 0.04)),
            width: 1,
          ),
          boxShadow: achievement.isUnlocked
              ? [
                  BoxShadow(
                    color: tierColors.first.withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge circle
            _buildBadgeCircle(isLight, tierColors),
            const SizedBox(height: AppSpacing.xs),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
              child: Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  color: achievement.isUnlocked
                      ? (isLight
                          ? AppColors.lightTextPrimary
                          : AppColors.textPrimary)
                      : (isLight
                          ? AppColors.lightTextTertiary
                          : AppColors.textTertiary),
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),

            // Tier or progress indicator
            if (achievement.isUnlocked &&
                achievement.tier != AchievementTier.none)
              _buildTierDot(tierColors)
            else if (!achievement.isUnlocked)
              _buildProgressIndicator(isLight, tierColors),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCircle(bool isLight, List<Color> tierColors) {
    const double size = 52;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipOval(
            child: ColorFiltered(
              colorFilter: achievement.isUnlocked
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                  : const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      0.4, 0,
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
                    size: 24,
                    color: tierColors.first,
                  ),
                ),
              ),
            ),
          ),
          if (!achievement.isUnlocked)
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.65),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildTierDot(List<Color> tierColors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: tierColors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _tierShort(achievement.tier),
        style: AppTextStyles.xs.copyWith(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isLight, List<Color> tierColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: achievement.progress,
          minHeight: 3,
          backgroundColor: isLight
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.06),
          valueColor: AlwaysStoppedAnimation(
            tierColors.first.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  static String _tierShort(AchievementTier tier) {
    return switch (tier) {
      AchievementTier.none => '',
      AchievementTier.bronze => '🥉',
      AchievementTier.silver => '🥈',
      AchievementTier.gold => '🥇',
      AchievementTier.diamond => '💎',
    };
  }

  static List<Color> _tierGradient(AchievementTier tier, bool isUnlocked) {
    if (!isUnlocked) {
      return const [Color(0xFF636366), Color(0xFF48484A)];
    }
    return switch (tier) {
      AchievementTier.none => [AppColors.primary, AppColors.primaryDark],
      AchievementTier.bronze => const [Color(0xFFCD7F32), Color(0xFFA0522D)],
      AchievementTier.silver => const [Color(0xFFC0C0C0), Color(0xFF808080)],
      AchievementTier.gold => const [Color(0xFFFFD700), Color(0xFFDAA520)],
      AchievementTier.diamond => const [Color(0xFFB9F2FF), Color(0xFF4FC3F7)],
    };
  }
}
