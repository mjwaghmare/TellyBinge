import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_confirm_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../domain/models/custom_list_item_model.dart';
import '../../domain/models/custom_list_model.dart';
import '../cubit/custom_lists_cubit.dart';
import '../cubit/custom_lists_state.dart';
import '../widgets/create_list_bottom_sheet.dart';

enum CustomListSortOption {
  dateAddedDesc,
  dateAddedAsc,
  titleAsc,
  ratingDesc,
}

class CustomListDetailsPage extends StatefulWidget {
  final String listId;

  const CustomListDetailsPage({
    super.key,
    required this.listId,
  });

  @override
  State<CustomListDetailsPage> createState() => _CustomListDetailsPageState();
}

class _CustomListDetailsPageState extends State<CustomListDetailsPage> {
  CustomListSortOption _sortOption = CustomListSortOption.dateAddedDesc;

  String _getImageUrl(String? path, {String size = 'w342'}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  List<CustomListItemModel> _sortItems(List<CustomListItemModel> items) {
    final sorted = List<CustomListItemModel>.from(items);
    switch (_sortOption) {
      case CustomListSortOption.dateAddedDesc:
        sorted.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
      case CustomListSortOption.dateAddedAsc:
        sorted.sort((a, b) => a.addedAt.compareTo(b.addedAt));
        break;
      case CustomListSortOption.titleAsc:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case CustomListSortOption.ratingDesc:
        sorted.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        break;
    }
    return sorted;
  }

  void _showSortSheet(BuildContext context) {
    AppHaptics.lightImpact();
    AppActionSheet.show(
      context,
      title: 'Sort items by',
      actions: [
        _buildSortAction(
          'Date Added (Newest)',
          'Recently added first',
          Icons.schedule_rounded,
          CustomListSortOption.dateAddedDesc,
        ),
        _buildSortAction(
          'Date Added (Oldest)',
          'Earliest added first',
          Icons.history_rounded,
          CustomListSortOption.dateAddedAsc,
        ),
        _buildSortAction(
          'Title (A-Z)',
          'Alphabetical order',
          Icons.sort_by_alpha_rounded,
          CustomListSortOption.titleAsc,
        ),
        _buildSortAction(
          'Rating (Highest)',
          'Top rated first',
          Icons.star_rounded,
          CustomListSortOption.ratingDesc,
        ),
      ],
    );
  }

  AppActionSheetAction _buildSortAction(
    String label,
    String subtitle,
    IconData icon,
    CustomListSortOption option,
  ) {
    final isSelected = _sortOption == option;
    return AppActionSheetAction(
      label: label,
      subtitle: subtitle,
      icon: icon,
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: context.primary, size: 22)
          : const SizedBox.shrink(),
      onTap: () {
        AppHaptics.lightImpact();
        setState(() => _sortOption = option);
      },
    );
  }

  void _showItemOptions(BuildContext context, CustomListItemModel item, String uid) {
    AppHaptics.lightImpact();
    AppActionSheet.show(
      context,
      title: item.title,
      subtitle: item.isMovie ? 'Movie' : 'TV Show',
      actions: [
        AppActionSheetAction(
          label: 'Remove from this list',
          subtitle: 'Remove item from this collection',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onTap: () {
            AppHaptics.mediumImpact();
            context.read<CustomListsCubit>().removeItemFromList(
                  uid: uid,
                  listId: widget.listId,
                  mediaId: item.id,
                  mediaType: item.mediaType,
                );
            AppSnackbar.showInfo(context, 'Removed "${item.title}" from list');
          },
        ),
      ],
    );
  }

  void _showListOptions(BuildContext context, CustomListModel list, String uid) {
    AppHaptics.lightImpact();
    final itemCount = list.items.length;
    AppActionSheet.show(
      context,
      title: list.name,
      subtitle: '$itemCount ${itemCount == 1 ? 'title' : 'titles'}',
      actions: [
        AppActionSheetAction(
          label: 'Edit list',
          subtitle: 'Update list name and description',
          icon: Icons.edit_rounded,
          iconColor: context.primary,
          onTap: () => CreateListBottomSheet.show(
            context,
            listId: list.id,
            initialName: list.name,
            initialDescription: list.description,
          ),
        ),
        AppActionSheetAction(
          label: 'Delete list',
          subtitle: 'Permanently delete this list',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onTap: () => _confirmDeleteList(list, uid),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteList(CustomListModel list, String uid) async {
    unawaited(AppHaptics.heavyImpact());
    final cubit = context.read<CustomListsCubit>();
    final deleted = await AppConfirmSheet.show(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete List?',
      message:
          'Are you sure you want to delete "${list.name}"? This action cannot be undone.',
      onConfirm: () async {
        final success = await cubit.deleteList(uid: uid, listId: list.id);
        if (!success && mounted) {
          AppSnackbar.showError(context, 'Failed to delete list');
        }
        return success;
      },
    );
    if (!deleted || !mounted) return;
    AppSnackbar.showSuccess(context, 'List deleted');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = context.isLight;
    final authState = context.watch<AuthCubit>().state;
    final uid = authState is Authenticated ? authState.user.uid : null;

    return BlocBuilder<CustomListsCubit, CustomListsState>(
      builder: (context, state) {
        CustomListModel? list;
        if (state is CustomListsSuccess) {
          final match = state.lists.where((l) => l.id == widget.listId);
          if (match.isNotEmpty) {
            list = match.first;
          }
        }

        if (state is CustomListsLoading || state is CustomListsInitial) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: context.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.primary,
              ),
            ),
          );
        }

        if (state is CustomListsError) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: context.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  state.message,
                  style: AppTextStyles.md.copyWith(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (list == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: context.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Text(
                'List not found or deleted',
                style: AppTextStyles.md.copyWith(color: context.textSecondary),
              ),
            ),
          );
        }

        final currentList = list;
        final items = _sortItems(currentList.items);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: context.textPrimary,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              currentList.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.lg.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: 'Sort items',
                  icon: Icon(
                    Icons.sort_rounded,
                    color: context.textPrimary,
                    size: 22,
                  ),
                  onPressed: () => _showSortSheet(context),
                ),
              if (uid != null)
                IconButton(
                  tooltip: 'More options',
                  icon: Icon(
                    Icons.more_horiz,
                    color: context.textPrimary,
                    size: 22,
                  ),
                  onPressed: () => _showListOptions(context, currentList, uid),
                ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              // Header description
              if (currentList.description.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      currentList.description,
                      style: AppTextStyles.sm.copyWith(
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),

              // Empty or Grid
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.movie_filter_outlined,
                            size: 64,
                            color: context.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'This list is empty',
                            style: AppTextStyles.mdBold.copyWith(
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Open any movie or show details page and tap "Add to list" to add titles here.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.sm.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.bottomTabPadding,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.xs,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.52,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = items[index];
                        final posterUrl = _getImageUrl(item.posterPath);

                        return GestureDetector(
                          onTap: () {
                            AppHaptics.lightImpact();
                            if (item.isMovie) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MovieDetailsPage(
                                    movieId: item.id,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ShowDetailsPage(
                                    mediaId: item.id,
                                    mediaType: item.mediaType,
                                    title: item.title,
                                  ),
                                ),
                              );
                            }
                          },
                          onLongPress: uid != null
                              ? () => _showItemOptions(context, item, uid)
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Poster card
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      posterUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: posterUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                color: isLight
                                                    ? AppColors.lightSurfaceElevated
                                                    : AppColors.surfaceElevated,
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                color: isLight
                                                    ? AppColors.lightSurfaceElevated
                                                    : AppColors.surfaceElevated,
                                                child: Icon(
                                                  item.isMovie
                                                      ? Icons.movie_outlined
                                                      : Icons.tv_outlined,
                                                  color: context.textTertiary,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: isLight
                                                  ? AppColors.lightSurfaceElevated
                                                  : AppColors.surfaceElevated,
                                              child: Icon(
                                                item.isMovie
                                                    ? Icons.movie_outlined
                                                    : Icons.tv_outlined,
                                                color: context.textTertiary,
                                              ),
                                            ),

                                      // Type tag (top-left)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.isMovie ? 'MOVIE' : 'TV',
                                            style: AppTextStyles.xs.copyWith(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textOnPrimary,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Rating pill (bottom-right)
                                      if (item.voteAverage > 0)
                                        Positioned(
                                          bottom: 4,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.75),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.star_rounded,
                                                  size: 11,
                                                  color: Colors.amber,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  item.voteAverage.toStringAsFixed(1),
                                                  style: AppTextStyles.xs.copyWith(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textOnPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),

                              // Title
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.xsMedium.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              // Year
                              if (item.releaseDate != null &&
                                  item.releaseDate!.length >= 4)
                                Text(
                                  item.releaseDate!.substring(0, 4),
                                  style: AppTextStyles.xs.copyWith(
                                    fontSize: 11,
                                    color: context.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
