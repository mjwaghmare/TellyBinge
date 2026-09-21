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
import '../cubit/custom_lists_cubit.dart';
import '../cubit/custom_lists_state.dart';
import 'create_list_bottom_sheet.dart';

class AddToListBottomSheet extends StatelessWidget {
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
        maxHeight: MediaQuery.of(context).size.height * 0.75,
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
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.sm),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sm.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: context.textSecondary,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Divider(color: borderColor, height: 1),

            // Create new list action button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  unawaited(AppHaptics.lightImpact());
                  final newListId = await CreateListBottomSheet.show(context);
                  if (newListId != null && uid != null && context.mounted) {
                    // Automatically add the current item to the newly created list
                    unawaited(
                      context.read<CustomListsCubit>().toggleItemInList(
                            uid: uid,
                            listId: newListId,
                            item: item,
                          ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.lightBackground
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
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
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Create New List',
                        style: AppTextStyles.smBold.copyWith(
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Lists list
            Expanded(
              child: BlocBuilder<CustomListsCubit, CustomListsState>(
                builder: (context, state) {
                  if (state is CustomListsLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state is CustomListsError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: AppTextStyles.sm.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    );
                  }

                  if (state is CustomListsSuccess) {
                    final lists = state.lists;
                    if (lists.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.playlist_add,
                                size: 48,
                                color: context.textTertiary,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'No custom lists yet',
                                style: AppTextStyles.mdBold.copyWith(
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Create a list above to organize your titles.',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.sm.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: lists.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final list = lists[index];
                        final isAdded = list.containsItem(item.id, item.mediaType);

                        return Material(
                          color: isLight
                              ? AppColors.lightSurface
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (uid == null) {
                                AppSnackbar.showError(
                                  context,
                                  'Please log in to save items',
                                );
                                return;
                              }
                              unawaited(AppHaptics.lightImpact());
                              unawaited(
                                context
                                    .read<CustomListsCubit>()
                                    .toggleItemInList(
                                      uid: uid,
                                      listId: list.id,
                                      item: item,
                                    ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          list.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.mdMedium.copyWith(
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
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
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
                                            : (isLight
                                                ? AppColors.borderLight
                                                : AppColors.borderDark),
                                        width: 2,
                                      ),
                                    ),
                                    child: isAdded
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: AppColors.textOnPrimary,
                                          )
                                        : null,
                                  ),
                                ],
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
