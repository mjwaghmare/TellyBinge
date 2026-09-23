import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/custom_lists_cubit.dart';

class CreateListBottomSheet extends StatefulWidget {
  final String? listId;
  final String? initialName;
  final String? initialDescription;

  const CreateListBottomSheet({
    super.key,
    this.listId,
    this.initialName,
    this.initialDescription,
  });

  static Future<String?> show(
    BuildContext context, {
    String? listId,
    String? initialName,
    String? initialDescription,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateListBottomSheet(
        listId: listId,
        initialName: initialName,
        initialDescription: initialDescription,
      ),
    );
  }

  @override
  State<CreateListBottomSheet> createState() => _CreateListBottomSheetState();
}

class _CreateListBottomSheetState extends State<CreateListBottomSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isLoading = false;

  bool get isEditing => widget.listId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.showInfo(context, 'Please enter a list name');
      return;
    }

    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      AppSnackbar.showError(context, 'You must be logged in');
      return;
    }

    setState(() => _isLoading = true);
    unawaited(AppHaptics.mediumImpact());

    final customListsCubit = context.read<CustomListsCubit>();
    if (isEditing) {
      final success = await customListsCubit.updateList(
        uid: authState.user.uid,
        listId: widget.listId!,
        name: name,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        AppSnackbar.showSuccess(context, 'List updated');
        Navigator.of(context).pop(widget.listId);
      } else {
        AppSnackbar.showError(context, 'Failed to update list');
      }
    } else {
      final newListId = await customListsCubit.createList(
        uid: authState.user.uid,
        name: name,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (newListId != null) {
        AppSnackbar.showSuccess(context, 'List created');
        Navigator.of(context).pop(newListId);
      } else {
        AppSnackbar.showError(context, 'Failed to create list');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final surfaceColor =
        isLight ? AppColors.lightSurfaceElevated : AppColors.surfaceElevated;
    final borderColor = isLight ? AppColors.borderLight : AppColors.borderDark;
    final primaryColor = context.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
            left: BorderSide(color: borderColor, width: 1),
            right: BorderSide(color: borderColor, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isLight
                          ? AppColors.borderLight
                          : AppColors.borderDark,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit List' : 'Create New List',
                      style: AppTextStyles.lg.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: context.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Name input
                Text(
                  'List Name',
                  style: AppTextStyles.smMedium.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.md.copyWith(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Comfort Movies, Weekend Marathon',
                    hintStyle: AppTextStyles.sm.copyWith(
                      color: context.textTertiary,
                    ),
                    filled: true,
                    fillColor: isLight
                        ? AppColors.lightBackground
                        : AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Description input
                Text(
                  'Description (Optional)',
                  style: AppTextStyles.smMedium.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                TextField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  style: AppTextStyles.md.copyWith(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'What is this list about?',
                    hintStyle: AppTextStyles.sm.copyWith(
                      color: context.textTertiary,
                    ),
                    filled: true,
                    fillColor: isLight
                        ? AppColors.lightBackground
                        : AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Submit Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textOnPrimary,
                              ),
                            ),
                          )
                        : Text(
                            isEditing ? 'Save Changes' : 'Create List',
                            style: AppTextStyles.smBold.copyWith(
                              color: AppColors.textOnPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
