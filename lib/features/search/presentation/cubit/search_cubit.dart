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

  String _tvSortBy = 'trending';
  String? _tvLanguage;
  String? _tvYear;

  // Filter state for Movies
  String _movieSortBy = 'trending';
  String? _movieLanguage;
  String? _movieYear;

  SearchCubit({required this.tmdbClient}) : super(SearchInitial());

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
      final tvShows = await tmdbClient.getTrendingTvShows();
      // Stagger by 100ms to prevent simultaneous socket handshakes on startup
      await Future.delayed(const Duration(milliseconds: 100));
      final movies = await tmdbClient.getTrendingMovies();

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

        final bool tvNoFilters = _tvLanguage == null && _tvYear == null;
        final bool movieNoFilters = _movieLanguage == null && _movieYear == null;

        List<dynamic> newResults = [];

        if (isTvTab) {
          if (_tvSortBy == 'trending' && tvNoFilters) {
            newResults = await tmdbClient.getTrendingTvShows(page: nextPage);
          } else if (_tvSortBy == 'airing_today' && tvNoFilters) {
            newResults = await tmdbClient.getAiringTodayTvShows(page: nextPage);
          } else if (_tvSortBy == 'upcoming' && tvNoFilters) {
            newResults = await tmdbClient.getUpcomingTvShows(page: nextPage);
          } else {
            final effectiveSortBy = (_tvSortBy == 'trending' || _tvSortBy == 'popularity.desc')
                ? 'popularity.desc'
                : (_tvSortBy == 'airing_today' || _tvSortBy == 'upcoming'
                    ? 'first_air_date.desc'
                    : _tvSortBy);
            newResults = await tmdbClient.discoverTvShowsWithFilters(
              page: nextPage,
              sortBy: effectiveSortBy,
              language: _tvLanguage,
              year: _tvYear,
            );
          }
        } else {
          if (_movieSortBy == 'trending' && movieNoFilters) {
            newResults = await tmdbClient.getTrendingMovies(page: nextPage);
          } else if (_movieSortBy == 'now_playing' && movieNoFilters) {
            newResults = await tmdbClient.getNowPlayingMovies(page: nextPage);
          } else if (_movieSortBy == 'upcoming' && movieNoFilters) {
            newResults = await tmdbClient.getUpcomingMovies(page: nextPage);
          } else {
            final effectiveSortBy = (_movieSortBy == 'trending' || _movieSortBy == 'popularity.desc')
                ? 'popularity.desc'
                : (_movieSortBy == 'now_playing' || _movieSortBy == 'upcoming'
                    ? 'primary_release_date.desc'
                    : _movieSortBy);
            newResults = await tmdbClient.discoverMoviesWithFilters(
              page: nextPage,
              sortBy: effectiveSortBy,
              language: _movieLanguage,
              year: _movieYear,
            );
          }
        }

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
              ? (List<dynamic>.from(currentState.trendingTv)
                  ..addAll(newResults))
              : currentState.trendingTv;
          final updatedMovies = !isTvTab
              ? (List<dynamic>.from(currentState.trendingMovies)
                  ..addAll(newResults))
              : currentState.trendingMovies;

          // Deduplicate by id
          final uniqueTv = <int, dynamic>{};
          for (var item in updatedTv) {
            uniqueTv[item['id'] as int] = item;
          }
          final uniqueMovies = <int, dynamic>{};
          for (var item in updatedMovies) {
            uniqueMovies[item['id'] as int] = item;
          }

          emit(
            currentState.copyWith(
              trendingTv: uniqueTv.values.toList(),
              trendingMovies: uniqueMovies.values.toList(),
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
      emit(
        currentState.copyWith(
          isLoadingMore: true,
          hasLoadMoreError: false,
        ),
      );

      try {
        final nextPage = currentState.page + 1;
        final newResults = currentState.isTv
            ? await tmdbClient.searchTv(currentState.query, page: nextPage)
            : await tmdbClient.searchMovie(currentState.query, page: nextPage);

        var filteredNewResults = newResults;
        if (currentState.isTv && _tvLanguage != null) {
          filteredNewResults = newResults.where((item) => item['original_language'] == _tvLanguage).toList();
        } else if (!currentState.isTv && _movieLanguage != null) {
          filteredNewResults = newResults.where((item) => item['original_language'] == _movieLanguage).toList();
        }

        if (filteredNewResults.isEmpty) {
          emit(
            currentState.copyWith(hasReachedMax: true, isLoadingMore: false),
          );
        } else {
          final updatedResults = List<dynamic>.from(currentState.results)
            ..addAll(filteredNewResults);

          final uniqueResults = <int, dynamic>{};
          for (var item in updatedResults) {
            uniqueResults[item['id'] as int] = item;
          }
          final deduplicatedList = uniqueResults.values.toList();

          emit(
            currentState.copyWith(
              results: deduplicatedList,
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
        filteredResults = results.where((item) => item['original_language'] == _tvLanguage).toList();
      } else if (!isTv && _movieLanguage != null) {
        filteredResults = results.where((item) => item['original_language'] == _movieLanguage).toList();
      }

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
    if (currentState is SearchTrendingSuccess) {
      emit(
        currentState.copyWith(
          trendingTv: filteredShows,
          tvPage: 1,
          tvHasReachedMax: filteredShows.isEmpty,
        ),
      );
    } else {
      emit(
        SearchTrendingSuccess(
          trendingTv: filteredShows,
          trendingMovies: _cachedTrendingMovies ?? [],
          tvPage: 1,
          moviesPage: 1,
          tvHasReachedMax: filteredShows.isEmpty,
          moviesHasReachedMax: (_cachedTrendingMovies ?? []).isEmpty,
        ),
      );
    }
  }

  void updateTrendingMovies(List<dynamic> filteredMovies) {
    final currentState = state;
    if (currentState is SearchTrendingSuccess) {
      emit(
        currentState.copyWith(
          trendingMovies: filteredMovies,
          moviesPage: 1,
          moviesHasReachedMax: filteredMovies.isEmpty,
        ),
      );
    } else {
      emit(
        SearchTrendingSuccess(
          trendingTv: _cachedTrendingTv ?? [],
          trendingMovies: filteredMovies,
          tvPage: 1,
          moviesPage: 1,
          tvHasReachedMax: (_cachedTrendingTv ?? []).isEmpty,
          moviesHasReachedMax: filteredMovies.isEmpty,
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
    String sortBy = 'trending',
    String? language,
    String? year,
  }) {
    _tvSortBy = sortBy;
    _tvLanguage = language;
    _tvYear = year;
  }

  void setMovieFilters({
    String sortBy = 'trending',
    String? language,
    String? year,
  }) {
    _movieSortBy = sortBy;
    _movieLanguage = language;
    _movieYear = year;
  }

  void clearTvFilters() {
    _tvSortBy = 'trending';
    _tvLanguage = null;
    _tvYear = null;
  }

  void clearMovieFilters() {
    _movieSortBy = 'trending';
    _movieLanguage = null;
    _movieYear = null;
  }
}
