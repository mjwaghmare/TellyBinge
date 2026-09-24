import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../constants/app_constants.dart';
import 'tmdb_cache_manager.dart';

class TmdbClient {
  final Dio _dio;
  // static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _defaultBaseUrl = AppConstants.tmdbDefaultBaseUrl;
  late final String _baseUrl;

  /// Cached API key to avoid reading dotenv on every request
  late final String? _apiKey;
  bool allowAdultContent = false;

  TmdbClient({Dio? dio}) : _dio = dio ?? Dio() {
    _baseUrl = dotenv.env['TMDB_BASE_URL'] ?? _defaultBaseUrl;
    _apiKey = dotenv.env['TMDB_API_KEY'];
    if (_apiKey == null ||
        _apiKey.isEmpty ||
        _apiKey == 'YOUR_TMDB_API_KEY_HERE') {
      debugPrint('Warning: TMDB_API_KEY is not configured in .env file.');
    }

    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    // Add interceptor to automatically append api_key and handle logging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.queryParameters['api_key'] = _apiKey;
          options.queryParameters['language'] = 'en-US'; // Default language
          options.queryParameters['include_adult'] = allowAdultContent;

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

          // Offline banner removed by user request

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
    final overallDeadline = DateTime.now().add(const Duration(seconds: 60));

    for (int retry = 0; retry < maxRetries; retry++) {
      Duration remaining = overallDeadline.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        throw TimeoutException(
          'Overall request deadline exceeded across retries',
        );
      }

      bool timerFired = false;
      final cancelToken = CancelToken();
      final timer = Timer(remaining, () {
        timerFired = true;
        cancelToken.cancel('Deadline exceeded');
      });

      try {
        final response = await _dio.get(
          path,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
        );
        timer.cancel();
        if (timerFired || DateTime.now().isAfter(overallDeadline)) {
          throw TimeoutException(
            'Overall request deadline exceeded across retries',
          );
        }
        return response;
      } on DioException catch (e) {
        timer.cancel();
        if (CancelToken.isCancel(e)) {
          throw TimeoutException(
            'Overall request deadline exceeded across retries',
          );
        }

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

        remaining = overallDeadline.difference(DateTime.now());
        if (remaining.isNegative || remaining == Duration.zero) {
          throw TimeoutException(
            'Overall request deadline exceeded across retries',
          );
        }

        final desiredDelay = Duration(milliseconds: delayMs);
        final actualDelay = desiredDelay > remaining ? remaining : desiredDelay;
        await Future.delayed(actualDelay);

        if (DateTime.now().isAfter(overallDeadline)) {
          throw TimeoutException(
            'Overall request deadline exceeded across retries',
          );
        }
      } catch (e) {
        timer.cancel();
        if (retry == maxRetries - 1) rethrow;

        final errorString = e.toString();
        final isConnectionReset =
            errorString.contains('Connection reset by peer') ||
            errorString.contains('SocketException') ||
            errorString.contains('errno = 54');
        final delayMs = isConnectionReset ? 200 : 500 * (retry + 1);

        remaining = overallDeadline.difference(DateTime.now());
        if (remaining.isNegative || remaining == Duration.zero) {
          throw TimeoutException(
            'Overall request deadline exceeded across retries',
          );
        }

        final desiredDelay = Duration(milliseconds: delayMs);
        final actualDelay = desiredDelay > remaining ? remaining : desiredDelay;
        await Future.delayed(actualDelay);

        if (DateTime.now().isAfter(overallDeadline)) {
          throw TimeoutException(
            'Overall request deadline exceeded across retries',
          );
        }
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
      return _filterContent(results);
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
      return _filterContent(results);
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
      return _filterContent(results);
    } catch (e) {
      debugPrint('Error searching movies: $e');
      return [];
    }
  }

  /// Fetch similar TV shows for a TV show
  Future<List<dynamic>> getSimilarTvShows(int tvId) async {
    final cacheKey = 'similar_tv_$tvId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) {
      return _filterContent(cachedData['results'] as List<dynamic>? ?? []);
    }

    try {
      final response = await _getWithRetry('/tv/$tvId/similar');
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return _filterContent(results);
    } catch (e) {
      debugPrint('Error fetching similar TV shows: $e');
      return [];
    }
  }

  /// Fetch cast and crew for a TV Show
  Future<Map<String, dynamic>> getTvCredits(int tvId) async {
    final cacheKey = 'tv_credits_$tvId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry('/tv/$tvId/credits');
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return data;
    } catch (e) {
      debugPrint('Error fetching TV credits: $e');
      return {'cast': [], 'crew': []};
    }
  }

  /// Fetch detailed information about a TV Show (does not include full season episode details)
  Future<Map<String, dynamic>> getTvShowDetails(int tvId) async {
    final cacheKey = 'tv_details_v5_$tvId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry(
        '/tv/$tvId',
        queryParameters: {
          'append_to_response': 'videos,watch/providers,images',
          'include_image_language': 'en,null',
        },
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
  Future<Map<String, dynamic>> getMovieDetails(
    int movieId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'movie_details_v4_$movieId';
    if (!forceRefresh) {
      final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
      if (cachedData != null) return cachedData;
    }

    try {
      final response = await _getWithRetry(
        '/movie/$movieId',
        queryParameters: {
          'append_to_response': 'videos,watch/providers,images',
          'include_image_language': 'en,null',
        },
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
      debugPrint('Error fetching movie credits: $e');
      return {'cast': [], 'crew': []};
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
      debugPrint('Error fetching collection details: $e');
      return {'parts': []};
    }
  }

  /// Fetch details of a person (actor/crew), including biography, profile, and combined credits.
  Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    final cacheKey = 'person_details_v1_$personId';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry(
        '/person/$personId',
        queryParameters: {'append_to_response': 'combined_credits'},
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
      debugPrint('Error fetching person details for $personId: $e');
      return {};
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

  /// Fetch the posters and backdrops for a movie or TV show.
  ///
  /// Limited to English and text-free (`null`) images; without the filter a
  /// popular title returns dozens of foreign-language posters. Returns an
  /// empty map on failure — callers treat alternate artwork as optional.
  Future<Map<String, dynamic>> getMediaImages(
    String mediaType,
    int id,
  ) async {
    final type = mediaType == 'movie' ? 'movie' : 'tv';
    final cacheKey = '${type}_images_$id';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null) return cachedData;

    try {
      final response = await _getWithRetry(
        '/$type/$id/images',
        queryParameters: {'include_image_language': 'en,null'},
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
      debugPrint('Error fetching $type images: $e');
      return {};
    }
  }

  /// Fetch trending TV shows of the week
  ///
  /// Like the other Explore list fetches: [forceRefresh] skips the fresh-cache
  /// read (a stale copy is still the fallback on failure), and [throwOnError]
  /// rethrows when there is no fallback instead of returning an empty list,
  /// so a caller can tell a failure from the end of the list.
  Future<List<dynamic>> getTrendingTvShows({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'trending_tv_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return _filterContent(results);
    }

    try {
      final response = await _getWithRetry(
        '/trending/tv/week',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return _filterContent(results);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return expiredData['results'] as List<dynamic>;
      }
      debugPrint('Error fetching trending TV shows: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// Fetch trending Movies of the week
  Future<List<dynamic>> getTrendingMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'trending_movie_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return _filterContent(results);
    }

    try {
      final response = await _getWithRetry(
        '/trending/movie/week',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      final results = data['results'] as List<dynamic>? ?? [];
      return _filterContent(results);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return expiredData['results'] as List<dynamic>;
      }
      debugPrint('Error fetching trending movies: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// Fetch Airing Today TV shows
  Future<List<dynamic>> getAiringTodayTvShows({int page = 1}) async {
    final cacheKey = 'airing_today_tv_page_$page';
    final cachedData = await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return _filterContent(cachedData['results'] as List<dynamic>);
    }
    try {
      final response = await _getWithRetry(
        '/tv/airing_today',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return _filterContent(data['results'] as List<dynamic>? ?? []);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return _filterContent(expiredData['results'] as List<dynamic>);
      }
      debugPrint('Error fetching Airing Today TV shows: $e');
      return [];
    }
  }

  /// Fetch Now Playing Movies
  Future<List<dynamic>> getNowPlayingMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'now_playing_movie_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return _filterContent(cachedData['results'] as List<dynamic>);
    }
    try {
      final response = await _getWithRetry(
        '/movie/now_playing',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return _filterContent(data['results'] as List<dynamic>? ?? []);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return _filterContent(expiredData['results'] as List<dynamic>);
      }
      debugPrint('Error fetching Now Playing movies: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// Fetch Upcoming TV shows (On the air)
  Future<List<dynamic>> getUpcomingTvShows({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'upcoming_tv_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return _filterContent(cachedData['results'] as List<dynamic>);
    }
    try {
      final response = await _getWithRetry(
        '/tv/on_the_air',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return _filterContent(data['results'] as List<dynamic>? ?? []);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return _filterContent(expiredData['results'] as List<dynamic>);
      }
      debugPrint('Error fetching Upcoming TV shows: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// Fetch Upcoming Movies
  Future<List<dynamic>> getUpcomingMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'upcoming_movie_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return _filterContent(cachedData['results'] as List<dynamic>);
    }
    try {
      final response = await _getWithRetry(
        '/movie/upcoming',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return _filterContent(data['results'] as List<dynamic>? ?? []);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return _filterContent(expiredData['results'] as List<dynamic>);
      }
      debugPrint('Error fetching Upcoming movies: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// Fetch Top Rated TV shows
  Future<List<dynamic>> getTopRatedTvShows({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'top_rated_tv_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return _filterContent(cachedData['results'] as List<dynamic>);
    }
    try {
      final response = await _getWithRetry(
        '/tv/top_rated',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return _filterContent(data['results'] as List<dynamic>? ?? []);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return _filterContent(expiredData['results'] as List<dynamic>);
      }
      debugPrint('Error fetching Top Rated TV shows: $e');
      if (throwOnError) rethrow;
      return [];
    }
  }

  /// Fetch Top Rated Movies
  Future<List<dynamic>> getTopRatedMovies({
    int page = 1,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final cacheKey = 'top_rated_movie_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    if (cachedData != null && cachedData['results'] != null) {
      return _filterContent(cachedData['results'] as List<dynamic>);
    }
    try {
      final response = await _getWithRetry(
        '/movie/top_rated',
        queryParameters: {'page': page},
      );
      final data = response.data as Map<String, dynamic>;
      await TmdbCacheManager.instance.writeCache(cacheKey, data);
      return _filterContent(data['results'] as List<dynamic>? ?? []);
    } catch (e) {
      final expiredData = await TmdbCacheManager.instance.readCache(
        cacheKey,
        maxAge: const Duration(days: 7),
      );
      if (expiredData != null && expiredData['results'] != null) {
        return _filterContent(expiredData['results'] as List<dynamic>);
      }
      debugPrint('Error fetching Top Rated movies: $e');
      if (throwOnError) rethrow;
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
    String? airDateGte,
    String? airDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final sortedGenres = (genreIds != null && genreIds.isNotEmpty)
        ? (List<int>.from(genreIds)..sort()).join(',')
        : 'none';
    // Appended only when set, so keys for existing callers are unchanged.
    final optionalKey = [
      if (firstAirDateGte != null) '_firstair_$firstAirDateGte',
      if (airDateGte != null || airDateLte != null)
        '_air_${airDateGte ?? 'any'}_${airDateLte ?? 'any'}',
      if (minVoteCount != null) '_votes_$minVoteCount',
    ].join();
    final cacheKey =
        'v3_discover_tv_${sortBy}_${sortedGenres}_${language ?? 'all'}_${originCountry ?? 'all'}_${year ?? 'all'}_${watchProviderId ?? 'all'}${optionalKey}_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    final allowAnime = genreIds != null && genreIds.contains(16);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return {
        'results': _filterContent(results, allowAnime: allowAnime),
        'total_pages': cachedData['total_pages'] ?? 1,
      };
    }

    try {
      final bool hasSpecificFilters =
          year != null ||
          originCountry != null ||
          (watchProviderId != null && watchProviderId.isNotEmpty);
      final int voteThreshold =
          minVoteCount ??
          (hasSpecificFilters ? 0 : _getVoteCountThreshold(sortBy, language));

      // Build query params
      final queryParams = <String, dynamic>{
        'page': page,
        'sort_by': sortBy,
        'vote_count.gte': voteThreshold,
        'with_original_language': language,
        'with_origin_country': originCountry,
      };

      final yearRange = (year != null && year.isNotEmpty)
          ? _parseYearRange(year)
          : null;
      if (yearRange != null) {
        queryParams['first_air_date.gte'] = '${yearRange.$1}-01-01';
        queryParams['first_air_date.lte'] = '${yearRange.$2}-12-31';
      } else if (firstAirDateGte != null) {
        queryParams['first_air_date.gte'] = firstAirDateGte;
      } else if (sortBy == 'first_air_date.desc') {
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        queryParams['first_air_date.lte'] = todayStr;
      }
      if (airDateGte != null) queryParams['air_date.gte'] = airDateGte;
      if (airDateLte != null) queryParams['air_date.lte'] = airDateLte;

      if (watchProviderId != null && watchProviderId.isNotEmpty) {
        queryParams['with_watch_providers'] = watchProviderId;
        queryParams['watch_region'] = 'US';
        queryParams['with_watch_monetization_types'] =
            'flatrate|free|ads|rent|buy';
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
        'results': _filterContent(results, allowAnime: allowAnime),
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
          'results': _filterContent(results, allowAnime: allowAnime),
          'total_pages': expiredData['total_pages'] ?? 1,
        };
      }
      debugPrint('Error discovering TV shows with filters: $e');
      if (throwOnError) rethrow;
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
    String? airDateGte,
    String? airDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final response = await discoverTvShowsWithFiltersPaginated(
      page: page,
      sortBy: sortBy,
      genreIds: genreIds,
      language: language,
      originCountry: originCountry,
      firstAirDateGte: firstAirDateGte,
      airDateGte: airDateGte,
      airDateLte: airDateLte,
      year: year,
      watchProviderId: watchProviderId,
      minVoteCount: minVoteCount,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
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
    String? primaryReleaseDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final sortedGenres = (genreIds != null && genreIds.isNotEmpty)
        ? (List<int>.from(genreIds)..sort()).join(',')
        : 'none';
    // Appended only when set, so keys for existing callers are unchanged.
    final optionalKey = [
      if (primaryReleaseDateGte != null || primaryReleaseDateLte != null)
        '_release_${primaryReleaseDateGte ?? 'any'}_${primaryReleaseDateLte ?? 'any'}',
      if (minVoteCount != null) '_votes_$minVoteCount',
    ].join();
    final cacheKey =
        'v3_discover_movie_${sortBy}_${sortedGenres}_${language ?? 'all'}_${originCountry ?? 'all'}_${year ?? 'all'}_${watchProviderId ?? 'all'}${optionalKey}_page_$page';
    final cachedData = forceRefresh
        ? null
        : await TmdbCacheManager.instance.readCache(cacheKey);
    final allowAnime = genreIds != null && genreIds.contains(16);
    if (cachedData != null && cachedData['results'] != null) {
      final results = cachedData['results'] as List<dynamic>;
      return {
        'results': _filterContent(results, allowAnime: allowAnime),
        'total_pages': cachedData['total_pages'] ?? 1,
      };
    }

    try {
      final bool hasSpecificFilters =
          year != null ||
          originCountry != null ||
          (watchProviderId != null && watchProviderId.isNotEmpty);
      final int voteThreshold =
          minVoteCount ??
          (hasSpecificFilters ? 0 : _getVoteCountThreshold(sortBy, language));

      // Build query params
      final queryParams = <String, dynamic>{
        'page': page,
        'sort_by': sortBy,
        'vote_count.gte': voteThreshold,
        'with_original_language': language,
        'with_origin_country': originCountry,
      };

      final yearRange = (year != null && year.isNotEmpty)
          ? _parseYearRange(year)
          : null;
      if (yearRange != null) {
        queryParams['primary_release_date.gte'] = '${yearRange.$1}-01-01';
        queryParams['primary_release_date.lte'] = '${yearRange.$2}-12-31';
      } else if (primaryReleaseDateGte != null ||
          primaryReleaseDateLte != null) {
        if (primaryReleaseDateGte != null) {
          queryParams['primary_release_date.gte'] = primaryReleaseDateGte;
        }
        if (primaryReleaseDateLte != null) {
          queryParams['primary_release_date.lte'] = primaryReleaseDateLte;
        }
      } else if (sortBy == 'primary_release_date.desc') {
        final todayStr = DateTime.now().toIso8601String().split('T').first;
        queryParams['primary_release_date.lte'] = todayStr;
      }

      if (watchProviderId != null && watchProviderId.isNotEmpty) {
        queryParams['with_watch_providers'] = watchProviderId;
        queryParams['watch_region'] = 'US';
        queryParams['with_watch_monetization_types'] =
            'flatrate|free|ads|rent|buy';
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
        'results': _filterContent(results, allowAnime: allowAnime),
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
          'results': _filterContent(results, allowAnime: allowAnime),
          'total_pages': expiredData['total_pages'] ?? 1,
        };
      }
      debugPrint('Error discovering movies with filters: $e');
      if (throwOnError) rethrow;
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
    String? primaryReleaseDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    final response = await discoverMoviesWithFiltersPaginated(
      page: page,
      sortBy: sortBy,
      genreIds: genreIds,
      language: language,
      originCountry: originCountry,
      primaryReleaseDateGte: primaryReleaseDateGte,
      primaryReleaseDateLte: primaryReleaseDateLte,
      year: year,
      watchProviderId: watchProviderId,
      minVoteCount: minVoteCount,
      forceRefresh: forceRefresh,
      throwOnError: throwOnError,
    );
    return response['results'] as List<dynamic>;
  }

  /// Resolves the `year` filter into an inclusive (start, end) year pair.
  ///
  /// Accepts three forms: a range as written by the Explore range picker
  /// ("1990-2010"), a decade ("2020s"), and a single year ("2026"). The latter
  /// two predate the range picker and are kept so any value still held in
  /// memory or in a cached filter selection keeps resolving.
  ///
  /// Returns null for anything unparseable, in which case the caller sends no
  /// date bounds at all rather than guessing.
  (int, int)? _parseYearRange(String year) {
    if (year.contains('-')) {
      final parts = year.split('-');
      if (parts.length != 2) return null;
      final from = int.tryParse(parts[0].trim());
      final to = int.tryParse(parts[1].trim());
      if (from == null || to == null) return null;
      return from <= to ? (from, to) : (to, from);
    }

    if (year.endsWith('s')) {
      final startYear = int.tryParse(year.substring(0, year.length - 1));
      return startYear == null ? null : (startYear, startYear + 9);
    }

    final single = int.tryParse(year);
    return single == null ? null : (single, single);
  }

  int _getVoteCountThreshold(String sortBy, [String? language]) {
    if (language == 'mr') {
      return 0; // Regional content like Marathi has very few votes on TMDB
    }
    if (sortBy == 'vote_average.desc') {
      // Deliberately high: this sort ranks by score alone, so a lower floor
      // puts "10.0 from two votes" above genuinely acclaimed titles.
      return 100;
    } else if (sortBy == 'first_air_date.desc' ||
        sortBy == 'primary_release_date.desc') {
      // Newest-first legitimately surfaces titles that have accumulated genuine votes,
      // excluding obscure 0-vote or fake 1-vote stub entries.
      return 5;
    } else if (sortBy == 'popularity.desc') {
      // 1 rather than 0 — TMDB carries a long tail of zero-vote stub entries,
      // and Surprise Me pages randomly as deep as page 500, so it reads
      // straight into that tail. One real vote is enough to filter them.
      return 1;
    }
    return 0;
  }

  /// Central helper to filter out unwanted content like Anime and Adult content from TMDB results.
  List<dynamic> _filterContent(
    List<dynamic> results, {
    bool allowAnime = false,
  }) {
    return results.where((item) {
      if (item is! Map<String, dynamic>) return true;

      // 1. Adult Content Filter
      if (!allowAdultContent && item['adult'] == true) {
        return false;
      }

      // 2. Anime Filter (bypassed when Anime is explicitly requested)
      if (!allowAnime) {
        final originalLanguage = item['original_language'] as String?;
        final genreIds =
            (item['genre_ids'] as List<dynamic>?)?.cast<int>() ?? [];

        // Filter out Japanese Animation
        if (originalLanguage == 'ja' && genreIds.contains(16)) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}
