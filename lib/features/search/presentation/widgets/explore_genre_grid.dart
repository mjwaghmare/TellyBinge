import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/explore_genres.dart';
import '../../data/explore_sources.dart';
import '../cubit/explore_feed_cubit.dart';
import 'explore_poster_grid.dart';
import 'watchlisted_ids_builder.dart';

/// Full 3-column grid displaying titles for a selected genre filter.
class ExploreGenreGrid extends StatefulWidget {
  const ExploreGenreGrid({
    super.key,
    required this.type,
    required this.genre,
    this.language,
  });

  final ExploreMediaType type;
  final GenreOption genre;
  final String? language;

  @override
  State<ExploreGenreGrid> createState() => _ExploreGenreGridState();
}

class _ExploreGenreGridState extends State<ExploreGenreGrid> {
  static const int _maxPage = 500;
  static const int _minVisible = 12;
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
  int _generation = 0;

  String get _defaultType => widget.type.tmdbType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void didUpdateWidget(ExploreGenreGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.genre != widget.genre ||
        oldWidget.language != widget.language ||
        oldWidget.type != widget.type) {
      _reload();
    }
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

  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadNextPage();
  }

  Future<List<dynamic>> _fetchPage({
    required TmdbClient client,
    required int page,
    required bool forceRefresh,
  }) async {
    final genreId = widget.genre.genreIdFor(widget.type);
    final effectiveLang = widget.genre.requiredLanguage ?? widget.language;
    final genreIds = genreId != null ? [genreId] : null;

    if (widget.type == ExploreMediaType.movie) {
      return client.discoverMoviesWithFilters(
        page: page,
        sortBy: 'popularity.desc',
        genreIds: genreIds,
        language: effectiveLang,
        forceRefresh: forceRefresh,
        throwOnError: true,
      );
    } else {
      return client.discoverTvShowsWithFilters(
        page: page,
        sortBy: 'popularity.desc',
        genreIds: genreIds,
        language: effectiveLang,
        forceRefresh: forceRefresh,
        throwOnError: true,
      );
    }
  }

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
      results = await _fetchPage(
        client: context.read<TmdbClient>(),
        page: nextPage,
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
        if (_items.isEmpty) {
          _firstPageFailed = true;
        } else if (nextPage > 1) {
          _loadMoreFailed = true;
        }
        return;
      }
      _hasReachedMax = results.isEmpty || nextPage >= _maxPage;
      if (nextPage == 1) {
        if (results.isNotEmpty) _items = results;
      } else {
        _items = appendUniqueById(_items, results);
      }
      _page = nextPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = AppSpacing.bottomTabPadding;

    if (_isLoading) {
      return ExplorePosterGrid.skeleton(
        _defaultType,
        bottomPadding: bottomPadding,
      );
    }

    return RefreshIndicator.adaptive(
      color: AppColors.primary,
      backgroundColor: Theme.of(context).cardColor,
      onRefresh: () => _reload(forceRefresh: true),
      child: WatchlistedIdsBuilder(
        type: widget.type,
        builder: (context, excluded) {
          _grid.update(_items, excluded);
          final visibleItems = _grid.items;

          if (!_isLoading &&
              !_hasReachedMax &&
              !_firstPageFailed &&
              !_loadMoreFailed &&
              visibleItems.length < _minVisible &&
              _autoFills < _maxAutoFills &&
              !_isFetching) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadNextPage(auto: true);
            });
          }

          return ExplorePosterGrid(
            items: visibleItems,
            defaultType: _defaultType,
            controller: _scrollController,
            isLoadingMore: _isLoadingMore,
            hasLoadMoreError: _firstPageFailed || _loadMoreFailed,
            hasReachedMax: _hasReachedMax,
            indexById: _grid.indexById,
            bottomPadding: bottomPadding,
            onRetry: _firstPageFailed ? () => _reload() : _retryLoadMore,
            onLoadMore: () => _loadNextPage(),
            emptyMessage:
                'No ${_defaultType == 'tv' ? 'shows' : 'movies'} found for ${widget.genre.label}.',
          );
        },
      ),
    );
  }
}
