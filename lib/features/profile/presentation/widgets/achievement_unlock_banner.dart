import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/achievement.dart';
import 'achievement_detail_bottom_sheet.dart';

/// Floating in-app notification banner displayed whenever an achievement is unlocked.
class AchievementUnlockBanner {
  AchievementUnlockBanner._();

  static final List<Achievement> _queue = [];
  static OverlayEntry? _currentEntry;
  static bool _isShowing = false;

  /// Shows the achievement unlock banner on top of the active route.
  /// If another banner is currently active, queues it for sequential presentation.
  static void show(BuildContext context, Achievement achievement) {
    _queue.add(achievement);
    if (!_isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && !_isShowing) {
          _showNext(context);
        }
      });
    }
  }

  static void _showNext(BuildContext context) {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }

    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) {
      _isShowing = false;
      return;
    }

    final achievement = _queue.removeAt(0);
    _isShowing = true;

    HapticFeedback.heavyImpact();

    _currentEntry = OverlayEntry(
      builder: (context) => _BannerOverlayWidget(
        achievement: achievement,
        onDismissed: () {
          _currentEntry?.remove();
          _currentEntry = null;
          // Small pause before presenting next queued achievement
          Future.delayed(const Duration(milliseconds: 300), () {
            if (context.mounted) {
              _showNext(context);
            } else {
              _isShowing = false;
            }
          });
        },
      ),
    );

    overlay.insert(_currentEntry!);
  }
}

class _BannerOverlayWidget extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismissed;

  const _BannerOverlayWidget({
    required this.achievement,
    required this.onDismissed,
  });

  @override
  State<_BannerOverlayWidget> createState() => _BannerOverlayWidgetState();
}

class _BannerOverlayWidgetState extends State<_BannerOverlayWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();

    _dismissTimer = Timer(const Duration(milliseconds: 4200), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismissed();
      });
    } else {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + AppSpacing.xs,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => _dismiss(),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  _dismiss();
                  AchievementDetailBottomSheet.show(
                    context,
                    widget.achievement,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isLight
                        ? Colors.white.withValues(alpha: 0.96)
                        : AppColors.surfaceElevated.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Badge icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: isLight ? Colors.grey[200] : Colors.grey[900],
                          child: Image.asset(
                            widget.achievement.assetPath,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              widget.achievement.icon,
                              color: AppColors.primary,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events_rounded,
                                  color: AppColors.primaryLight,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ACHIEVEMENT UNLOCKED!',
                                  style: AppTextStyles.xsBold.copyWith(
                                    color: AppColors.primaryLight,
                                    fontSize: 10.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.achievement.title}${_tierSuffix(widget.achievement.tier)}',
                              style: AppTextStyles.smMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isLight
                                    ? AppColors.lightTextPrimary
                                    : AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.achievement.description,
                              style: AppTextStyles.xs.copyWith(
                                color: isLight
                                    ? AppColors.lightTextSecondary
                                    : AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Arrow indicator
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _tierSuffix(AchievementTier tier) {
    return switch (tier) {
      AchievementTier.none => '',
      AchievementTier.bronze => ' 🥉',
      AchievementTier.silver => ' 🥈',
      AchievementTier.gold => ' 🥇',
      AchievementTier.diamond => ' 💎',
    };
  }
}
