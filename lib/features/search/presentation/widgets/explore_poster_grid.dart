import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../cubit/explore_feed_cubit.dart';
import 'explore_poster_card.dart';

/// Paginated 3-column poster grid, used by search results and See All.
class ExplorePosterGrid extends StatelessWidget {
  const ExplorePosterGrid({
    super.key,
    required this.items,
    required this.defaultType,
    this.physics,
    this.controller,
    this.isLoadingMore = false,
    this.hasLoadMoreError = false,
    this.onRetry,
    this.onLoadMore,
    this.hasReachedMax = false,
    this.indexById,
    this.bottomPadding = AppSpacing.bottomTabPadding,
    this.emptyMessage = 'No results found.\nTry searching for something else.',
  });

  /// Shimmering placeholder grid shown while the first page loads.
  static Widget skeleton(String defaultType, {double? bottomPadding}) {
    return Skeletonizer(
      enabled: true,
      child: ExplorePosterGrid(
        items: List.generate(
          9,
          (index) => {
            if (defaultType == 'tv') 'name': 'Loading Show Title',
            if (defaultType != 'tv') 'title': 'Loading Movie Title',
            'vote_average': 9.9,
            'id': index,
          },
        ),
        defaultType: defaultType,
        physics: const NeverScrollableScrollPhysics(),
        bottomPadding: bottomPadding ?? AppSpacing.bottomTabPadding,
      ),
    );
  }

  final List<dynamic> items;
  final String defaultType;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool isLoadingMore;
  final bool hasLoadMoreError;
  final VoidCallback? onRetry;

  /// When set, a "Load more" button ends the grid, for lists that stopped
  /// fetching on their own before filling the screen.
  final VoidCallback? onLoadMore;
  final bool hasReachedMax;
  final Map<int, int>? indexById;
  final double bottomPadding;

  /// Shown when there are no items and no error.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final tertiary = Theme.of(context).brightness == Brightness.light
        ? AppColors.lightTextTertiary
        : AppColors.textTertiary;

    if (items.isEmpty) {
      if (hasLoadMoreError && onRetry != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Failed to load explore content.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.sm.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.xl),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  child: Text('RETRY', style: AppTextStyles.smBold),
                ),
              ],
            ),
          ),
        );
      }
      return CustomScrollView(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPadding),
                child: AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No Results Found',
                  body: emptyMessage,
                  primaryLabel: onLoadMore != null ? 'Load More' : null,
                  onPrimary: onLoadMore,
                  compact: true,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final bool hasFooter =
        isLoadingMore ||
        (hasLoadMoreError && onRetry != null) ||
        onLoadMore != null ||
        (hasReachedMax && items.isNotEmpty);

    final itemIndexMap = indexById ?? FilteredGrid.indexOf(items);

    return CustomScrollView(
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            hasFooter ? AppSpacing.sm : bottomPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.xs,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 0.52,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return RepaintBoundary(
                  key: ValueKey('${defaultType}_${item['id']}'),
                  child: ExplorePosterCard(
                    item: item,
                    defaultType: defaultType,
                  ),
                );
              },
              childCount: items.length,
              findChildIndexCallback: (Key key) {
                if (key is ValueKey<String>) {
                  final keyStr = key.value;
                  final prefix = '${defaultType}_';
                  if (keyStr.startsWith(prefix)) {
                    final id = int.tryParse(keyStr.substring(prefix.length));
                    if (id != null) return itemIndexMap[id];
                  }
                }
                return null;
              },
            ),
          ),
        ),
        if (isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: bottomPadding,
              ),
              child: const Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        if (hasLoadMoreError && onRetry != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load more data.',
                    style: AppTextStyles.sm.copyWith(color: tertiary),
                  ),
                  AppSpacing.gapH8,
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                    ),
                    child: Text('Retry', style: AppTextStyles.smBold),
                  ),
                ],
              ),
            ),
          ),
        if (onLoadMore != null && !isLoadingMore && !hasLoadMoreError)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: bottomPadding,
              ),
              child: Center(
                child: TextButton(
                  onPressed: onLoadMore,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text('Load more', style: AppTextStyles.smBold),
                ),
              ),
            ),
          ),
        if (hasReachedMax && items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: AppSpacing.md,
                bottom: bottomPadding,
              ),
              child: Center(
                child: Text(
                  defaultType == 'tv'
                      ? 'No more shows to load'
                      : 'No more movies to load',
                  style: AppTextStyles.smMedium.copyWith(color: tertiary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Caches the watchlist-filtered list and its id -> index map for one grid.
///
/// Both are O(n) over a list that grows with every page fetched, and they were
/// being recomputed on every rebuild — including the two emits that each
/// load-more produces while you are mid-fling. Recomputing allocates a fresh
/// List and HashMap each time, so the cost showed up as GC pressure as much as
/// raw CPU. Keyed on source identity, so it recomputes only when a genuinely
/// new list arrives or the exclusions change.
class FilteredGrid {
  List<dynamic>? _sourceItems;
  Set<int>? _excludedIds;

  List<dynamic>? _items;
  Map<int, int>? _indexById;

  List<dynamic> get items => _items!;
  Map<int, int> get indexById => _indexById!;

  /// True when the most recent [update] actually recomputed. Lets the caller
  /// react to a genuinely new list — queueing status lookups, say — without
  /// firing on every rebuild.
  bool didChange = false;

  /// Builds the id -> index map for an arbitrary list (skeleton placeholders and
  /// raw search results, which are short enough not to need caching).
  static Map<int, int> indexOf(List<dynamic> items) {
    final map = <int, int>{};
    for (int i = 0; i < items.length; i++) {
      final id = exploreIdOf(items[i]['id']);
      if (id != null) map[id] = i;
    }
    return map;
  }

  void update(List<dynamic> sourceItems, Set<int> excludedIds) {
    final unchanged =
        _items != null &&
        identical(_sourceItems, sourceItems) &&
        _excludedIds!.length == excludedIds.length &&
        _excludedIds!.containsAll(excludedIds);
    didChange = !unchanged;
    if (unchanged) return;

    final filtered = <dynamic>[];
    final index = <int, int>{};
    for (final item in sourceItems) {
      final id = exploreIdOf(item['id']);
      if (id == null || excludedIds.contains(id)) continue;
      index[id] = filtered.length;
      filtered.add(item);
    }

    _sourceItems = sourceItems;
    _excludedIds = excludedIds;
    _items = filtered;
    _indexById = index;
  }
}
