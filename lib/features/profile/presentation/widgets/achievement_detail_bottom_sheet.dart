import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/achievement.dart';

/// A bottom sheet that shows detailed information about a single achievement.
class AchievementDetailBottomSheet extends StatelessWidget {
  final Achievement achievement;

  const AchievementDetailBottomSheet({
    super.key,
    required this.achievement,
  });

  static Future<void> show(BuildContext context, Achievement achievement) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AchievementDetailBottomSheet(achievement: achievement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final tierColors = _tierGradient(achievement.tier, achievement.isUnlocked);

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + AppSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isLight
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Badge emblem
            _BadgeEmblem(
              achievement: achievement,
              tierColors: tierColors,
              size: 100,
            ),
            const SizedBox(height: AppSpacing.md),

            // Tier pill
            if (achievement.tier != AchievementTier.none)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: tierColors,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_tierLabel(achievement.tier)} TIER',
                  style: AppTextStyles.xsBold.copyWith(
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            if (achievement.tier != AchievementTier.none)
              const SizedBox(height: AppSpacing.sm),

            // Title
            Text(
              achievement.title,
              style: AppTextStyles.lg.copyWith(
                color: isLight
                    ? AppColors.lightTextPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: AppTextStyles.sm.copyWith(
                  color: isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Progress bar section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                children: [
                  // Progress labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${achievement.currentValue} / ${achievement.targetValue}',
                        style: AppTextStyles.smMedium.copyWith(
                          color: isLight
                              ? AppColors.lightTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${(achievement.progress * 100).round()}%',
                        style: AppTextStyles.smMedium.copyWith(
                          color: achievement.isUnlocked
                              ? tierColors.first
                              : (isLight
                                  ? AppColors.lightTextTertiary
                                  : AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Animated progress bar
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: achievement.progress),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: isLight
                              ? Colors.black.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: tierColors),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Status
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: achievement.isUnlocked
                    ? tierColors.first.withValues(alpha: 0.12)
                    : (isLight
                        ? Colors.black.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    achievement.isUnlocked
                        ? Icons.check_circle_rounded
                        : Icons.lock_outline_rounded,
                    color: achievement.isUnlocked
                        ? tierColors.first
                        : (isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary),
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    achievement.isUnlocked ? 'Unlocked' : 'Locked',
                    style: AppTextStyles.smMedium.copyWith(
                      color: achievement.isUnlocked
                          ? tierColors.first
                          : (isLight
                              ? AppColors.lightTextTertiary
                              : AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _tierLabel(AchievementTier tier) {
    return switch (tier) {
      AchievementTier.none => '',
      AchievementTier.bronze => 'BRONZE',
      AchievementTier.silver => 'SILVER',
      AchievementTier.gold => 'GOLD',
      AchievementTier.diamond => 'DIAMOND',
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

/// Renders the circular badge emblem with custom artwork and tier styling.
class _BadgeEmblem extends StatelessWidget {
  final Achievement achievement;
  final List<Color> tierColors;
  final double size;

  const _BadgeEmblem({
    required this.achievement,
    required this.tierColors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: achievement.isUnlocked
            ? [
                BoxShadow(
                  color: tierColors.first.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Clip circular badge artwork
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
                    size: size * 0.4,
                    color: tierColors.first,
                  ),
                ),
              ),
            ),
          ),
          // Locked badge overlay indicator
          if (!achievement.isUnlocked)
            Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.65),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

