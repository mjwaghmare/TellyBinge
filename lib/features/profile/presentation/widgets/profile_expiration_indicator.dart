import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'profile_expiration_card.dart';

/// A circular progress indicator widget displayed in the app header (before
/// notifications icon).
///
/// UI Design:
/// - Transparent center (primary fill removed).
/// - Text color dynamically matches the indicator arc color (`indicatorColor`).
/// - Outer incrementing progress arc (Green / Yellow / Red based on remaining time).
/// - Tapping opens a Modal Bottom Sheet with the full profile expiration countdown UI.
class ProfileExpirationIndicator extends StatefulWidget {
  const ProfileExpirationIndicator({super.key});

  @override
  State<ProfileExpirationIndicator> createState() =>
      _ProfileExpirationIndicatorState();
}

class _ProfileExpirationIndicatorState
    extends State<ProfileExpirationIndicator> {
  DateTime? _expirationDate;
  Timer? _timer;
  bool _isLoading = true;

  static const int _totalSecondsIn6Days = 6 * 24 * 60 * 60; // 518,400 seconds

  @override
  void initState() {
    super.initState();
    _loadExpirationDate();
  }

  Future<void> _loadExpirationDate() async {
    final expirationDate =
        await NotificationService().getProfileExpirationDate();
    if (!mounted) return;
    setState(() {
      _expirationDate = expirationDate;
      _isLoading = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showBottomSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDarkMode
            ? AppColors.surfaceElevated
            : AppColors.lightSurfaceElevated;

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(
            top: AppSpacing.md,
            bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AppSpacing.gapH16,
              const ProfileExpirationCard(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _expirationDate == null) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final difference = _expirationDate!.difference(now);
    final isExpired = difference.isNegative || difference.inSeconds <= 0;

    final remainingSeconds = isExpired
        ? 0
        : difference.inSeconds.clamp(0, _totalSecondsIn6Days);
    final days = isExpired ? 0 : difference.inDays;
    final hours = isExpired ? 0 : (difference.inHours % 24);
    final minutes = isExpired ? 0 : (difference.inMinutes % 60);

    // Indicator color: Green (AppColors.success) for active, or status stage
    final Color indicatorColor;
    if (isExpired || remainingSeconds <= 24 * 3600) {
      indicatorColor = AppColors.error;
    } else if (remainingSeconds <= 3 * 24 * 3600) {
      indicatorColor = AppColors.primaryDark;
    } else {
      indicatorColor = AppColors.success; // Green
    }

    // Label formatting:
    // - 6d, 5d ... 1d (when days >= 1)
    // - 23h ... 1h (when days == 0 and hours >= 1)
    // - 60m, 59m ... 10m ... 1m (when under 60 mins)
    // - 0m (when expired)
    final String label;
    if (isExpired) {
      label = '0m';
    } else if (days >= 1) {
      label = '${days}d';
    } else if (hours >= 1) {
      label = '${hours}h';
    } else if (minutes > 0) {
      label = '${minutes}m';
    } else {
      label = '1m';
    }

    // Progress ratio: 1.0 (6 days left) down to 0.0 (0 days left)
    final double progress = (remainingSeconds / _totalSecondsIn6Days).clamp(
      0.0,
      1.0,
    );

    return Tooltip(
      message: 'Free Profile Expiry: $label remaining',
      child: GestureDetector(
        onTap: () => _showBottomSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Custom Painted Incremental Progress Arc (No center fill)
                CustomPaint(
                  size: const Size(36, 36),
                  painter: _IncrementalCircleIndicatorPainter(
                    progress: progress,
                    indicatorColor: indicatorColor,
                  ),
                ),
                // Centered Label Text with FittedBox scaling
                Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: indicatorColor,
                        letterSpacing: -0.3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that renders an outer incrementing progress arc (without center fill or background track).
class _IncrementalCircleIndicatorPainter extends CustomPainter {
  final double progress;
  final Color indicatorColor;

  _IncrementalCircleIndicatorPainter({
    required this.progress,
    required this.indicatorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // Draw incrementing progress arc around outer boundary
    if (progress > 0) {
      final arcPaint = Paint()
        ..color = indicatorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: outerRadius - 1.5);
      const startAngle = -3.141592653589793 / 2; // Top position (-90 deg)
      final sweepAngle = 2 * 3.141592653589793 * progress;
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IncrementalCircleIndicatorPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.indicatorColor != indicatorColor;
  }
}
