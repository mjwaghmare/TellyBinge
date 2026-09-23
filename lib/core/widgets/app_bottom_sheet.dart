import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared chrome for every modal bottom sheet in the app: Level 2
/// `surfaceElevated` background, 20pt top corners and a drag handle.
///
/// Sheets with custom content should open through [show] (or reuse
/// [backgroundColor], [shape] and [AppSheetHandle] when they paint their own
/// container) so the outer frame stays consistent everywhere.
class AppBottomSheet {
  AppBottomSheet._();

  static const double radius = 20.0;

  static const BorderRadius borderRadius =
      BorderRadius.vertical(top: Radius.circular(radius));

  static const ShapeBorder shape =
      RoundedRectangleBorder(borderRadius: borderRadius);

  static Color backgroundColor(BuildContext context) => context.isLight
      ? AppColors.lightSurfaceElevated
      : AppColors.surfaceElevated;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useSafeArea = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor(context),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      builder: builder,
    );
  }
}

/// The 56px circular hero icon used at the top of centred sheets
/// (confirmations, sign-in prompts, info sheets).
class AppSheetIcon extends StatelessWidget {
  final IconData icon;
  final bool isDestructive;

  const AppSheetIcon({
    super.key,
    required this.icon,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final color = isDestructive ? AppColors.error : context.primary;
    final background = isDestructive
        ? (isLight
            ? AppColors.lightErrorContainer
            : AppColors.error.withValues(alpha: 0.15))
        : (isLight
            ? AppColors.lightPrimaryContainer
            : AppColors.primary.withValues(alpha: 0.15));

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 28),
    );
  }
}

/// The standard 36×4 drag handle shown at the top of every bottom sheet.
class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.isLight ? AppColors.borderLight : AppColors.borderDark,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
