import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_bottom_sheet.dart';

/// App-styled confirmation bottom sheet: icon, title, message, and a
/// cancel + confirm button pair.
///
/// When [onConfirm] is provided, the confirm button shows a spinner while it
/// runs and the sheet can't be dismissed. The sheet closes when [onConfirm]
/// returns `true` and stays open when it returns `false` (or throws), so
/// callers can show their own error and let the user retry.
///
/// [onCancel] runs only when the cancel button is tapped, not when the sheet
/// is dismissed by dragging or tapping outside. Use it when "cancel" is a
/// real choice (e.g. "No, just this one").
///
/// [show] resolves to `true` only if the user confirmed (and [onConfirm], if
/// any, succeeded).
class AppConfirmSheet extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final Future<bool> Function()? onConfirm;
  final VoidCallback? onCancel;

  const AppConfirmSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.cancelLabel = 'Cancel',
    this.isDestructive = true,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool isDestructive = true,
    Future<bool> Function()? onConfirm,
    VoidCallback? onCancel,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: onConfirm == null,
      enableDrag: onConfirm == null,
      backgroundColor: AppBottomSheet.backgroundColor(context),
      shape: AppBottomSheet.shape,
      builder: (_) => AppConfirmSheet(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
    return confirmed ?? false;
  }

  @override
  State<AppConfirmSheet> createState() => _AppConfirmSheetState();
}

class _AppConfirmSheetState extends State<AppConfirmSheet> {
  bool _isPending = false;

  Future<void> _handleConfirm() async {
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isPending = true);
    bool success;
    try {
      success = await onConfirm();
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isPending = false);
    }
  }

  void _handleCancel() {
    Navigator.pop(context, false);
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final borderColor = isLight ? AppColors.borderLight : AppColors.borderDark;
    final accentColor =
        widget.isDestructive ? AppColors.error : context.primary;

    return PopScope(
      canPop: !_isPending,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag handle
              const AppSheetHandle(),
              AppSpacing.gapH24,
              AppSheetIcon(
                icon: widget.icon,
                isDestructive: widget.isDestructive,
              ),
              AppSpacing.gapH16,
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.lg.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              AppSpacing.gapH8,
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: AppTextStyles.sm.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              AppSpacing.gapH24,
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isPending ? null : _handleCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: isLight
                            ? AppColors.lightBackground
                            : AppColors.surface,
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        widget.cancelLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.smBold.copyWith(
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isPending ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: accentColor,
                        foregroundColor: AppColors.textOnPrimary,
                        disabledBackgroundColor:
                            accentColor.withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: _isPending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.textOnPrimary,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.confirmLabel,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.smBold.copyWith(
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
