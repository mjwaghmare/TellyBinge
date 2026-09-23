import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/explore_sources.dart';
import '../cubit/explore_feed_cubit.dart';
import '../widgets/explore_poster_grid.dart';
import '../widgets/watchlisted_ids_builder.dart';

/// Full 3-column grid behind an Explore row's See All, paging through the
/// same source as the row with the same language and exclusions.
class ExploreSeeAllPage extends StatefulWidget {
  const ExploreSeeAllPage({
    super.key,
    required this.type,
    required this.section,
    this.language,
    this.excludedIds = const {},
  });

  final ExploreMediaType type;
  final ExploreSection section;
  final String? language;

  /// Ids hidden on top of the watchlist, e.g. Trending Now leaves out the
  /// titles already shown in Top 5.
  final Set<int> excludedIds;

  @override
  State<ExploreSeeAllPage> createState() => _ExploreSeeAllPageState();
}

class _ExploreSeeAllPageState extends State<ExploreSeeAllPage> {
  /// TMDB caps list pagination at page 500.
  static const int _maxPage = 500;

  /// Keep fetching until at least this many survive watchlist filtering, so
  /// the grid fills the screen and can scroll to trigger the next page.
  static const int _minVisible = 12;

  /// Pages fetched automatically in a row to reach [_minVisible]. A large
  /// watchlist can filter out whole pages; past this the grid offers a
  /// "Load more" button instead of chaining requests.
  static const int _maxAutoFills = 5;

  final ScrollController _scrollController = ScrollController();
  final FilteredGrid _grid = FilteredGrid();

  List<dynamic> _items = const [];
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasReachedMax = false;
  bool _firstPageFailed = false;
  bool _loadMoreFailed = false;
  bool _isFetching = false;
  int _autoFills = 0;

  /// Bumped by [_reload] so a page still in flight from before is discarded.
  int _generation = 0;

  String get _defaultType => widget.type.tmdbType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadMoreFailed) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  /// Starts over from page 1. Pull-to-refresh bypasses the cache and keeps
  /// the current grid on screen until page 1 comes back; the Retry button
  /// shows the skeleton instead (a failed page was never cached anyway).
  Future<void> _reload({bool forceRefresh = false}) {
    _generation++;
    _isFetching = false;
    setState(() {
      if (!forceRefresh) _items = const [];
      _page = 0;
      _isLoading = !forceRefresh;
      _isLoadingMore = false;
      _hasReachedMax = false;
      _firstPageFailed = false;
      _loadMoreFailed = false;
      _autoFills = 0;
    });
    return _loadNextPage(forceRefresh: forceRefresh);
  }

  /// Retries the page that failed, from the footer's Retry.
  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadNextPage();
  }

  /// [auto] marks a top-up triggered by too few visible titles rather than by
  /// the user scrolling or tapping, which counts against [_maxAutoFills].
  Future<void> _loadNextPage({
    bool forceRefresh = false,
    bool auto = false,
  }) async {
    if (_isFetching || _hasReachedMax || _firstPageFailed) return;
    _isFetching = true;
    _autoFills = auto ? _autoFills + 1 : 0;
    final generation = _generation;
    if (_page > 0) setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    List<dynamic>? results;
    try {
      results = await fetchExploreSectionPage(
        context.read<TmdbClient>(),
        type: widget.type,
        section: widget.section,
        page: nextPage,
        language: widget.language,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      results = null;
    }
    if (!mounted || generation != _generation) return;
    _isFetching = false;

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
      if (results == null) {
        // A failed refresh keeps the grid it already had.
        if (_items.isEmpty) {
          _firstPageFailed = true;
        } else if (nextPage > 1) {
          _loadMoreFailed = true;
        }
        return;
      }
      // Sources throw on failure, so an empty page is the real end.
      _hasReachedMax = results.isEmpty || nextPage >= _maxPage;
      if (nextPage == 1) {
        // A refresh replaces the list rather than appending to it.
        if (results.isNotEmpty) _items = results;
      } else {
        _items = appendUniqueById(_items, results);
      }
      _page = nextPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = AppSpacing.xl + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: Text(widget.section.title)),
      body: _isLoading
          ? ExplorePosterGrid.skeleton(
              _defaultType,
              bottomPadding: bottomPadding,
            )
          : RefreshIndicator.adaptive(
              color: AppColors.primary,
              backgroundColor: Theme.of(context).cardColor,
              onRefresh: () => _reload(forceRefresh: true),
              child: WatchlistedIdsBuilder(
                type: widget.type,
                builder: (context, watchlisted) {
                  _grid.update(_items, {...watchlisted, ...widget.excludedIds});
                  final needsMore =
                      _grid.items.length < _minVisible &&
                      !_hasReachedMax &&
                      !_firstPageFailed &&
                      !_loadMoreFailed;
                  final canAutoFill = _autoFills < _maxAutoFills;
                  if (needsMore && canAutoFill && !_isFetching) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _loadNextPage(auto: true);
                    });
                  }
                  return ExplorePosterGrid(
                    items: _grid.items,
                    defaultType: _defaultType,
                    controller: _scrollController,
                    isLoadingMore: _isLoadingMore,
                    hasLoadMoreError: _firstPageFailed || _loadMoreFailed,
                    onRetry: _firstPageFailed ? _reload : _retryLoadMore,
                    onLoadMore: needsMore && !canAutoFill && !_isFetching
                        ? _loadNextPage
                        : null,
                    hasReachedMax: _hasReachedMax,
                    indexById: _grid.indexById,
                    bottomPadding: bottomPadding,
                    emptyMessage:
                        'Everything here so far is already on your watchlist.',
                  );
                },
              ),
            ),
    );
  }
}
