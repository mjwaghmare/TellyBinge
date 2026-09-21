import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../domain/models/achievement.dart';
import 'achievement_detail_bottom_sheet.dart';

/// Floating Bottom Sheet displayed whenever an achievement is unlocked.
class AchievementUnlockBanner {
  AchievementUnlockBanner._();

  static final List<Achievement> _queue = [];
  static bool _isShowing = false;

  /// Shows the achievement unlock floating bottom sheet on top of the active route.
  /// If multiple achievements are queued, presents them as a stacked deck with ~4-6px lip height.
  static void show(BuildContext context, Achievement achievement) {
    _queue.add(achievement);
    if (!_isShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && !_isShowing) {
          _showBatch(context);
        }
      });
    }
  }

  static void _showBatch(BuildContext context) {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);
    final navContext = navigator.context;

    final batch = List<Achievement>.from(_queue);
    _queue.clear();
    _isShowing = true;

    AppHaptics.heavyImpact();

    AchievementDetailBottomSheet.showStack(
      navContext,
      batch,
      isCelebration: true,
    ).then((_) {
      _isShowing = false;
      if (_queue.isNotEmpty && context.mounted) {
        _showBatch(context);
      }
    });
  }
}
