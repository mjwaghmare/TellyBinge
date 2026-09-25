import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Reusable empty state widget used across the application.
///
/// Displays a tinted circle (with an [icon] or [emoji]), a bold [title],
/// an optional [body] description, and optional primary + secondary actions.
///
/// Use [compact] for inline/tabbed contexts (smaller icon, tighter spacing).
class AppEmptyState extends StatelessWidget {
  /// Icon displayed inside a tinted circle.
  /// Pass `null` to use [emoji] instead.
  final IconData? icon;

  /// Emoji string displayed inside a tinted circle when [icon] is null.
  /// Ignored when [icon] is provided.
  final String? emoji;

  /// Bold headline explaining what happened.
  final String title;

  /// Supporting body text with context or guidance.
  final String? body;

  /// Primary call-to-action button label.
  final String? primaryLabel;

  /// Callback for the primary CTA.
  final VoidCallback? onPrimary;

  /// Optional secondary text-button label.
  final String? secondaryLabel;

  /// Callback for the secondary action.
  final VoidCallback? onSecondary;

  /// Whether to use a compact layout (smaller icon, tighter spacing)
  /// suitable for inline/tabbed contexts like profile grids.
  final bool compact;

  const AppEmptyState({
    super.key,
    this.icon,
    this.emoji,
    required this.title,
    this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.compact = false,
  }) : assert(
         icon != null || emoji != null,
         'Either icon or emoji must be provided',
       );

  /// Factory for when filters/searches matched nothing.
  factory AppEmptyState.noResults({
    Key? key,
    IconData icon = Icons.filter_alt_off_rounded,
    String title = 'No Results Matched',
    String? body = 'Try adjusting your filters or search terms.',
    String primaryLabel = 'CLEAR FILTERS',
    VoidCallback? onClearFilters,
    bool compact = false,
  }) {
    return AppEmptyState(
      key: key,
      icon: icon,
      title: title,
      body: body,
      primaryLabel: onClearFilters != null ? primaryLabel : null,
      onPrimary: onClearFilters,
      compact: compact,
    );
  }

  /// Factory for when there is genuinely no data yet.
  factory AppEmptyState.noData({
    Key? key,
    required IconData icon,
    required String title,
    String? body,
    String? primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool compact = false,
  }) {
    return AppEmptyState(
      key: key,
      icon: icon,
      title: title,
      body: body,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.primary;
    final containerColor = context.primaryContainer;

    final double circleSize = compact ? 56 : 72;
    final double iconSize = compact ? 26 : 34;
    final double emojiSize = compact ? 28 : 36;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: compact ? AppSpacing.md : AppSpacing.xxl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon / Emoji circle
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              color: containerColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: primaryColor, size: iconSize)
                  : Text(
                      emoji!,
                      style: TextStyle(fontSize: emojiSize),
                    ),
            ),
          ),

          compact ? AppSpacing.gapH12 : AppSpacing.gapH16,

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: (compact ? AppTextStyles.mdBold : AppTextStyles.lg)
                .copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
          ),

          // Body
          if (body != null) ...[
            compact ? AppSpacing.gapH4 : AppSpacing.gapH8,
            Text(
              body!,
              textAlign: TextAlign.center,
              style: AppTextStyles.sm.copyWith(
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ],

          // Primary CTA
          if (primaryLabel != null && onPrimary != null) ...[
            compact ? AppSpacing.gapH16 : AppSpacing.gapH24,
            ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: AppColors.textOnPrimary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(primaryLabel!, style: AppTextStyles.smBold),
            ),
          ],

          // Secondary action
          if (secondaryLabel != null && onSecondary != null) ...[
            AppSpacing.gapH8,
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
              ),
              child: Text(secondaryLabel!, style: AppTextStyles.smMedium),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Center(child: content);
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Center(child: content),
            ),
          ),
        );
      },
    );
  }
}
