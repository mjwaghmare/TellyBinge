import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'tmdb_cache_manager.dart';

class TmdbClient {
  final Dio _dio;
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  /// Cached API key to avoid reading dotenv on every request
  late final String? _apiKey;

  TmdbClient({Dio? dio}) : _dio = dio ?? Dio() {
    _apiKey = dotenv.env['TMDB_API_KEY'];
    if (_apiKey == null ||
        _apiKey.isEmpty ||
        _apiKey == 'YOUR_TMDB_API_KEY_HERE') {
      debugPrint('Warning: TMDB_API_KEY is not configured in .env file.');
    }

    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 20);

    // Add interceptor to automatically append api_key and handle logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.queryParameters['api_key'] = _apiKey;
          options.queryParameters['language'] = 'en-US'; // Default language

          // Removed fake User-Agent to prevent Cloudflare blocks
          return handler.next(options);
        },
        onError: (DioException e, handler) {
          // Mute 'Connection reset by peer' spam since we handle retries
          final isConnectionReset =
              e.message?.contains('Connection reset by peer') == true ||
              e.error.toString().contains('Connection reset by peer');
          if (!isConnectionReset) {
            debugPrint('TmdbClient Error: ${e.message}');
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// Internal helper to perform a GET request with smart retries.
  /// It skips retrying on 4xx client errors (except 429 Too Many Requests)
  /// but retries connection timeouts and server errors.
  Future<Response<dynamic>> _getWithRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
    int maxRetries = 3,
  }) async {
    for (int retry = 0; retry < maxRetries; retry++) {
      try {
        return await _dio.get(path, queryParameters: queryParameters);
      } on DioException catch (e) {
        // Don't retry on client errors (4xx) except 429 (Rate Limit)
        if (e.response != null) {
          final statusCode = e.response?.statusCode ?? 500;
          if (statusCode >= 400 && statusCode < 500 && statusCode != 429) {
            rethrow;
          }
        }

        if (retry == maxRetries - 1) rethrow;

        // Always delay before retry — use shorter delay for connection resets
        final errorString = e.toString();
        final isConnectionReset =
            errorString.contains('Connection reset by peer') ||
            errorString.contains('SocketException') ||
            errorString.contains('errno = 54');
        final delayMs = isConnectionReset ? 200 : 500 * (retry + 1);
        await Future.delayed(Duration(milliseconds: delayMs));
      } catch (e) {
        if (retry == maxRetries - 1) rethrow;

        final errorString = e.toString();
        final isConnectionReset =
            errorString.contains('Connection reset by peer') ||
            errorString.contains('SocketException') ||
            errorString.contains('errno = 54');
        final delayMs = isConnectionReset ? 200 : 500 * (retry + 1);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw Exception('Unreachable');
  }

  /// Search movies, TV shows, and people
  Future<List<dynamic>> searchMulti(String query, {int page = 1}) async {
    try {
      final response = await _getWithRetry(
        '/search/multi',
        queryParameters: {'query': query, 'page': page},
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return _filterAnime(results);
    } catch (e) {
      throw Exception('Failed to search TMDb: $e');
    }
  }

  /// Search TV shows specifically
  Future<List<dynamic>> searchTv(String query, {int page = 1}) async {
    try {
      final response = await _getWithRetry(
        '/search/tv',
        queryParameters: {'query': query, 'page': page},
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return _filterAnime(results);
    } catch (e) {
      debugPrint('Error searching TV shows: $e');
      return [];
    }
  }

  /// Find TV show by TVDB ID
  Future<Map<String, dynamic>?> findByTvdbId(String tvdbId) async {
    try {
      final response = await _getWithRetry(
        '/find/$tvdbId',
        queryParameters: {'external_source': 'tvdb_id'},
      );
      final tvResults = response.data['tv_results'] as List<dynamic>? ?? [];
      if (tvResults.isNotEmpty) {
        return tvResults.first as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error finding TV show by TVDB ID: $e');
      return null;
    }
  }

  /// Search movies specifically
  Future<List<dynamic>> searchMovie(String query, {int page = 1}) async {
    try {
      final response = await _getWithRetry(
        '/search/movie',
        queryParameters: {'query': query, 'page': page},
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      return _filterAnime(results);
    } catch (e) {
      debugPrint('Error searching movies: $e');
      return [];
    }
  }

  /// Fetch detailed information about a TV Show (does not include full season episode details)
  Future<Map<String, dynamic>> getTvShowDetails(int tvId) async {
    final cacheKey = 'tv_details_v3_$tvId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry(
        '/tv/$tvId',
        queryParameters: {'append_to_response': 'videos,credits'},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data;
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 30),
      );
      if (expiredData != null) return expiredData;
      throw Exception('Failed to fetch TV show details: $e');
    }
  }

  /// Fetch detailed episodes list for a specific season of a TV show
  Future<Map<String, dynamic>> getTvSeasonDetails(
    int tvId,
    int seasonNumber,
  ) async {
    final cacheKey = 'tv_season_${tvId}_$seasonNumber';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry('/tv/$tvId/season/$seasonNumber');
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data;
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 30),
      );
      if (expiredData != null) return expiredData;
      throw Exception('Failed to fetch TV season details: $e');
    }
  }

  /// Fetch detailed information about a Movie
  Future<Map<String, dynamic>> getMovieDetails(int movieId) async {
    final cacheKey = 'movie_details_v2_$movieId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry(
        '/movie/$movieId',
        queryParameters: {'append_to_response': 'videos'},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data;
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 30),
      );
      if (expiredData != null) return expiredData;
      throw Exception('Failed to fetch movie details: $e');
    }
  }

  /// Fetch cast and crew credits for a Movie
  Future<Map<String, dynamic>> getMovieCredits(int movieId) async {
    final cacheKey = 'movie_credits_$movieId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry('/movie/$movieId/credits');
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data;
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 30),
      );
      if (expiredData != null) return expiredData;
      throw Exception('Failed to fetch movie credits: $e');
    }
  }

  /// Fetch details of a movie collection (franchise parts)
  Future<Map<String, dynamic>> getCollectionDetails(int collectionId) async {
    final cacheKey = 'movie_collection_$collectionId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry('/collection/$collectionId');
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data;
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 30),
      );
      if (expiredData != null) return expiredData;
      throw Exception('Failed to fetch collection details: $e');
    }
  }

  /// Fetch similar movies for a movie
  Future<List<dynamic>> getSimilarMovies(int movieId) async {
    final cacheKey = 'similar_movies_$movieId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return cachedData['results'] as List<dynamic>;
    }

    try {
      final response = await _getWithRetry('/movie/$movieId/similar');
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data['results'] as List<dynamic>? ?? [];
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 30),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return expiredData['results'] as List<dynamic>;
      }
      debugPrint('Error fetching similar movies: $e');
      return [];
    }
  }

  /// Fetch trending TV shows of the week
  Future<List<dynamic>> getTrendingTvShows({int page = 1}) async {
    final cacheKey = 'trending_tv_page_$page';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return _filterAnime(results);
    }

    try {
      final response = await _getWithRetry(
        '/trending/tv/week',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return _filterAnime(results);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return expiredData['results'] as List<dynamic>;
      }
      debugPrint('Error fetching trending TV shows: $e');
      return [];
    }
  }

  /// Fetch trending Movies of the week
  Future<List<dynamic>> getTrendingMovies({int page = 1}) async {
    final cacheKey = 'trending_movie_page_$page';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return _filterAnime(results);
    }

    try {
      final response = await _getWithRetry(
        '/trending/movie/week',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return _filterAnime(results);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return expiredData['results'] as List<dynamic>;
      }
      debugPrint('Error fetching trending movies: $e');
      return [];
    }
  }

  /// Discover TV shows with sorting (delegates to filter method)
  Future<List<dynamic>> discoverTvShows({
    int page = 1,
    String sortBy = 'first_air_date.desc',
  }) {
    return discoverTvShowsWithFilters(
      page: page,
      sortBy: sortBy,
      language: 'en',
    );
  }

  /// Discover Movies with sorting (delegates to filter method)
  Future<List<dynamic>> discoverMovies({
    int page = 1,
    String sortBy = 'primary_release_date.desc',
  }) {
    return discoverMoviesWithFilters(
      page: page,
      sortBy: sortBy,
      language: 'en',
    );
  }

  /// Discover TV shows with filters (returns paginated data)
  Future<Map<String, dynamic>> discoverTvShowsWithFiltersPaginated({
    int page = 1,
    String sortBy = 'first_air_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? firstAirDateGte,
  }) async {
    final cacheKey =
        'discover_tv_${sortBy}_${genreIds?.join(',') ?? 'none'}_${language ?? 'all'}_${originCountry ?? 'all'}_${firstAirDateGte ?? 'none'}_page_$page';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return {
        'results': _filterAnime(results),
        'total_pages': cachedData['total_pages'] ?? 1,
      };
    }

    try {
      // Build query params
      final queryParams = <String, dynamic>{
        'page': page,
        'sort_by': sortBy,
        'vote_count.gte': _getVoteCountThreshold(sortBy, language),
        'with_original_language': language,
        'with_origin_country': originCountry,
      };

      if (firstAirDateGte != null) {
        queryParams['first_air_date.gte'] = firstAirDateGte;
      }

      if (genreIds != null && genreIds.isNotEmpty) {
        // Use pipe '|' for OR logic across multiple genres (native TMDB support)
        queryParams['with_genres'] = genreIds.join('|');
      }

      final response = await _getWithRetry(
        '/discover/tv',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return {
        'results': _filterAnime(results),
        'total_pages': data['total_pages'] ?? 1,
      };
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        final results = expiredData['results'] as List<dynamic>;
        return {
          'results': _filterAnime(results),
          'total_pages': expiredData['total_pages'] ?? 1,
        };
      }
      debugPrint('Error discovering TV shows with filters: $e');
      return {'results': [], 'total_pages': 1};
    }
  }

  /// Discover TV shows with filters
  Future<List<dynamic>> discoverTvShowsWithFilters({
    int page = 1,
    String sortBy = 'first_air_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? firstAirDateGte,
  }) async {
    final response = await discoverTvShowsWithFiltersPaginated(
      page: page,
      sortBy: sortBy,
      genreIds: genreIds,
      language: language,
      originCountry: originCountry,
      firstAirDateGte: firstAirDateGte,
    );
    return response['results'] as List<dynamic>;
  }

  /// Discover movies with filters (returns paginated data)
  Future<Map<String, dynamic>> discoverMoviesWithFiltersPaginated({
    int page = 1,
    String sortBy = 'primary_release_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? primaryReleaseDateGte,
  }) async {
    final cacheKey =
        'discover_movie_${sortBy}_${genreIds?.join(',') ?? 'none'}_${language ?? 'all'}_${originCountry ?? 'all'}_${primaryReleaseDateGte ?? 'none'}_page_$page';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return {
        'results': _filterAnime(results),
        'total_pages': cachedData['total_pages'] ?? 1,
      };
    }

    try {
      // Build query params
      final queryParams = <String, dynamic>{
        'page': page,
        'sort_by': sortBy,
        'vote_count.gte': _getVoteCountThreshold(sortBy, language),
        'with_original_language': language,
        'with_origin_country': originCountry,
      };

      if (primaryReleaseDateGte != null) {
        queryParams['primary_release_date.gte'] = primaryReleaseDateGte;
      }

      if (genreIds != null && genreIds.isNotEmpty) {
        // Use pipe '|' for OR logic across multiple genres (native TMDB support)
        queryParams['with_genres'] = genreIds.join('|');
      }

      final response = await _getWithRetry(
        '/discover/movie',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return {
        'results': _filterAnime(results),
        'total_pages': data['total_pages'] ?? 1,
      };
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        final results = expiredData['results'] as List<dynamic>;
        return {
          'results': _filterAnime(results),
          'total_pages': expiredData['total_pages'] ?? 1,
        };
      }
      debugPrint('Error discovering movies with filters: $e');
      return {'results': [], 'total_pages': 1};
    }
  }

  /// Discover movies with filters
  Future<List<dynamic>> discoverMoviesWithFilters({
    int page = 1,
    String sortBy = 'primary_release_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? primaryReleaseDateGte,
  }) async {
    final response = await discoverMoviesWithFiltersPaginated(
      page: page,
      sortBy: sortBy,
      genreIds: genreIds,
      language: language,
      originCountry: originCountry,
      primaryReleaseDateGte: primaryReleaseDateGte,
    );
    return response['results'] as List<dynamic>;
  }
  int _getVoteCountThreshold(String sortBy, [String? language]) {
    if (language == 'mr') {
      return 0; // Regional content like Marathi has very few votes on TMDB
    }
    if (sortBy == 'vote_average.desc') {
      return 100;
    } else if (sortBy == 'first_air_date.desc' ||
        sortBy == 'primary_release_date.desc') {
      return 5;
    } else if (sortBy == 'popularity.desc') {
      return 5;
    }
    return 0;
  }

  /// Central helper to filter out Anime from TMDB results.
  /// We identify anime as having original_language 'ja' and genre 16 (Animation).
  List<dynamic> _filterAnime(List<dynamic> results) {
    return results.where((item) {
      if (item is! Map<String, dynamic>) return true;
      final originalLanguage = item['original_language'] as String?;
      final genreIds = (item['genre_ids'] as List<dynamic>?)?.cast<int>() ?? [];

      // Filter out Japanese Animation
      if (originalLanguage == 'ja' && genreIds.contains(16)) {
        return false;
      }
      return true;
    }).toList();
  }
}
