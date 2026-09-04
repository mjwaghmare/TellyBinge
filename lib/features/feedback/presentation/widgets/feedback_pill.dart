import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/feedback_item.dart';

class FeedbackPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final String? leadingEmoji;
  final bool isLight;
  final FontWeight fontWeight;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const FeedbackPill({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.isLight,
    this.leadingEmoji,
    this.fontWeight = FontWeight.w700,
    this.fontSize = 11.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
  });

  factory FeedbackPill.milestone({
    Key? key,
    required FeedbackVoteMilestone milestone,
    required bool isLight,
  }) {
    final textColor = milestone.textColor(isLight);
    return FeedbackPill(
      key: key,
      label: milestone.label,
      leadingEmoji: milestone.emoji,
      backgroundColor: milestone.backgroundColor(isLight),
      textColor: textColor,
      isLight: isLight,
      fontWeight: FontWeight.w700,
      fontSize: 11.5,
      padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.0),
    );
  }

  factory FeedbackPill.category({
    Key? key,
    required FeedbackCategory category,
    required bool isLight,
  }) {
    final textColor = category.textColor(isLight);
    return FeedbackPill(
      key: key,
      label: category.label,
      backgroundColor: category.backgroundColor(isLight),
      textColor: textColor,
      isLight: isLight,
      fontWeight: FontWeight.w700,
      fontSize: 11.5,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
    );
  }

  factory FeedbackPill.status({
    Key? key,
    required FeedbackStatus status,
    required bool isLight,
  }) {
    final textColor = status.textColor(isLight);
    return FeedbackPill(
      key: key,
      label: status.label,
      backgroundColor: status.backgroundColor(isLight),
      textColor: textColor,
      isLight: isLight,
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
    );
  }

  factory FeedbackPill.severity({
    Key? key,
    required String severity,
    required bool isLight,
  }) {
    final textColor = isLight ? AppColors.error : const Color(0xFFFF6B6B);
    final bgColor = isLight
        ? AppColors.error.withValues(alpha: 0.1)
        : AppColors.error.withValues(alpha: 0.2);
    return FeedbackPill(
      key: key,
      label: severity,
      backgroundColor: bgColor,
      textColor: textColor,
      isLight: isLight,
      fontWeight: FontWeight.w600,
      fontSize: 11.0,
      padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: textColor.withValues(alpha: isLight ? 0.25 : 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingEmoji != null) ...[
            Text(
              leadingEmoji!,
              style: const TextStyle(fontSize: 11.0, height: 1.0),
            ),
            const SizedBox(width: 3.5),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
