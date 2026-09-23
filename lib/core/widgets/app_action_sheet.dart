import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_bottom_sheet.dart';

/// A single row in an [AppActionSheet].
class AppActionSheetAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final Widget? trailing;

  const AppActionSheetAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.subtitle,
    this.iconColor,
    this.iconBackgroundColor,
    this.trailing,
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

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppBottomSheet.backgroundColor(context),
      shape: AppBottomSheet.shape,
      builder: (_) =>
          AppActionSheet(title: title, subtitle: subtitle, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final borderColor = isLight ? AppColors.borderLight : AppColors.borderDark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: AppSheetHandle(),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
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
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    right: AppSpacing.xs,
                    top: 2,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(
                    subtitle!,
                    style: AppTextStyles.sm.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              if (title != null || subtitle != null)
                const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: borderColor,
                  ),
                _buildTile(context, actions[i]),
              ],
            ],
          ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: () {
          Navigator.pop(context);
          action.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
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
                  child: Icon(action.icon, size: 20, color: fgColor),
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
                      style: AppTextStyles.smBold.copyWith(
                        color: action.isDestructive
                            ? AppColors.error
                            : context.textPrimary,
                      ),
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
              AppSpacing.gapW8,
              action.trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
