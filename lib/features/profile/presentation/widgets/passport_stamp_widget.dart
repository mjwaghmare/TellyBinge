import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/models/cinema_passport.dart';

/// A widget that renders an authentic physical ink immigration stamp.
///
/// Features shape variation (circular, rounded-rectangle Schengen style,
/// US CBP oval, and Japanese landing hexagon), physical ink bleed,
/// hand-stamped rotation tilts, and official border control typography.
class PassportStampWidget extends StatelessWidget {
  final PassportStamp stamp;
  final VoidCallback? onTap;
  final double size;

  const PassportStampWidget({
    super.key,
    required this.stamp,
    this.onTap,
    this.size = 148,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlocked = stamp.isUnlocked;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return GestureDetector(
      onTap: () {
        AppHaptics.lightImpact();
        onTap?.call();
      },
      child: Transform.rotate(
        angle: isUnlocked ? stamp.rotationAngle : 0.0,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: isUnlocked
                ? stamp.inkColor.withValues(alpha: 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: stamp.inkColor.withValues(alpha: 0.12),
                      blurRadius: 6,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(
            painter: _AuthenticStampPainter(
              stamp: stamp,
              isUnlocked: isUnlocked,
              isLight: isLight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isUnlocked) ...[
                      // Top immigration code / admission tag
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 6.0,
                              color: stamp.inkColor.withValues(alpha: 0.85),
                            ),
                            AppSpacing.gapW4,
                            Text(
                              stamp.entryCode ?? 'ADMITTED',
                              style: AppTextStyles.xsBold.copyWith(
                                fontSize: 6.5,
                                letterSpacing: 1.2,
                                color: stamp.inkColor.withValues(alpha: 0.88),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            AppSpacing.gapW4,
                            Icon(
                              Icons.star,
                              size: 6.0,
                              color: stamp.inkColor.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.gapH4,
                      // Main Stamp Title
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stamp.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: AppTextStyles.xsBold.copyWith(
                            fontSize: 10.5,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                            color: stamp.inkColor.withValues(alpha: 0.94),
                          ),
                        ),
                      ),
                      AppSpacing.gapH4,
                      // Middle Boxed Date Line (Official entry date)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.micro,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: stamp.inkColor.withValues(alpha: 0.80),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            stamp.unlockedDate ?? 'VERIFIED ENTRY',
                            style: AppTextStyles.xsBold.copyWith(
                              fontSize: 7.0,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w800,
                              color: stamp.inkColor.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ),
                      AppSpacing.gapH4,
                      // Subtitle / Authority Department
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stamp.subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.xsBold.copyWith(
                            fontSize: 6.0,
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w700,
                            color: stamp.inkColor.withValues(alpha: 0.80),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Locked State
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 22,
                        color: isLight
                            ? AppColors.lightTextTertiary
                            : AppColors.textTertiary,
                      ),
                      AppSpacing.gapH4,
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stamp.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: AppTextStyles.xsBold.copyWith(
                            fontSize: 9.5,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: isLight
                                ? AppColors.lightTextTertiary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      AppSpacing.gapH4,
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.micro,
                          ),
                          decoration: BoxDecoration(
                            color: isLight
                                ? AppColors.borderLight.withValues(alpha: 0.5)
                                : AppColors.borderDark.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${stamp.currentCount} / ${stamp.requiredCount}',
                            style: AppTextStyles.xsBold.copyWith(
                              fontSize: 7.5,
                              color: isLight
                                  ? AppColors.lightTextTertiary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering authentic double-ring physical stamp borders
/// with geometry variations for Schengen rectangles, Japanese hexagons,
/// US CBP ovals, and classic consular circles.
class _AuthenticStampPainter extends CustomPainter {
  final PassportStamp stamp;
  final bool isUnlocked;
  final bool isLight;

  _AuthenticStampPainter({
    required this.stamp,
    required this.isUnlocked,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);

    if (isUnlocked) {
      final inkPaint = Paint()
        ..color = stamp.inkColor.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      final innerPaint = Paint()
        ..color = stamp.inkColor.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      switch (stamp.shape) {
        case PassportStampShape.roundedRectangle:
          _drawRoundedRectangleStamp(canvas, rect, inkPaint, innerPaint);
          break;
        case PassportStampShape.hexagonal:
          _drawHexagonalStamp(canvas, center, size.width / 2 - 3, inkPaint, innerPaint);
          break;
        case PassportStampShape.oval:
          _drawOvalStamp(canvas, rect, inkPaint, innerPaint);
          break;
        case PassportStampShape.circular:
          _drawCircularStamp(canvas, center, size.width / 2 - 3, inkPaint, innerPaint);
          break;
      }
    } else {
      _drawLockedBorder(canvas, size, center);
    }
  }

  void _drawCircularStamp(
    Canvas canvas,
    Offset center,
    double radius,
    Paint outerPaint,
    Paint innerPaint,
  ) {
    final outerRadius = radius;
    final innerRadius = outerRadius - 4.5;

    // 1. Concentric circles
    canvas.drawCircle(center, outerRadius, outerPaint);
    canvas.drawCircle(center, innerRadius, innerPaint);

    // 2. Stars / Accent dots at 9 and 3 o'clock
    final dotPaint = Paint()
      ..color = stamp.inkColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - innerRadius + 2.5, center.dy), 1.8, dotPaint);
    canvas.drawCircle(Offset(center.dx + innerRadius - 2.5, center.dy), 1.8, dotPaint);
  }

  void _drawRoundedRectangleStamp(
    Canvas canvas,
    Rect rect,
    Paint outerPaint,
    Paint innerPaint,
  ) {
    final outerRRect = RRect.fromRectAndRadius(
      rect.deflate(3),
      const Radius.circular(12),
    );
    final innerRRect = RRect.fromRectAndRadius(
      rect.deflate(7.5),
      const Radius.circular(8),
    );

    // 1. Concentric rounded rectangles (Schengen / UK border style)
    canvas.drawRRect(outerRRect, outerPaint);
    canvas.drawRRect(innerRRect, innerPaint);

    // 2. Iconic Schengen Entry Arrow `►` at top-left
    final arrowPath = Path()
      ..moveTo(rect.left + 11, rect.top + 10)
      ..lineTo(rect.left + 17, rect.top + 13.5)
      ..lineTo(rect.left + 11, rect.top + 17)
      ..close();

    final fillPaint = Paint()
      ..color = stamp.inkColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, fillPaint);

    // 3. Country code tag at top right
    final codeRect = Rect.fromLTWH(rect.right - 26, rect.top + 9, 16, 9);
    canvas.drawRect(codeRect, innerPaint);
  }

  void _drawOvalStamp(
    Canvas canvas,
    Rect rect,
    Paint outerPaint,
    Paint innerPaint,
  ) {
    final outerOval = rect.deflate(3.5);
    final innerOval = rect.deflate(8.0);

    canvas.drawOval(outerOval, outerPaint);
    canvas.drawOval(innerOval, innerPaint);

    // Lateral accent dots
    final dotPaint = Paint()
      ..color = stamp.inkColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(rect.left + 10, rect.center.dy), 1.8, dotPaint);
    canvas.drawCircle(Offset(rect.right - 10, rect.center.dy), 1.8, dotPaint);
  }

  void _drawHexagonalStamp(
    Canvas canvas,
    Offset center,
    double radius,
    Paint outerPaint,
    Paint innerPaint,
  ) {
    // 6-sided polygon (Japanese Landing Stamp)
    final outerPath = _createPolygonPath(center, radius, 6);
    final innerPath = _createPolygonPath(center, radius - 4.5, 6);

    canvas.drawPath(outerPath, outerPaint);
    canvas.drawPath(innerPath, innerPaint);
  }

  Path _createPolygonPath(Offset center, double radius, int sides) {
    final path = Path();
    final angle = (2 * math.pi) / sides;
    for (int i = 0; i < sides; i++) {
      final a = i * angle - (math.pi / 2);
      final x = center.dx + radius * math.cos(a);
      final y = center.dy + radius * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  void _drawLockedBorder(Canvas canvas, Size size, Offset center) {
    final dashPaint = Paint()
      ..color = isLight
          ? AppColors.borderLight
          : AppColors.borderDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const int dashCount = 28;
    const double dashAngle = (2 * math.pi) / dashCount;
    final outerRadius = (size.width / 2) - 3;

    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: outerRadius),
          i * dashAngle,
          dashAngle * 0.7,
          false,
          dashPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuthenticStampPainter oldDelegate) {
    return oldDelegate.stamp != stamp ||
        oldDelegate.isUnlocked != isUnlocked ||
        oldDelegate.isLight != isLight;
  }
}
