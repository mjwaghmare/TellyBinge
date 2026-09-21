import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Semantic classification for TV show lifecycle states.
enum TvShowStatusType {
  returning,
  ended,
  cancelled,
  upcoming,
  unknown,
}

/// A prominent, token-compliant status badge/chip indicating the TV show lifecycle
/// (e.g. "RETURNING SERIES", "ENDED", "CANCELLED", "IN PRODUCTION").
///
/// Designed to provide industry-standard visual parity with TV Time & Serializd
/// with full dark/light theme awareness and high-contrast hero overlay support.
class TvStatusBadge extends StatelessWidget {
  const TvStatusBadge({
    super.key,
    required this.status,
    this.isHero = true,
  });

  /// The raw status string from TMDB (e.g. "Returning Series", "Ended", "Canceled").
  final String status;

  /// Whether this badge is rendered on a dark media backdrop/hero overlay.
  final bool isHero;

  static TvShowStatusType parseStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'returning series' || s == 'returning') {
      return TvShowStatusType.returning;
    }
    if (s == 'ended') {
      return TvShowStatusType.ended;
    }
    if (s == 'canceled' || s == 'cancelled') {
      return TvShowStatusType.cancelled;
    }
    if (s == 'in production' ||
        s == 'planned' ||
        s == 'post production' ||
        s == 'pilot') {
      return TvShowStatusType.upcoming;
    }
    return TvShowStatusType.unknown;
  }

  static String getLabel(String status, TvShowStatusType type) {
    switch (type) {
      case TvShowStatusType.returning:
        return 'RETURNING SERIES';
      case TvShowStatusType.ended:
        return 'ENDED';
      case TvShowStatusType.cancelled:
        return 'CANCELLED';
      case TvShowStatusType.upcoming:
        final s = status.trim().toLowerCase();
        if (s == 'in production') return 'IN PRODUCTION';
        if (s == 'planned') return 'PLANNED';
        return 'UPCOMING';
      case TvShowStatusType.unknown:
        return status.trim().toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = status.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final statusType = parseStatus(trimmed);
    final label = getLabel(trimmed, statusType);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor;
    final Color borderColor;
    final Color textColor;
    final Color dotColor;

    if (isHero || isDarkTheme) {
      // High-contrast tokens for dark backgrounds / hero backdrop overlays
      switch (statusType) {
        case TvShowStatusType.returning:
          backgroundColor = const Color(0xFF14532D).withValues(alpha: 0.55);
          borderColor = const Color(0xFF22C55E).withValues(alpha: 0.45);
          textColor = const Color(0xFF86EFAC);
          dotColor = const Color(0xFF4ADE80);
          break;
        case TvShowStatusType.ended:
          backgroundColor = Colors.black.withValues(alpha: 0.45);
          borderColor = const Color(0xFF71717A).withValues(alpha: 0.5);
          textColor = const Color(0xFFE4E4E7);
          dotColor = const Color(0xFFA1A1AA);
          break;
        case TvShowStatusType.cancelled:
          backgroundColor = AppColors.error.withValues(alpha: 0.25);
          borderColor = AppColors.error.withValues(alpha: 0.45);
          textColor = const Color(0xFFFCA5A5);
          dotColor = AppColors.error;
          break;
        case TvShowStatusType.upcoming:
          backgroundColor = AppColors.airing.withValues(alpha: 0.25);
          borderColor = AppColors.airing.withValues(alpha: 0.45);
          textColor = const Color(0xFF93C5FD);
          dotColor = AppColors.airing;
          break;
        case TvShowStatusType.unknown:
          backgroundColor = Colors.black.withValues(alpha: 0.45);
          borderColor = const Color(0xFF71717A).withValues(alpha: 0.5);
          textColor = const Color(0xFFE4E4E7);
          dotColor = const Color(0xFFA1A1AA);
          break;
      }
    } else {
      // Light mode tonal container styling for standard content surfaces
      switch (statusType) {
        case TvShowStatusType.returning:
          backgroundColor = AppColors.lightSuccessContainer;
          borderColor =
              AppColors.lightOnSuccessContainer.withValues(alpha: 0.25);
          textColor = AppColors.lightOnSuccessContainer;
          dotColor = AppColors.lightOnSuccessContainer;
          break;
        case TvShowStatusType.ended:
          backgroundColor = AppColors.lightEndedContainer;
          borderColor = AppColors.lightOnEndedContainer.withValues(alpha: 0.25);
          textColor = AppColors.lightOnEndedContainer;
          dotColor = AppColors.lightOnEndedContainer;
          break;
        case TvShowStatusType.cancelled:
          backgroundColor = AppColors.lightErrorContainer;
          borderColor = AppColors.lightOnErrorContainer.withValues(alpha: 0.25);
          textColor = AppColors.lightOnErrorContainer;
          dotColor = AppColors.lightOnErrorContainer;
          break;
        case TvShowStatusType.upcoming:
          backgroundColor = AppColors.lightAiringContainer;
          borderColor = AppColors.lightOnAiringContainer.withValues(alpha: 0.25);
          textColor = AppColors.lightOnAiringContainer;
          dotColor = AppColors.lightOnAiringContainer;
          break;
        case TvShowStatusType.unknown:
          backgroundColor = AppColors.lightEndedContainer;
          borderColor = AppColors.lightOnEndedContainer.withValues(alpha: 0.25);
          textColor = AppColors.lightOnEndedContainer;
          dotColor = AppColors.lightOnEndedContainer;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 3.5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 6.0,
            height: 6.0,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5.0),
          Text(
            label,
            style: AppTextStyles.xsBold.copyWith(
              fontSize: 10.5,
              color: textColor,
              letterSpacing: 0.6,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
