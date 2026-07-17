import 'package:flutter_test/flutter_test.dart';
import 'package:tvtimeapp/features/search/presentation/cubit/search_cubit.dart';
import 'package:tvtimeapp/features/search/presentation/cubit/search_state.dart';
import 'package:tvtimeapp/core/network/tmdb_client.dart';

class MockTmdbClient extends TmdbClient {
  int discoverTvShowsCalled = 0;
  int discoverMoviesCalled = 0;
  int searchTvCalled = 0;
  int searchMovieCalled = 0;
  String? lastSearchQuery;

  @override
  Future<List<dynamic>> discoverTvShows({int page = 1, String sortBy = 'first_air_date.desc'}) async {
    discoverTvShowsCalled++;
    return [{'id': 1, 'name': 'Trending Show'}];
  }

  @override
  Future<List<dynamic>> discoverMovies({int page = 1, String sortBy = 'primary_release_date.desc'}) async {
    discoverMoviesCalled++;
    return [{'id': 2, 'title': 'Trending Movie'}];
  }

  @override
  Future<List<dynamic>> searchTv(String query, {int page = 1}) async {
    searchTvCalled++;
    lastSearchQuery = query;
    return [{'id': 3, 'name': 'Search Show'}];
  }

  @override
  Future<List<dynamic>> searchMovie(String query, {int page = 1}) async {
    searchMovieCalled++;
    lastSearchQuery = query;
    return [{'id': 4, 'title': 'Search Movie'}];
  }
}

void main() {
  late MockTmdbClient mockTmdbClient;
  late SearchCubit searchCubit;

  setUp(() {
    mockTmdbClient = MockTmdbClient();
    searchCubit = SearchCubit(tmdbClient: mockTmdbClient);
  });

  tearDown(() {
    searchCubit.close();
  });

  test('loadTrending should load and cache trending data', () async {
    expect(searchCubit.state, isA<SearchInitial>());

    // First load
    final loadFuture = searchCubit.loadTrending();
    expect(searchCubit.state, isA<SearchLoading>());
    await loadFuture;

    expect(searchCubit.state, isA<SearchTrendingSuccess>());
    final state1 = searchCubit.state as SearchTrendingSuccess;
    expect(state1.trendingTv.first['name'], 'Trending Show');
    expect(state1.trendingMovies.first['title'], 'Trending Movie');

    expect(mockTmdbClient.discoverTvShowsCalled, 1);
    expect(mockTmdbClient.discoverMoviesCalled, 1);

    // Call loadTrending again; should return instantly and not invoke client again (caching test)
    // First, emit a dummy state so that state is SearchTrendingSuccess is not true (which returns immediately without emitting).
    // Actually, if we are in SearchTrendingSuccess, loadTrending() returns early.
    // If we transition to another state and call loadTrending() again, it should use the cache.
    searchCubit.emit(SearchInitial()); 
    await searchCubit.loadTrending();

    expect(searchCubit.state, isA<SearchTrendingSuccess>());
    expect(mockTmdbClient.discoverTvShowsCalled, 1); // Remains 1, meaning cache was used!
    expect(mockTmdbClient.discoverMoviesCalled, 1); // Remains 1, meaning cache was used!
  });

  test('onSearchTextChanged with short query (<3 chars) should load/show trending', () async {
    // 1. If query is less than 3 chars (e.g. 'ab'), should call loadTrending and not search.
    searchCubit.onSearchTextChanged('ab', isTv: true);
    await Future.delayed(const Duration(milliseconds: 600));

    expect(mockTmdbClient.searchTvCalled, 0);
    expect(mockTmdbClient.discoverTvShowsCalled, 1); // Triggered loadTrending
  });

  test('onSearchTextChanged with spaces only should load/show trending', () async {
    searchCubit.onSearchTextChanged('   ', isTv: true);
    await Future.delayed(const Duration(milliseconds: 600));

    expect(mockTmdbClient.searchTvCalled, 0);
    expect(mockTmdbClient.discoverTvShowsCalled, 1);
  });

  test('onSearchTextChanged with valid query (>=3 chars) should debounce and search', () async {
    // 1. Fast typing test
    searchCubit.onSearchTextChanged('abc', isTv: true);
    searchCubit.onSearchTextChanged('abcd', isTv: true);

    // Verify search has not happened yet (debouncing)
    expect(mockTmdbClient.searchTvCalled, 0);

    // Wait for debounce timer (500ms)
    await Future.delayed(const Duration(milliseconds: 600));

    expect(mockTmdbClient.searchTvCalled, 1);
    expect(mockTmdbClient.lastSearchQuery, 'abcd');
    expect(searchCubit.state, isA<SearchResultsSuccess>());
  });
}
