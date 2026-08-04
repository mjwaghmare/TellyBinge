import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final TmdbClient tmdbClient;
  Timer? _debounceTimer;

  // ADD: Cache lists for trending content
  List<dynamic>? _cachedTrendingTv;
  List<dynamic>? _cachedTrendingMovies;

  /// Server-side release-date sorts. TMDB orders and paginates by these, so
  /// successive pages continue the same global ordering and can simply be
  /// appended.
  static const String tvLatestSort = 'first_air_date.desc';
  static const String movieLatestSort = 'primary_release_date.desc';

  String _tvSortBy = tvLatestSort;
  String? _tvLanguage;
  String? _tvYear;

  // Filter state for Movies
  String _movieSortBy = movieLatestSort;
  String? _movieLanguage;
  String? _movieYear;

  SearchCubit({required this.tmdbClient}) : super(SearchInitial());

  static int? _idOf(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  /// Appends a freshly fetched page, dropping ids already present.
  ///
  /// Ordering is whatever the API returned and is never recomputed here. A
  /// client-side sort is only stable if it uses the same key the server
  /// paginates by; re-sorting a paginated feed inserts later pages *above* the
  /// user's scroll position, which reads as the list jumping and every visible
  /// tile reloading its poster. Sorting is requested from TMDB instead, via
  /// `sort_by`, so appending preserves a correct global order.
  List<dynamic> _appendUnique(List<dynamic> existing, List<dynamic> newItems) {
    if (newItems.isEmpty) return existing;

    final seen = <int>{};
    for (final item in existing) {
      final id = _idOf(item['id']);
      if (id != null) seen.add(id);
    }

    final fresh = <dynamic>[];
    for (final item in newItems) {
      final id = _idOf(item['id']);
      if (id == null || !seen.add(id)) continue;
      fresh.add(item);
    }

    if (fresh.isEmpty) return existing;
    return [...existing, ...fresh];
  }

  /// Resolves which endpoint backs the TV feed for the active filters.
  ///
  /// Page 1 and every subsequent page go through here so they always come from
  /// the same source in the same order — fetching page 1 from `/trending` and
  /// page 2 from `/discover` would reshuffle the list mid-scroll.
  Future<List<dynamic>> _fetchTvPage(int page) {
    final bool noFilters = _tvLanguage == null && _tvYear == null;

    if (noFilters) {
      if (_tvSortBy == 'trending') {
        return tmdbClient.getTrendingTvShows(page: page);
      }
      if (_tvSortBy == 'airing_today') {
        return tmdbClient.getAiringTodayTvShows(page: page);
      }
      if (_tvSortBy == 'upcoming') {
        return tmdbClient.getUpcomingTvShows(page: page);
      }
    }

    final effectiveSortBy = switch (_tvSortBy) {
      'trending' || 'popularity.desc' => 'popularity.desc',
      'airing_today' || 'upcoming' => tvLatestSort,
      _ => _tvSortBy,
    };
    return tmdbClient.discoverTvShowsWithFilters(
      page: page,
      sortBy: effectiveSortBy,
      language: _tvLanguage,
      year: _tvYear,
    );
  }

  /// Movie counterpart of [_fetchTvPage].
  Future<List<dynamic>> _fetchMoviePage(int page) {
    final bool noFilters = _movieLanguage == null && _movieYear == null;

    if (noFilters) {
      if (_movieSortBy == 'trending') {
        return tmdbClient.getTrendingMovies(page: page);
      }
      if (_movieSortBy == 'now_playing') {
        return tmdbClient.getNowPlayingMovies(page: page);
      }
      if (_movieSortBy == 'upcoming') {
        return tmdbClient.getUpcomingMovies(page: page);
      }
    }

    final effectiveSortBy = switch (_movieSortBy) {
      'trending' || 'popularity.desc' => 'popularity.desc',
      'now_playing' || 'upcoming' => movieLatestSort,
      _ => _movieSortBy,
    };
    return tmdbClient.discoverMoviesWithFilters(
      page: page,
      sortBy: effectiveSortBy,
      language: _movieLanguage,
      year: _movieYear,
    );
  }

  // MODIFY: loadTrending with caching to avoid redundant api queries
  Future<void> loadTrending() async {
    if (state is SearchTrendingSuccess) {
      return;
    }
    if (_cachedTrendingTv != null && _cachedTrendingMovies != null) {
      emit(
        SearchTrendingSuccess(
          trendingTv: _cachedTrendingTv!,
          trendingMovies: _cachedTrendingMovies!,
          tvPage: 1,
          moviesPage: 1,
          tvHasReachedMax: _cachedTrendingTv!.isEmpty,
          moviesHasReachedMax: _cachedTrendingMovies!.isEmpty,
        ),
      );
      return;
    }
    emit(SearchLoading());
    try {
      final tvShows = await _fetchTvPage(1);
      // Stagger by 100ms to prevent simultaneous socket handshakes on startup
      await Future.delayed(const Duration(milliseconds: 100));
      final movies = await _fetchMoviePage(1);

      _cachedTrendingTv = tvShows;
      _cachedTrendingMovies = movies;
      emit(
        SearchTrendingSuccess(
          trendingTv: tvShows,
          trendingMovies: movies,
          tvPage: 1,
          moviesPage: 1,
          tvHasReachedMax: tvShows.isEmpty,
          moviesHasReachedMax: movies.isEmpty,
        ),
      );
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }

  void resetTvTrending() {
    if (state is SearchTrendingSuccess && _cachedTrendingTv != null) {
      final currentState = state as SearchTrendingSuccess;
      emit(
        currentState.copyWith(
          trendingTv: _cachedTrendingTv,
          tvPage: 1,
          tvHasReachedMax: _cachedTrendingTv!.isEmpty,
        ),
      );
    } else if (state is! SearchTrendingSuccess) {
      loadTrending();
    }
  }

  void resetMoviesTrending() {
    if (state is SearchTrendingSuccess && _cachedTrendingMovies != null) {
      final currentState = state as SearchTrendingSuccess;
      emit(
        currentState.copyWith(
          trendingMovies: _cachedTrendingMovies,
          moviesPage: 1,
          moviesHasReachedMax: _cachedTrendingMovies!.isEmpty,
        ),
      );
    } else if (state is! SearchTrendingSuccess) {
      loadTrending();
    }
  }

  Future<void> loadMore(bool isTvTab) async {
    final currentState = state;

    if (currentState is SearchTrendingSuccess) {
      final hasReachedMax = isTvTab
          ? currentState.tvHasReachedMax
          : currentState.moviesHasReachedMax;
      if (currentState.isLoadingMore || hasReachedMax) return;

      final isRetry = isTvTab
          ? currentState.tvLoadMoreError
          : currentState.moviesLoadMoreError;

      emit(
        currentState.copyWith(
          isLoadingMore: true,
          tvLoadMoreError: isTvTab ? false : null,
          moviesLoadMoreError: !isTvTab ? false : null,
        ),
      );

      try {
        final nextPage =
            (isTvTab ? currentState.tvPage : currentState.moviesPage) + 1;

        final List<dynamic> newResults = isTvTab
            ? await _fetchTvPage(nextPage)
            : await _fetchMoviePage(nextPage);

        if (newResults.isEmpty) {
          if (nextPage >= 500) {
            emit(
              currentState.copyWith(
                tvHasReachedMax: isTvTab ? true : currentState.tvHasReachedMax,
                moviesHasReachedMax: !isTvTab
                    ? true
                    : currentState.moviesHasReachedMax,
                isLoadingMore: false,
              ),
            );
          } else {
            // Page had zero results (e.g. filtered out), but TMDB has more pages: advance page count
            emit(
              currentState.copyWith(
                tvPage: isTvTab ? nextPage : currentState.tvPage,
                moviesPage: !isTvTab ? nextPage : currentState.moviesPage,
                isLoadingMore: false,
              ),
            );
          }
        } else {
          final updatedTv = isTvTab
              ? _appendUnique(currentState.trendingTv, newResults)
              : currentState.trendingTv;
          final updatedMovies = !isTvTab
              ? _appendUnique(currentState.trendingMovies, newResults)
              : currentState.trendingMovies;

          emit(
            currentState.copyWith(
              trendingTv: updatedTv,
              trendingMovies: updatedMovies,
              tvPage: isTvTab ? nextPage : currentState.tvPage,
              moviesPage: !isTvTab ? nextPage : currentState.moviesPage,
              isLoadingMore: false,
            ),
          );
        }
      } catch (_) {
        emit(
          currentState.copyWith(
            isLoadingMore: false,
            tvLoadMoreError: isTvTab ? !isRetry : null,
            moviesLoadMoreError: !isTvTab ? !isRetry : null,
          ),
        );
      }
    } else if (currentState is SearchResultsSuccess) {
      if (currentState.isLoadingMore ||
          currentState.hasReachedMax ||
          currentState.isTv != isTvTab) {
        return;
      }
      final isRetry = currentState.hasLoadMoreError;
      emit(currentState.copyWith(isLoadingMore: true, hasLoadMoreError: false));

      try {
        final nextPage = currentState.page + 1;
        final newResults = currentState.isTv
            ? await tmdbClient.searchTv(currentState.query, page: nextPage)
            : await tmdbClient.searchMovie(currentState.query, page: nextPage);

        var filteredNewResults = newResults;
        if (currentState.isTv && _tvLanguage != null) {
          filteredNewResults = newResults
              .where((item) => item['original_language'] == _tvLanguage)
              .toList();
        } else if (!currentState.isTv && _movieLanguage != null) {
          filteredNewResults = newResults
              .where((item) => item['original_language'] == _movieLanguage)
              .toList();
        }

        if (filteredNewResults.isEmpty) {
          emit(
            currentState.copyWith(hasReachedMax: true, isLoadingMore: false),
          );
        } else {
          final updatedResults = _appendUnique(
            currentState.results,
            filteredNewResults,
          );

          emit(
            currentState.copyWith(
              results: updatedResults,
              page: nextPage,
              isLoadingMore: false,
            ),
          );
        }
      } catch (_) {
        emit(
          currentState.copyWith(
            isLoadingMore: false,
            hasLoadMoreError: !isRetry,
          ),
        );
      }
    }
  }

  // Track the current search request to prevent stale results from overwriting newer ones (Race Condition Fix)
  int _currentSearchRequestId = 0;

  // MODIFY: Add 3-character checks and debounce timer
  void onSearchTextChanged(String query, {required bool isTv}) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      loadTrending();
      return;
    }

    if (trimmedQuery.length < 3) {
      loadTrending();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      executeSearch(trimmedQuery, isTv: isTv);
    });
  }

  Future<void> executeSearch(String query, {required bool isTv}) async {
    final int requestId = ++_currentSearchRequestId;
    emit(SearchLoading());
    final startTime = DateTime.now();
    try {
      final results = isTv
          ? await tmdbClient.searchTv(query)
          : await tmdbClient.searchMovie(query);

      // Check if another search was triggered while we were waiting for the network
      if (_currentSearchRequestId != requestId) {
        return; // Discard stale result
      }

      // Enforce a minimum load time of 150ms to let the Skeletonizer shimmer display smoothly
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      if (elapsed < 150) {
        await Future.delayed(Duration(milliseconds: 150 - elapsed));
      }

      var filteredResults = results;
      if (isTv && _tvLanguage != null) {
        filteredResults = results
            .where((item) => item['original_language'] == _tvLanguage)
            .toList();
      } else if (!isTv && _movieLanguage != null) {
        filteredResults = results
            .where((item) => item['original_language'] == _movieLanguage)
            .toList();
      }

      // Left in TMDB's relevance order. The search endpoint paginates by
      // relevance and accepts no sort_by, so re-sorting here would reorder the
      // list every time another page arrives.
      emit(
        SearchResultsSuccess(
          results: filteredResults,
          query: query,
          isTv: isTv,
          page: 1,
          hasReachedMax: filteredResults.isEmpty,
        ),
      );
    } catch (e) {
      if (_currentSearchRequestId == requestId) {
        emit(SearchError(e.toString()));
      }
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }

  void updateTrendingTv(List<dynamic> filteredShows) {
    final currentState = state;
    // Already in the order TMDB returned it for the active sort.
    final sortedShows = filteredShows;
    if (currentState is SearchTrendingSuccess) {
      emit(
        currentState.copyWith(
          trendingTv: sortedShows,
          tvPage: 1,
          tvHasReachedMax: sortedShows.isEmpty,
        ),
      );
    } else {
      emit(
        SearchTrendingSuccess(
          trendingTv: sortedShows,
          trendingMovies: _cachedTrendingMovies ?? [],
          tvPage: 1,
          moviesPage: 1,
          tvHasReachedMax: sortedShows.isEmpty,
          moviesHasReachedMax: (_cachedTrendingMovies ?? []).isEmpty,
        ),
      );
    }
  }

  void updateTrendingMovies(List<dynamic> filteredMovies) {
    final currentState = state;
    // Already in the order TMDB returned it for the active sort.
    final sortedMovies = filteredMovies;
    if (currentState is SearchTrendingSuccess) {
      emit(
        currentState.copyWith(
          trendingMovies: sortedMovies,
          moviesPage: 1,
          moviesHasReachedMax: sortedMovies.isEmpty,
        ),
      );
    } else {
      emit(
        SearchTrendingSuccess(
          trendingTv: _cachedTrendingTv ?? [],
          trendingMovies: sortedMovies,
          tvPage: 1,
          moviesPage: 1,
          tvHasReachedMax: (_cachedTrendingTv ?? []).isEmpty,
          moviesHasReachedMax: sortedMovies.isEmpty,
        ),
      );
    }
  }

  void clearTrendingTvResults() {
    final currentState = state;
    if (currentState is SearchTrendingSuccess) {
      emit(
        currentState.copyWith(
          trendingTv: [],
          tvPage: 1,
          tvHasReachedMax: false,
        ),
      );
    }
  }

  void clearTrendingMovieResults() {
    final currentState = state;
    if (currentState is SearchTrendingSuccess) {
      emit(
        currentState.copyWith(
          trendingMovies: [],
          moviesPage: 1,
          moviesHasReachedMax: false,
        ),
      );
    }
  }

  void setTvFilters({
    String sortBy = tvLatestSort,
    String? language,
    String? year,
  }) {
    _tvSortBy = sortBy;
    _tvLanguage = language;
    _tvYear = year;
  }

  void setMovieFilters({
    String sortBy = movieLatestSort,
    String? language,
    String? year,
  }) {
    _movieSortBy = sortBy;
    _movieLanguage = language;
    _movieYear = year;
  }

  void clearTvFilters() {
    _tvSortBy = tvLatestSort;
    _tvLanguage = null;
    _tvYear = null;
  }

  void clearMovieFilters() {
    _movieSortBy = movieLatestSort;
    _movieLanguage = null;
    _movieYear = null;
  }
}
