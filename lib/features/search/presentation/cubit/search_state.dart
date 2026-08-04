import 'package:equatable/equatable.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchTrendingSuccess extends SearchState {
  final List<dynamic> trendingTv;
  final List<dynamic> trendingMovies;
  final int tvPage;
  final int moviesPage;
  final bool tvHasReachedMax;
  final bool moviesHasReachedMax;
  final bool isLoadingMore;
  final bool tvLoadMoreError;
  final bool moviesLoadMoreError;

  const SearchTrendingSuccess({
    required this.trendingTv,
    required this.trendingMovies,
    this.tvPage = 1,
    this.moviesPage = 1,
    this.tvHasReachedMax = false,
    this.moviesHasReachedMax = false,
    this.isLoadingMore = false,
    this.tvLoadMoreError = false,
    this.moviesLoadMoreError = false,
  });

  SearchTrendingSuccess copyWith({
    List<dynamic>? trendingTv,
    List<dynamic>? trendingMovies,
    int? tvPage,
    int? moviesPage,
    bool? tvHasReachedMax,
    bool? moviesHasReachedMax,
    bool? isLoadingMore,
    bool? tvLoadMoreError,
    bool? moviesLoadMoreError,
  }) {
    return SearchTrendingSuccess(
      trendingTv: trendingTv ?? this.trendingTv,
      trendingMovies: trendingMovies ?? this.trendingMovies,
      tvPage: tvPage ?? this.tvPage,
      moviesPage: moviesPage ?? this.moviesPage,
      tvHasReachedMax: tvHasReachedMax ?? this.tvHasReachedMax,
      moviesHasReachedMax: moviesHasReachedMax ?? this.moviesHasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      tvLoadMoreError: tvLoadMoreError ?? this.tvLoadMoreError,
      moviesLoadMoreError: moviesLoadMoreError ?? this.moviesLoadMoreError,
    );
  }

  @override
  List<Object?> get props => [
    trendingTv,
    trendingMovies,
    tvPage,
    moviesPage,
    tvHasReachedMax,
    moviesHasReachedMax,
    isLoadingMore,
    tvLoadMoreError,
    moviesLoadMoreError,
  ];
}

class SearchResultsSuccess extends SearchState {
  final List<dynamic> results;
  final String query;
  final bool isTv;
  final int page;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final bool hasLoadMoreError;

  const SearchResultsSuccess({
    required this.results,
    required this.query,
    required this.isTv,
    this.page = 1,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.hasLoadMoreError = false,
  });

  SearchResultsSuccess copyWith({
    List<dynamic>? results,
    String? query,
    bool? isTv,
    int? page,
    bool? hasReachedMax,
    bool? isLoadingMore,
    bool? hasLoadMoreError,
  }) {
    return SearchResultsSuccess(
      results: results ?? this.results,
      query: query ?? this.query,
      isTv: isTv ?? this.isTv,
      page: page ?? this.page,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasLoadMoreError: hasLoadMoreError ?? this.hasLoadMoreError,
    );
  }

  @override
  List<Object?> get props => [
    results,
    query,
    isTv,
    page,
    hasReachedMax,
    isLoadingMore,
    hasLoadMoreError,
  ];
}

class SearchError extends SearchState {
  final String message;

  const SearchError(this.message);

  @override
  List<Object?> get props => [message];
}
