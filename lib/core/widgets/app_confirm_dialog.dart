import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// App-styled confirmation dialog with a cancel and a confirm action.
///
/// When [onConfirm] is provided, the confirm button shows a spinner while it
/// runs and the dialog can't be dismissed. The dialog closes when [onConfirm]
/// returns `true` and stays open when it returns `false`, so callers can show
/// their own error and let the user retry.
///
/// [show] resolves to `true` only if the user confirmed (and [onConfirm], if
/// any, succeeded).
class AppConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final Future<bool> Function()? onConfirm;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.cancelLabel = 'Cancel',
    this.isDestructive = true,
    this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    bool isDestructive = true,
    Future<bool> Function()? onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: onConfirm == null,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        onConfirm: onConfirm,
      ),
    );
    return confirmed ?? false;
  }

  @override
  State<AppConfirmDialog> createState() => _AppConfirmDialogState();
}

class _AppConfirmDialogState extends State<AppConfirmDialog> {
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

  @override
  Widget build(BuildContext context) {
    final confirmColor =
        widget.isDestructive ? AppColors.error : context.primary;

    return PopScope(
      canPop: !_isPending,
      child: AlertDialog(
        backgroundColor: context.isLight
            ? AppColors.lightSurfaceElevated
            : AppColors.surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          widget.title,
          style: AppTextStyles.mdBold.copyWith(color: context.textPrimary),
        ),
        content: Text(
          widget.message,
          style: AppTextStyles.sm.copyWith(color: context.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: _isPending ? null : () => Navigator.pop(context, false),
            child: Text(
              widget.cancelLabel,
              style: AppTextStyles.smBold.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.textOnPrimary,
              disabledBackgroundColor: confirmColor.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onPressed: _isPending ? null : _handleConfirm,
            child: _isPending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textOnPrimary,
                      ),
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.confirmLabel,
                    style: AppTextStyles.smBold.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
