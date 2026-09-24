import 'package:equatable/equatable.dart';

abstract class SearchState extends Equatable {
  const SearchState();

  @override
  List<Object?> get props => [];
}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

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
