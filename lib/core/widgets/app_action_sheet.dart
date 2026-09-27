import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A single row in an [AppActionSheet].
class AppActionSheetAction {
  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onTap;
  final bool isDestructive;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? trailing;

  const AppActionSheetAction({
    required this.label,
    this.icon,
    Widget? iconWidget,
    Widget? leading,
    required this.onTap,
    this.isDestructive = false,
    this.subtitle,
    this.iconColor,
    this.iconBackgroundColor,
    this.trailing,
  })  : iconWidget = iconWidget ?? leading,
        assert(
          icon != null || iconWidget != null || leading != null,
          'Either icon or iconWidget must be provided',
        );
}

/// App-styled action sheet with a clean, compact popup design.
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

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) =>
          AppActionSheet(title: title, subtitle: subtitle, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final sheetColor = isLight
        ? AppColors.lightSurface
        : AppColors.surfaceElevated;
    final dividerColor = isLight
        ? AppColors.borderLight
        : Colors.white.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Action card – scrollable so the Cancel button stays visible
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (title != null || subtitle != null) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.md,
                                AppSpacing.md,
                                0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (title != null)
                                    Text(
                                      title!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.smBold.copyWith(
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  if (subtitle != null) ...[
                                    if (title != null)
                                      const SizedBox(height: 2),
                                    Text(
                                      subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.xs.copyWith(
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.sm),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: dividerColor,
                              ),
                            ),
                          ],
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0 || (title == null && subtitle == null))
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: dividerColor,
                                  indent: AppSpacing.md,
                                  endIndent: AppSpacing.md,
                                ),
                            _buildTile(context, actions[i]),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Cancel button
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: sheetColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm + 2,
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.smBold.copyWith(
                            color: context.textPrimary,
                          ),
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
    );
  }

  Widget _buildTile(BuildContext context, AppActionSheetAction action) {
    final isLight = context.isLight;

    final Color fgColor;
    final Color bgColor;

    if (action.isDestructive) {
      fgColor = action.iconColor ?? AppColors.error;
      bgColor = action.iconBackgroundColor ??
          (isLight
              ? AppColors.lightErrorContainer
              : AppColors.error.withValues(alpha: 0.15));
    } else if (action.iconColor != null) {
      fgColor = action.iconColor!;
      bgColor = action.iconBackgroundColor ??
          (isLight
              ? fgColor.withValues(alpha: 0.12)
              : fgColor.withValues(alpha: 0.18));
    } else {
      // Default smart brand container
      fgColor = isLight ? AppColors.lightPrimary : AppColors.primaryLight;
      bgColor = action.iconBackgroundColor ??
          (isLight
              ? AppColors.lightPrimaryContainer
              : AppColors.primary.withValues(alpha: 0.15));
    }

    final Color labelColor = action.isDestructive
        ? AppColors.error
        : context.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          action.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: action.iconWidget ??
                      (action.icon != null
                          ? Icon(action.icon, size: 20, color: fgColor)
                          : const SizedBox.shrink()),
                ),
              ),
              AppSpacing.gapW12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: AppTextStyles.smBold.copyWith(color: labelColor),
                    ),
                    if (action.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle!,
                        style: AppTextStyles.xs.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action.trailing != null) ...[
                AppSpacing.gapW8,
                action.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
