import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/achievement.dart';

/// A bottom sheet that shows detailed information about a single or stacked set of achievements.
class AchievementDetailBottomSheet extends StatelessWidget {
  final Achievement achievement;

  const AchievementDetailBottomSheet({
    super.key,
    required this.achievement,
  });

  /// Shows a single achievement bottom sheet.
  static Future<void> show(BuildContext context, Achievement achievement) {
    return showStack(context, [achievement]);
  }

  /// Shows a stacked set of achievements with a subtle ~4px-6px lip height and swipe transitions.
  static Future<void> showStack(
    BuildContext context,
    List<Achievement> achievements,
  ) {
    if (achievements.isEmpty) return Future.value();

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => _AchievementStackBottomSheet(
        achievements: achievements,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final sheetHeight = MediaQuery.of(context).size.height * 0.35;

    return Container(
      width: double.infinity,
      height: sheetHeight,
      margin: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        bottomPadding + AppSpacing.sm,
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
      child: _AchievementCardContent(achievement: achievement),
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
      AchievementTier.bronze => const [Color(0xFFCD7F32), Color(0xFFA0522D)],
      AchievementTier.silver => const [Color(0xFFC0C0C0), Color(0xFF808080)],
      AchievementTier.gold => const [Color(0xFFFFD700), Color(0xFFDAA520)],
      AchievementTier.diamond => const [Color(0xFFB9F2FF), Color(0xFF4FC3F7)],
    };
  }
}

class _AchievementStackBottomSheet extends StatefulWidget {
  final List<Achievement> achievements;

  const _AchievementStackBottomSheet({
    required this.achievements,
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
      _dismissAnimation = Tween<double>(begin: startOffset, end: 0.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
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
    final sheetHeight = MediaQuery.of(context).size.height * 0.35;
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
    final sheetHeight = MediaQuery.of(context).size.height * 0.35;
    const lipHeight = 5.0;
    final totalStackHeight =
        sheetHeight +
        (remaining >= 3 ? lipHeight * 2 : (remaining == 2 ? lipHeight : 0));

    // Progress fraction of the swipe dismissal from 0.0 to 1.0
    final t = (_dragOffset / 110.0).clamp(0.0, 1.0);

    // Color definitions for card layers
    final topCardColor =
        isLight ? AppColors.lightSurface : AppColors.surfaceElevated;
    final card1Color =
        isLight ? AppColors.lightSurfaceElevated : const Color(0xFF2E2E2E);
    final card2Color =
        isLight ? AppColors.borderLight : const Color(0xFF383838);

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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding + AppSpacing.sm),
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

  const _AchievementCardContent({
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final tierColors = AchievementDetailBottomSheet._tierGradient(
      achievement.tier,
      achievement.isUnlocked,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs + 2,
        AppSpacing.lg,
        AppSpacing.md,
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
                      horizontal: 14,
                      vertical: 4,
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
                      '${AchievementDetailBottomSheet._tierLabel(achievement.tier)} TIER',
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
                  size: 108,
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
              ],
            ),
          ),
        ],
      ),
    );
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
                  color: tierColors.first.withValues(alpha: 0.38),
                  blurRadius: 26,
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
                  ? const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    )
                  : const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 0.4, 0,
                    ]),
              child: Image.asset(
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
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

