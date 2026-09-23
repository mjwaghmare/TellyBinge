import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A single row in an [AppActionSheet].
class AppActionSheetAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const AppActionSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// App-styled action sheet with icon rows and optional destructive actions.
///
/// The sheet pops itself before invoking the tapped action's [onTap], so
/// callbacks should use the caller's context rather than the sheet's.
class AppActionSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<AppActionSheetAction> actions;

  const AppActionSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.actions,
  });

  static Future<void> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    required List<AppActionSheetAction> actions,
  }) {
    // Nothing to offer (e.g. details still loading) - don't open an empty sheet
    if (actions.isEmpty) return Future.value();

    final isLight = context.isLight;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          isLight ? AppColors.lightSurfaceElevated : AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (_) =>
          AppActionSheet(title: title, subtitle: subtitle, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: isLight ? AppColors.borderLight : AppColors.borderDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.lg.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  top: 2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle!,
                    style: AppTextStyles.sm.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
            if (title != null || subtitle != null)
              const SizedBox(height: AppSpacing.sm),
            for (final action in actions) _buildTile(context, action),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, AppActionSheetAction action) {
    final color =
        action.isDestructive ? AppColors.error : context.textPrimary;

    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      leading: Icon(action.icon, size: 20, color: color),
      title: Text(
        action.label,
        style: AppTextStyles.smMedium.copyWith(color: color),
      ),
      onTap: () {
        Navigator.pop(context);
        action.onTap();
      },
    );
  }
}
