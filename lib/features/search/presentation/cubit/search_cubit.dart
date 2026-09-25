import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/tmdb_client.dart';
import 'explore_feed_cubit.dart';
import 'search_state.dart';

/// Title search for one Explore tab — each tab owns its own instance, so the
/// Shows and Movies queries and results never overwrite each other.
///
/// The browse feed shown while the search field is empty lives in
/// [ExploreFeedCubit]; this cubit sits in [SearchInitial] until a query of
/// [minQueryLength] or more characters is entered.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit({required this.tmdbClient, required this.isTv})
    : super(SearchInitial());

  static const int minQueryLength = 3;

  final TmdbClient tmdbClient;
  final bool isTv;

  Timer? _debounceTimer;
  String? _language;

  /// Tracks the current search request so stale results never overwrite
  /// newer ones.
  int _currentSearchRequestId = 0;

  /// Language applied to search results, matching the Explore language filter.
  void setLanguage(String? language) => _language = language;

  Future<List<dynamic>> _fetch(String query, int page) => isTv
      ? tmdbClient.searchTv(query, page: page)
      : tmdbClient.searchMovie(query, page: page);

  /// Raw pages scanned per request when a language filter empties them.
  static const int _maxPagesPerFetch = 5;

  /// Fetches from [startPage] until a page has results in the active
  /// language. TMDB search takes no language filter, so it is applied here;
  /// without the scan, one page with no Hindi titles would end the results
  /// even with matches further on.
  ///
  /// Returns the matches, the last page read, and whether TMDB ran out.
  Future<(List<dynamic>, int, bool)> _fetchFiltered(
    String query,
    int startPage,
  ) async {
    final language = _language;
    var page = startPage;
    while (true) {
      final raw = await _fetch(query, page);
      if (raw.isEmpty) return (const <dynamic>[], page, true);
      final matches = language == null
          ? raw
          : raw.where((item) => item['original_language'] == language).toList();
      if (matches.isNotEmpty ||
          page - startPage + 1 >= _maxPagesPerFetch ||
          page >= 500) {
        return (matches, page, page >= 500);
      }
      page++;
    }
  }

  void onSearchTextChanged(String query) {
    _debounceTimer?.cancel();

    final trimmedQuery = query.trim();
    if (trimmedQuery.length < minQueryLength) {
      clear();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      executeSearch(trimmedQuery);
    });
  }

  /// Leaves search mode, dropping any request still in flight.
  void clear() {
    _debounceTimer?.cancel();
    _currentSearchRequestId++;
    if (state is! SearchInitial) emit(SearchInitial());
  }

  Future<void> executeSearch(String query) async {
    final int requestId = ++_currentSearchRequestId;
    emit(SearchLoading());
    final startTime = DateTime.now();
    try {
      final (results, lastPage, exhausted) = await _fetchFiltered(query, 1);

      // Check if another search was triggered while we were waiting for the network
      if (_currentSearchRequestId != requestId) return;

      // Enforce a minimum load time of 150ms to let the Skeletonizer shimmer display smoothly
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 150) {
        await Future.delayed(Duration(milliseconds: 150 - elapsed));
        if (_currentSearchRequestId != requestId) return;
      }

      // Left in TMDB's relevance order. The search endpoint paginates by
      // relevance and accepts no sort_by, so re-sorting here would reorder the
      // list every time another page arrives.
      emit(
        SearchResultsSuccess(
          results: results,
          query: query,
          isTv: isTv,
          page: lastPage,
          hasReachedMax: exhausted || results.isEmpty,
        ),
      );
    } catch (e) {
      if (_currentSearchRequestId == requestId) {
        emit(SearchError(Failure.fromException(e)));
      }
    }
  }

  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! SearchResultsSuccess ||
        currentState.isLoadingMore ||
        currentState.hasReachedMax) {
      return;
    }
    final requestId = _currentSearchRequestId;
    final isRetry = currentState.hasLoadMoreError;
    emit(currentState.copyWith(isLoadingMore: true, hasLoadMoreError: false));

    try {
      final (newResults, lastPage, exhausted) = await _fetchFiltered(
        currentState.query,
        currentState.page + 1,
      );
      if (_currentSearchRequestId != requestId) return;

      emit(
        currentState.copyWith(
          results: appendUniqueById(currentState.results, newResults),
          page: lastPage,
          // Five pages with no match in the language: stop rather than
          // keep scanning on every scroll.
          hasReachedMax: exhausted || newResults.isEmpty,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      if (_currentSearchRequestId != requestId) return;
      emit(
        currentState.copyWith(isLoadingMore: false, hasLoadMoreError: !isRetry),
      );
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _currentSearchRequestId++;
    return super.close();
  }
}
