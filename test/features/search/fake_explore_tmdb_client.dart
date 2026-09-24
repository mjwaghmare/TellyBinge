import 'package:popverse/core/network/tmdb_client.dart';

/// One recorded call to an Explore-facing [TmdbClient] method.
class ExploreCall {
  ExploreCall(
    this.method, {
    required this.page,
    this.forceRefresh = false,
    this.throwOnError = false,
    this.language,
    this.genreIds,
    this.sortBy,
    this.minVoteCount,
    this.airDateGte,
    this.airDateLte,
    this.firstAirDateGte,
    this.releaseDateGte,
    this.releaseDateLte,
  });

  final String method;
  final int page;
  final bool forceRefresh;
  final bool throwOnError;
  final String? language;
  final List<int>? genreIds;
  final String? sortBy;
  final int? minVoteCount;
  final String? airDateGte;
  final String? airDateLte;
  final String? firstAirDateGte;
  final String? releaseDateGte;
  final String? releaseDateLte;

  @override
  String toString() => '$method(page: $page, language: $language, genreIds: $genreIds)';
}

/// Records every Explore fetch and answers with [respond] (empty by default).
class FakeExploreTmdbClient extends TmdbClient {
  FakeExploreTmdbClient({this.respond});

  Future<List<dynamic>> Function(ExploreCall call)? respond;
  final List<ExploreCall> calls = [];

  Future<List<dynamic>> _record(ExploreCall call) {
    calls.add(call);
    return respond?.call(call) ?? Future.value(const []);
  }

  @override
  Future<List<dynamic>> getTrendingTvShows({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'trendingTv',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> getTrendingMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'trendingMovie',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> getTopRatedTvShows({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'topRatedTv',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> getTopRatedMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'topRatedMovie',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> getUpcomingTvShows({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'onTheAirTv',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> getNowPlayingMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'nowPlayingMovie',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> getUpcomingMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'upcomingMovie',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    ),
  );

  @override
  Future<List<dynamic>> searchTv(String query, {int page = 1}) =>
      _record(ExploreCall('searchTv', page: page));

  @override
  Future<List<dynamic>> searchMovie(String query, {int page = 1}) =>
      _record(ExploreCall('searchMovie', page: page));

  @override
  Future<List<dynamic>> discoverTvShowsWithFilters({
    int page = 1,
    String sortBy = 'first_air_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? firstAirDateGte,
    String? airDateGte,
    String? airDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'discoverTv',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
      language: language,
      genreIds: genreIds,
      sortBy: sortBy,
      minVoteCount: minVoteCount,
      airDateGte: airDateGte,
      airDateLte: airDateLte,
      firstAirDateGte: firstAirDateGte,
    ),
  );

  @override
  Future<List<dynamic>> discoverMoviesWithFilters({
    int page = 1,
    String sortBy = 'primary_release_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? primaryReleaseDateGte,
    String? primaryReleaseDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) => _record(
    ExploreCall(
      'discoverMovie',
      page: page,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
      language: language,
      genreIds: genreIds,
      sortBy: sortBy,
      minVoteCount: minVoteCount,
      releaseDateGte: primaryReleaseDateGte,
      releaseDateLte: primaryReleaseDateLte,
    ),
  );
}

/// A fake TMDB page of [count] titles with ids starting at [from].
List<dynamic> titles(int from, int count, {String language = 'en'}) => [
  for (var id = from; id < from + count; id++)
    {'id': id, 'name': 'Title $id', 'original_language': language},
];
