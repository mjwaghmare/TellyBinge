import 'dart:math' as math;
import 'dart:ui' show FontFeature, lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/achievement.dart';

/// A bottom sheet that shows detailed information about a single or stacked set of achievements.
class AchievementDetailBottomSheet extends StatelessWidget {
  final Achievement achievement;
  final bool isCelebration;

  const AchievementDetailBottomSheet({
    super.key,
    required this.achievement,
    this.isCelebration = false,
  });

  /// Calculates responsive sheet height ensuring proper breathing room and zero overflow.
  static double calculateSheetHeight(
    BuildContext context,
    Achievement achievement, {
    bool isCelebration = false,
  }) {
    final screenH = MediaQuery.of(context).size.height;
    if (achievement.hasTiers) {
      final ratio = isCelebration ? 0.32 : 0.37;
      return (screenH * ratio).clamp(310.0, 350.0);
    } else {
      final hasProgress = !achievement.isUnlocked && !isCelebration;
      final ratio = hasProgress ? 0.32 : 0.28;
      return (screenH * ratio).clamp(250.0, 305.0);
    }
  }

  /// Shows a single achievement bottom sheet.
  static Future<void> show(
    BuildContext context,
    Achievement achievement, {
    bool isCelebration = false,
  }) {
    return showStack(context, [achievement], isCelebration: isCelebration);
  }

  /// Shows a stacked set of achievements with a subtle ~4px-6px lip height and swipe transitions.
  static Future<void> showStack(
    BuildContext context,
    List<Achievement> achievements, {
    bool isCelebration = false,
  }) {
    if (achievements.isEmpty) return Future.value();

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _AchievementStackBottomSheet(
        achievements: achievements,
        isCelebration: isCelebration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final bottomMargin = (bottomPadding * 0.35).clamp(8.0, 12.0);
    final sheetHeight = calculateSheetHeight(
      context,
      achievement,
      isCelebration: isCelebration,
    );

    return Container(
      width: double.infinity,
      height: sheetHeight,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        bottomMargin,
      ),
      decoration: BoxDecoration(
        color: isLight ? AppColors.lightSurface : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight ? AppColors.borderLight : AppColors.borderDark,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _AchievementCardContent(
        achievement: achievement,
        isCelebration: isCelebration,
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
      return const [AppColors.textTertiary, AppColors.borderDark];
    }
    return switch (tier) {
      AchievementTier.none => [AppColors.primary, AppColors.primaryDark],
      AchievementTier.bronze => const [AppColors.bronze, AppColors.bronzeDark],
      AchievementTier.silver => const [AppColors.silver, AppColors.silverDark],
      AchievementTier.gold => const [AppColors.gold, AppColors.goldDark],
      AchievementTier.diamond => const [AppColors.diamond, AppColors.diamondDark],
    };
  }
}

class _AchievementStackBottomSheet extends StatefulWidget {
  final List<Achievement> achievements;
  final bool isCelebration;

  const _AchievementStackBottomSheet({
    required this.achievements,
    this.isCelebration = false,
  });

  @override
  State<_AchievementStackBottomSheet> createState() =>
      _AchievementStackBottomSheetState();
}

class _AchievementStackBottomSheetState
    extends State<_AchievementStackBottomSheet>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  double _dragOffset = 0.0;
  late AnimationController _animController;
  late Animation<double> _dismissAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isDismissing) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 400.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isDismissing) return;
    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffset > 60.0 || velocity > 320.0) {
      _dismissCurrentCard();
    } else {
      // Spring back to 0 smoothly
      final startOffset = _dragOffset;
      _dismissAnimation =
          Tween<double>(begin: startOffset, end: 0.0).animate(
            CurvedAnimation(
              parent: _animController,
              curve: Curves.easeOutCubic,
            ),
          )..addListener(() {
            setState(() {
              _dragOffset = _dismissAnimation.value;
            });
          });
      _animController.forward(from: 0.0);
    }
  }

  void _dismissCurrentCard() {
    _isDismissing = true;
    HapticFeedback.mediumImpact();
    final currentAchievement = widget.achievements[_currentIndex];
    final sheetHeight = AchievementDetailBottomSheet.calculateSheetHeight(
      context,
      currentAchievement,
      isCelebration: widget.isCelebration,
    );
    final startOffset = _dragOffset;
    _dismissAnimation =
        Tween<double>(begin: startOffset, end: sheetHeight + 60.0).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        )..addListener(() {
          setState(() {
            _dragOffset = _dismissAnimation.value;
          });
        });

    _animController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      if (_currentIndex + 1 < widget.achievements.length) {
        setState(() {
          _currentIndex++;
          _dragOffset = 0.0;
          _isDismissing = false;
        });
      } else {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final remaining = widget.achievements.length - _currentIndex;

    if (remaining <= 0) return const SizedBox.shrink();

    final activeAchievement = widget.achievements[_currentIndex];
    final sheetHeight = AchievementDetailBottomSheet.calculateSheetHeight(
      context,
      activeAchievement,
      isCelebration: widget.isCelebration,
    );
    const lipHeight = 5.0;
    final totalStackHeight =
        sheetHeight +
        (remaining >= 3 ? lipHeight * 2 : (remaining == 2 ? lipHeight : 0));

    // Progress fraction of the swipe dismissal from 0.0 to 1.0
    final t = (_dragOffset / 110.0).clamp(0.0, 1.0);

    // Color definitions for card layers
    final topCardColor = isLight
        ? AppColors.lightSurface
        : AppColors.surfaceElevated;
    final card1Color = isLight
        ? AppColors.lightSurfaceElevated
        : AppColors.surfaceStackedDark;
    final card2Color = isLight
        ? AppColors.borderLight
        : AppColors.surfaceStackedDarkElevated;

    // Interpolated values for Background Card 1 promoting to Top Card
    final card1Top = lerpDouble(lipHeight, lipHeight * 2, t) ?? lipHeight;
    final card1Margin =
        lerpDouble(AppSpacing.md + 4, AppSpacing.md, t) ?? AppSpacing.md;
    final card1CurrentColor =
        Color.lerp(card1Color, topCardColor, t) ?? card1Color;

    // Interpolated values for Background Card 2 promoting to Card 1
    final card2Top = lerpDouble(0, lipHeight, t) ?? 0;
    final card2Margin =
        lerpDouble(AppSpacing.md + 8, AppSpacing.md + 4, t) ??
        (AppSpacing.md + 4);
    final card2CurrentColor =
        Color.lerp(card2Color, card1Color, t) ?? card2Color;

    final bottomMargin = (bottomPadding * 0.35).clamp(8.0, 12.0);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomMargin),
      child: SizedBox(
        width: double.infinity,
        height: totalStackHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Background Card 3 (fades in as card 2 promotes if remaining >= 4)
            if (remaining >= 4 && t > 0.0)
              Positioned(
                top: 0,
                left: AppSpacing.md + 8,
                right: AppSpacing.md + 8,
                height: sheetHeight,
                child: Opacity(
                  opacity: t,
                  child: Container(
                    decoration: BoxDecoration(
                      color: card2Color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isLight
                            ? AppColors.borderLight
                            : AppColors.borderDark,
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _AchievementCardContent(
                        achievement: widget.achievements[_currentIndex + 3],
                        isCelebration: widget.isCelebration,
                      ),
                    ),
                  ),
                ),
              ),

            // Background Card 2 (3rd card in stack if remaining >= 3)
            if (remaining >= 3)
              Positioned(
                top: card2Top,
                left: card2Margin,
                right: card2Margin,
                height: sheetHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: card2CurrentColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isLight
                          ? AppColors.borderLight
                          : AppColors.borderDark,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.05 : 0.25,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _AchievementCardContent(
                      achievement: widget.achievements[_currentIndex + 2],
                      isCelebration: widget.isCelebration,
                    ),
                  ),
                ),
              ),

            // Background Card 1 (2nd card in stack if remaining >= 2)
            if (remaining >= 2)
              Positioned(
                top: card1Top,
                left: card1Margin,
                right: card1Margin,
                height: sheetHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: card1CurrentColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isLight
                          ? AppColors.borderLight
                          : AppColors.borderDark,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isLight ? 0.06 : 0.3,
                        ),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _AchievementCardContent(
                      achievement: widget.achievements[_currentIndex + 1],
                      isCelebration: widget.isCelebration,
                    ),
                  ),
                ),
              ),

            // Top / Active Card
            Positioned(
              bottom: 0,
              left: AppSpacing.md,
              right: AppSpacing.md,
              height: sheetHeight,
              child: GestureDetector(
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: Transform.translate(
                  offset: Offset(0, _dragOffset),
                  child: Container(
                    decoration: BoxDecoration(
                      color: topCardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isLight
                            ? AppColors.borderLight
                            : AppColors.borderDark,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isLight ? 0.1 : 0.45,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _AchievementCardContent(
                      achievement: activeAchievement,
                      isCelebration: widget.isCelebration,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the complete centered achievement card content with generous breathing room.
class _AchievementCardContent extends StatelessWidget {
  final Achievement achievement;
  final bool isCelebration;

  const _AchievementCardContent({
    required this.achievement,
    this.isCelebration = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final tierColors = AchievementDetailBottomSheet._tierGradient(
      achievement.tier,
      achievement.isUnlocked,
    );

    final showStepper = achievement.hasTiers;
    final showTierProgress = achievement.hasTiers && !isCelebration;
    final showSingleProgress =
        !achievement.hasTiers && !achievement.isUnlocked && !isCelebration;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          // 1. Drag handle positioned at the top rim
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 2. Content below drag handle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Centered Tier Pill (Placed ABOVE badge medallion)
                if (achievement.tier != AchievementTier.none)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: tierColors.first.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: tierColors.first.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${AchievementDetailBottomSheet._tierLabel(achievement.tier)} TIER${achievement.isMaxTier ? ' (MAX)' : ''}',
                      style: AppTextStyles.xsBold.copyWith(
                        color: tierColors.first,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                // Centered Badge Emblem
                _BadgeEmblem(
                  achievement: achievement,
                  tierColors: tierColors,
                  size: achievement.hasTiers
                      ? 84
                      : (achievement.isUnlocked ? 108 : 100),
                ),

                // Centered Title
                Text(
                  achievement.title,
                  style: AppTextStyles.lg.copyWith(
                    color: isLight
                        ? AppColors.lightTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Centered Description
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Text(
                    achievement.description,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sm.copyWith(
                      color: isLight
                          ? AppColors.lightTextSecondary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Stepper for multi-tier badges
                if (showStepper)
                  _TierMilestoneStepper(achievement: achievement),

                // Progress for multi-tier badges
                if (showTierProgress)
                  _TierNextProgress(achievement: achievement),

                // Progress indicator for pending single-tier achievements
                if (showSingleProgress)
                  _AchievementProgress(achievement: achievement),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the connected milestone progression track for multi-tier badges.
class _TierMilestoneStepper extends StatelessWidget {
  final Achievement achievement;

  const _TierMilestoneStepper({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final tiers = achievement.tierTargets;
    if (tiers == null || tiers.isEmpty) return const SizedBox.shrink();

    final entries = tiers.entries.toList();
    final currentVal = achievement.currentValue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            _buildMilestoneNode(context, entries[i], currentVal, isLight),
            if (i < entries.length - 1)
              Expanded(
                child: Container(
                  height: 24,
                  alignment: Alignment.center,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: currentVal >= entries[i + 1].value
                          ? (isLight
                              ? AppColors.primary
                              : AppColors.primaryLight)
                          : (isLight
                              ? AppColors.borderLight
                              : AppColors.borderDark),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneNode(
    BuildContext context,
    MapEntry<AchievementTier, int> entry,
    int currentVal,
    bool isLight,
  ) {
    final tier = entry.key;
    final target = entry.value;
    final isReached = currentVal >= target;
    final isNext = achievement.nextTier == tier;
    final tierColors = AchievementDetailBottomSheet._tierGradient(tier, true);
    final tierColor = tierColors.first;

    final Color nodeBg;
    final Color nodeBorder;
    final Widget nodeContent;

    if (isReached) {
      nodeBg = tierColor.withValues(alpha: isLight ? 0.16 : 0.26);
      nodeBorder = tierColor;
      nodeContent = Icon(
        Icons.check_rounded,
        size: 13,
        color: isLight ? tierColor : AppColors.textOnPrimary,
      );
    } else if (isNext) {
      nodeBg = AppColors.primary.withValues(alpha: isLight ? 0.14 : 0.22);
      nodeBorder = AppColors.primary;
      nodeContent = Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary,
        ),
      );
    } else {
      nodeBg = isLight
          ? AppColors.lightSurfaceElevated
          : AppColors.surfaceElevated;
      nodeBorder = isLight ? AppColors.borderLight : AppColors.borderDark;
      nodeContent = Icon(
        Icons.lock_rounded,
        size: 10,
        color: isLight ? AppColors.lightTextTertiary : AppColors.textTertiary,
      );
    }

    final rawTier = AchievementDetailBottomSheet._tierLabel(tier);
    final tierTitle = rawTier.isNotEmpty
        ? '${rawTier[0]}${rawTier.substring(1).toLowerCase()}'
        : '';
    final targetLabel = target >= 1000
        ? '${(target / 1000).toStringAsFixed(target % 1000 == 0 ? 0 : 1)}k'
        : '$target';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: nodeBg,
            border: Border.all(color: nodeBorder, width: 1.5),
            boxShadow: isReached
                ? [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Center(child: nodeContent),
        ),
        const SizedBox(height: 4),
        Text(
          tierTitle,
          style: AppTextStyles.xs.copyWith(
            fontSize: 10,
            fontWeight: isNext
                ? FontWeight.bold
                : (isReached ? FontWeight.w600 : FontWeight.normal),
            color: isReached
                ? (isLight ? AppColors.lightTextPrimary : AppColors.textPrimary)
                : (isNext
                    ? AppColors.primaryLight
                    : (isLight
                        ? AppColors.lightTextTertiary
                        : AppColors.textTertiary)),
          ),
        ),
        Text(
          targetLabel,
          style: AppTextStyles.xs.copyWith(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: isReached
                ? (isLight ? tierColor : AppColors.primaryLight)
                : (isLight
                    ? AppColors.lightTextTertiary
                    : AppColors.textTertiary),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Renders the next tier milestone goal and progress indicator.
class _TierNextProgress extends StatelessWidget {
  final Achievement achievement;

  const _TierNextProgress({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    if (achievement.isMaxTier) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.stars_rounded,
              color: AppColors.success,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              'ALL TIERS COMPLETED',
              style: AppTextStyles.xsBold.copyWith(
                color: AppColors.success,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    final nextTier = achievement.nextTier;
    final nextTarget = achievement.nextTierTarget ?? achievement.targetValue;
    final current = achievement.currentValue;
    final remaining = (nextTarget - current).clamp(0, nextTarget);
    final progress =
        nextTarget > 0 ? (current / nextTarget).clamp(0.0, 1.0) : 0.0;
    final rawTier = nextTier != null
        ? AchievementDetailBottomSheet._tierLabel(nextTier)
        : '';
    final nextTierTitle = rawTier.isNotEmpty
        ? '${rawTier[0]}${rawTier.substring(1).toLowerCase()} Tier'
        : 'Next Tier';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next: $nextTierTitle ($current / $nextTarget)',
                style: AppTextStyles.xsMedium.copyWith(
                  color: isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$remaining remaining',
                style: AppTextStyles.xsMedium.copyWith(
                  color: isLight ? AppColors.primary : AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isLight
                  ? AppColors.borderLight
                  : AppColors.borderDark,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the progress bar and completed / remaining indicators for pending achievements.
class _AchievementProgress extends StatelessWidget {
  final Achievement achievement;

  const _AchievementProgress({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final current = achievement.currentValue;
    final target = achievement.targetValue;
    final remaining = (target - current).clamp(0, target);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$current / $target completed',
                style: AppTextStyles.xsMedium.copyWith(
                  color: isLight
                      ? AppColors.lightTextSecondary
                      : AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$remaining remaining',
                style: AppTextStyles.xsMedium.copyWith(
                  color: isLight ? AppColors.primary : AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: achievement.progress,
              minHeight: 6,
              backgroundColor: isLight
                  ? AppColors.borderLight
                  : AppColors.borderDark,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders the circular badge emblem with custom artwork, tier styling,
/// and a realistic 3D coin flip (3D perspective pitch tilt, dual-face metal back,
/// dynamic specular lighting, and metallic gleam shimmer).
class _BadgeEmblem extends StatefulWidget {
  final Achievement achievement;
  final List<Color> tierColors;
  final double size;

  const _BadgeEmblem({
    required this.achievement,
    required this.tierColors,
    required this.size,
  });

  @override
  State<_BadgeEmblem> createState() => _BadgeEmblemState();
}

class _BadgeEmblemState extends State<_BadgeEmblem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _flipAnim;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _scaleAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutBack),
      ),
    );

    _flipAnim = Tween<double>(begin: math.pi * 2, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    _shimmerAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(_BadgeEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.achievement != oldWidget.achievement) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapSpin() {
    if (_controller.isAnimating) return;
    HapticFeedback.lightImpact();
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final size = widget.size;
    final achievement = widget.achievement;
    final tierColors = widget.tierColors;
    final primaryTierColor = tierColors.first;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: _onTapSpin,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final flipVal = _flipAnim.value;
            final scaleVal = _scaleAnim.value;
            final shimmerVal = _shimmerAnim.value;

            final cosVal = math.cos(flipVal);
            final isFront = cosVal >= 0;
            // Shading intensity: darkest when edge-on (cosVal ~ 0)
            final edgeDarkness = (1.0 - cosVal.abs()).clamp(0.0, 1.0);
            // 3D edge thickness offset in pixels
            final edgeOffset = math.sin(flipVal) * 3.5;

            return Transform.scale(
              scale: scaleVal,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018) // realistic camera perspective
                  ..rotateX(-0.14) // pitch tilt down so circular disc shows 3D elliptical depth
                  ..rotateY(flipVal), // 3D spin
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: achievement.isUnlocked
                        ? [
                            BoxShadow(
                              color: primaryTierColor.withValues(
                                alpha: 0.35 * _controller.value,
                              ),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 3D Coin Rim / Thickness (shows when medal is turned in 3D)
                      if (edgeOffset.abs() > 0.4)
                        Transform.translate(
                          offset: Offset(edgeOffset, 0),
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryTierColor.withValues(alpha: 0.5),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                          ),
                        ),

                      // Front and Back faces of the medal (Opacity maintains Image in tree)
                      ClipOval(
                        child: Stack(
                          children: [
                            // Back face (brushed metallic engraved medal back)
                            Opacity(
                              opacity: isFront ? 0.0 : 1.0,
                              child: _buildBackFace(
                                context,
                                size,
                                primaryTierColor,
                                isLight,
                              ),
                            ),

                            // Front face (badge artwork)
                            Opacity(
                              opacity: isFront ? 1.0 : 0.0,
                              child: _buildFrontFace(context, size, isLight),
                            ),

                            // Dynamic 3D lighting shadow based on rotation angle
                            if (edgeDarkness > 0.05)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(
                                    alpha: edgeDarkness * 0.45,
                                  ),
                                ),
                              ),

                            // Metallic gleam sweep when front face settles
                            if (isFront &&
                                achievement.isUnlocked &&
                                shimmerVal > 0.0 &&
                                shimmerVal < 1.0)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Transform.rotate(
                                    angle: -math.pi / 4,
                                    child: Transform.translate(
                                      offset: Offset(
                                        -size + (shimmerVal * size * 2.5),
                                        0,
                                      ),
                                      child: Container(
                                        width: size * 0.45,
                                        height: size * 2.2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0.0),
                                              Colors.white.withValues(alpha: 0.45),
                                              Colors.white.withValues(alpha: 0.0),
                                            ],
                                            stops: const [0.0, 0.5, 1.0],
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

                      // Locked badge overlay indicator
                      if (!achievement.isUnlocked && isFront)
                        Container(
                          width: size * 0.38,
                          height: size * 0.38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.65),
                            border: Border.all(
                              color: AppColors.borderDark,
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.lock_rounded,
                              color: AppColors.textOnPrimary,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFrontFace(BuildContext context, double size, bool isLight) {
    final achievement = widget.achievement;
    final tierColors = widget.tierColors;

    final imageContent = Image.asset(
      achievement.assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: isLight
            ? AppColors.lightSurfaceElevated
            : AppColors.surface,
        child: Icon(
          achievement.icon,
          size: size * 0.4,
          color: tierColors.first,
        ),
      ),
    );

    if (achievement.isUnlocked) {
      return imageContent;
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      0.4, 0,
      ]),
      child: imageContent,
    );
  }

  Widget _buildBackFace(
    BuildContext context,
    double size,
    Color tierColor,
    bool isLight,
  ) {
    return Transform.flip(
      flipX: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              tierColor.withValues(alpha: 0.85),
              tierColor.withValues(alpha: 0.4),
              Colors.black87,
            ],
            stops: const [0.3, 0.75, 1.0],
          ),
          border: Border.all(
            color: tierColor.withValues(alpha: 0.6),
            width: 3.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Inner concentric engraved medal ring
            Container(
              width: size * 0.75,
              height: size * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),
            // Embossed star emblem on the back
            Icon(
              Icons.stars_rounded,
              size: size * 0.38,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );
  }
}
