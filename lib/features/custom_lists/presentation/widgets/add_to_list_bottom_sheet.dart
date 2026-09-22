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
import '../../domain/models/custom_list_item_model.dart';
import '../../domain/models/custom_list_model.dart';
import '../cubit/custom_lists_cubit.dart';
import '../cubit/custom_lists_state.dart';
import 'create_list_bottom_sheet.dart';

class AddToListBottomSheet extends StatefulWidget {
  final CustomListItemModel item;

  const AddToListBottomSheet({
    super.key,
    required this.item,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomListItemModel item,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToListBottomSheet(item: item),
    );
  }

  @override
  State<AddToListBottomSheet> createState() => _AddToListBottomSheetState();
}

class _AddToListBottomSheetState extends State<AddToListBottomSheet> {
  final Set<String> _loadingListIds = {};
  bool _isClosing = false;

  Future<void> _handleToggleItem({
    required String? uid,
    required CustomListModel list,
  }) async {
    if (uid == null) {
      AppSnackbar.showError(
        context,
        'Please log in to save items',
      );
      return;
    }

    if (_loadingListIds.contains(list.id) || _isClosing) return;

    final isAdding = !list.containsItem(widget.item.id, widget.item.mediaType);

    setState(() {
      _loadingListIds.add(list.id);
    });
    unawaited(AppHaptics.lightImpact());

    try {
      final success = await context.read<CustomListsCubit>().toggleItemInList(
            uid: uid,
            listId: list.id,
            item: widget.item,
          );

      if (mounted) {
        if (!success) {
          setState(() {
            _loadingListIds.remove(list.id);
          });
          AppSnackbar.showError(context, 'Failed to update list');
          return;
        }

        setState(() {
          _loadingListIds.remove(list.id);
          _isClosing = true;
        });

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        final message = isAdding
            ? 'Added to "${list.name}"'
            : 'Removed from "${list.name}"';
        if (isAdding) {
          AppSnackbar.showSuccess(context, message);
        } else {
          AppSnackbar.showInfo(context, message);
        }
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingListIds.remove(list.id);
        });
        AppSnackbar.showError(context, 'An unexpected error occurred');
      }
    }
  }

  Future<void> _handleCreateNewList(String? uid) async {
    if (_isClosing) return;
    unawaited(AppHaptics.lightImpact());
    final newListId = await CreateListBottomSheet.show(context);
    if (!mounted || newListId == null) return;

    if (uid == null) {
      AppSnackbar.showError(
        context,
        'Please log in to save items',
      );
      return;
    }

    setState(() {
      _loadingListIds.add(newListId);
    });

    try {
      final success = await context.read<CustomListsCubit>().toggleItemInList(
            uid: uid,
            listId: newListId,
            item: widget.item,
          );
      if (mounted) {
        if (!success) {
          setState(() {
            _loadingListIds.remove(newListId);
          });
          AppSnackbar.showError(
            context,
            'Failed to add item to list',
          );
          return;
        }

        setState(() {
          _loadingListIds.remove(newListId);
          _isClosing = true;
        });

        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        AppSnackbar.showSuccess(context, 'Added to new list');
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingListIds.remove(newListId);
        });
        AppSnackbar.showError(
          context,
          'An unexpected error occurred',
        );
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

    final authState = context.read<AuthCubit>().state;
    final uid = authState is Authenticated ? authState.user.uid : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSpacing.gapH8,
            // Handle
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
            AppSpacing.gapH8,

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to List',
                          style: AppTextStyles.lg.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sm.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _isClosing ? null : () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isLight
                            ? AppColors.lightBackground
                            : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: _isClosing
                            ? context.textTertiary
                            : context.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.gapH4,
            Divider(color: borderColor, height: 1),

            // Create new list action button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightSurface
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _isClosing ? null : () => _handleCreateNewList(uid),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: context.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: primaryColor,
                              size: 20,
                            ),
                          ),
                          AppSpacing.gapW12,
                          Expanded(
                            child: Text(
                              'Create New List',
                              style: AppTextStyles.smBold.copyWith(
                                color: primaryColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: primaryColor.withValues(alpha: 0.6),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Lists list
            Flexible(
              child: BlocBuilder<CustomListsCubit, CustomListsState>(
                builder: (context, state) {
                  if (state is CustomListsLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    );
                  }

                  if (state is CustomListsError) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Center(
                        child: Text(
                          state.message,
                          style: AppTextStyles.sm.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    );
                  }

                  if (state is CustomListsSuccess) {
                    final lists = state.lists;
                    if (lists.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.playlist_add_rounded,
                                size: 36,
                                color: context.textTertiary,
                              ),
                              AppSpacing.gapH8,
                              Text(
                                'No custom lists yet',
                                style: AppTextStyles.smBold.copyWith(
                                  color: context.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH4,
                              Text(
                                'Create a list above to organize your titles.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.xs.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      itemCount: lists.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final list = lists[index];
                        final isAdded = list.containsItem(
                          widget.item.id,
                          widget.item.mediaType,
                        );
                        final isItemLoading =
                            _loadingListIds.contains(list.id);

                        return Material(
                          color: Colors.transparent,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: isAdded
                                  ? (isLight
                                      ? AppColors.lightPrimaryContainer
                                          .withValues(alpha: 0.35)
                                      : primaryColor.withValues(alpha: 0.12))
                                  : (isLight
                                      ? AppColors.lightSurface
                                      : AppColors.surface),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAdded
                                    ? primaryColor.withValues(alpha: 0.45)
                                    : borderColor,
                                width: isAdded ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: (isItemLoading || _isClosing)
                                  ? null
                                  : () => _handleToggleItem(
                                        uid: uid,
                                        list: list,
                                      ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isAdded
                                            ? primaryColor.withValues(alpha: 0.18)
                                            : (isLight
                                                ? AppColors.lightBackground
                                                : AppColors.surfaceElevated),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isAdded
                                            ? Icons.playlist_add_check_rounded
                                            : Icons.playlist_play_rounded,
                                        color: isAdded
                                            ? primaryColor
                                            : context.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                    AppSpacing.gapW12,
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            list.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.mdMedium
                                                .copyWith(
                                              color: context.textPrimary,
                                              fontWeight: isAdded
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${list.itemCount} ${list.itemCount == 1 ? 'item' : 'items'}',
                                            style: AppTextStyles.xs.copyWith(
                                              color: context.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    AppSpacing.gapW8,
                                    if (isItemLoading)
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isAdded
                                              ? primaryColor
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: isAdded
                                                ? primaryColor
                                                : borderColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: isAdded
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 15,
                                                color: AppColors.textOnPrimary,
                                              )
                                            : null,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
