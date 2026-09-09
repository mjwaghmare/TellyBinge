import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/repositories/movie_watchlist_repository.dart';
import 'movie_watchlist_state.dart';

class MovieWatchlistCubit extends Cubit<MovieWatchlistState> {
  final MovieWatchlistRepository movieWatchlistRepository;
  final TmdbClient? tmdbClient;
  StreamSubscription? _watchlistSubscription;

  // Sets to manage concurrent requests and failure retry loops
  final Set<int> _backfillingMovieIds = {};
  final Set<int> _failedMovieIds = {};
  bool _isSyncing = false;
  Future<void>? _activeSyncFuture;

  MovieWatchlistCubit({required this.movieWatchlistRepository, this.tmdbClient})
    : super(MovieWatchlistInitial());

  void watchWatchlist(String uid) {
    emit(MovieWatchlistLoading());
    _watchlistSubscription?.cancel();

    _watchlistSubscription = movieWatchlistRepository
        .watchWatchlist(uid)
        .listen(
          (movies) {
            emit(MovieWatchlistSuccess(movies));

            // Hand the whole watchlist over; the service reconciles it against
            // what's actually scheduled. Watched movies are simply absent here and
            // get cancelled as a result.
            NotificationService().submitTitles(NotificationMedia.movie, [
              for (final movie in movies)
                if ((movie['isWatched'] as bool? ?? false) == false &&
                    (movie['id'] as num?) != null &&
                    (movie['releaseDate'] as String?) != null)
                  () {
                    final (
                      title,
                      body,
                    ) = NotificationService.generateMovieNotificationContent(
                      movieId: (movie['id'] as num).toInt(),
                      movieTitle: movie['title'] as String? ?? 'Movie',
                    );
                    return PendingNotification(
                      media: NotificationMedia.movie,
                      mediaId: (movie['id'] as num).toInt(),
                      title: title,
                      body: body,
                      releaseDateStr: movie['releaseDate'] as String,
                    );
                  }(),
            ]);

            // Start backfilling in the background sequentially to avoid socket rate limiting
            _backfillMissingGenres(uid, movies);

            // Check if upcoming/recent movie release dates need their once-a-day sync
            syncUpcomingMovies(uid, movies: movies);
          },
          onError: (error) {
            emit(MovieWatchlistError(error.toString()));
          },
        );
  }

  // Sequential backfiller that manages lock set and delays requests
  Future<void> _backfillMissingGenres(
    String uid,
    List<Map<String, dynamic>> movies,
  ) async {
    if (tmdbClient == null) return;

    for (final movie in movies) {
      if (isClosed) break;
      if (!movie.containsKey('genres')) {
        final movieId = (movie['id'] as num?)?.toInt();
        if (movieId != null) {
          if (_backfillingMovieIds.contains(movieId) ||
              _failedMovieIds.contains(movieId)) {
            continue;
          }

          _backfillingMovieIds.add(movieId);
          try {
            await _fillMissingGenres(uid, movieId);
            // Throttle requests (250ms delay) to prevent TMDb API/Cloudflare connection resets
            await Future.delayed(const Duration(milliseconds: 250));
          } catch (_) {
            _failedMovieIds.add(movieId);
          } finally {
            _backfillingMovieIds.remove(movieId);
          }
        }
      }
    }
  }

  // Helper method rethrows error so backfill process can register the failure
  Future<void> _fillMissingGenres(String uid, int movieId) async {
    try {
      if (tmdbClient == null) return;
      final details = await tmdbClient!.getMovieDetails(movieId);
      final List<dynamic>? genresList = details['genres'] as List<dynamic>?;
      final genresStr = (genresList != null && genresList.isNotEmpty)
          ? genresList.map((g) => g['name'] as String? ?? '').join(', ')
          : '';
      await movieWatchlistRepository.updateMovieGenres(
        uid: uid,
        movieId: movieId,
        genres: genresStr,
      );
    } catch (e) {
      debugPrint('Error filling missing genres for movie $movieId: $e');
      rethrow;
    }
  }

  /// Daily background sync of release dates, posters, and runtimes for
  /// unreleased, missing-date, and recently scheduled movies (<= 14 days ago).
  ///
  /// Runs once per calendar day when the user opens the app or views the Movies tab.
  /// Bypassed when [force] is true (e.g. on manual pull-to-refresh).
  Future<void> syncUpcomingMovies(
    String uid, {
    List<Map<String, dynamic>>? movies,
    bool force = false,
  }) async {
    if (tmdbClient == null || isClosed) return;
    if (_isSyncing) {
      if (force && _activeSyncFuture != null) {
        await _activeSyncFuture;
      }
      return;
    }

    final targetMovies = movies ??
        (state is MovieWatchlistSuccess
            ? (state as MovieWatchlistSuccess).movies
            : null);
    if (targetMovies == null || targetMovies.isEmpty) return;

    _isSyncing = true;
    final syncFuture = _executeSyncUpcomingMovies(
      uid,
      targetMovies,
      force: force,
    );
    _activeSyncFuture = syncFuture;
    try {
      await syncFuture;
    } finally {
      _isSyncing = false;
      _activeSyncFuture = null;
    }
  }

  Future<void> _executeSyncUpcomingMovies(
    String uid,
    List<Map<String, dynamic>> targetMovies, {
    required bool force,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final syncKey = 'movie_sync_last_date_$uid';

      if (!force) {
        final lastSyncDate = prefs.getString(syncKey);
        if (lastSyncDate == todayStr) {
          return; // Already synced today on this device
        }
      }

      // Filter: unreleased, missing release date, or scheduled within last 14 days
      final eligible = targetMovies.where((movie) {
        if (movie['isWatched'] == true) return false;
        final rawId = movie['id'];
        if (rawId == null) return false;

        final relStr =
            (movie['releaseDate'] ?? movie['release_date']) as String? ?? '';
        if (relStr.isEmpty || relStr.toUpperCase() == 'TBA') return true;

        final relDate = DateTime.tryParse(relStr);
        if (relDate == null) return true;

        final today = DateTime.utc(now.year, now.month, now.day);
        final relDay = DateTime.utc(relDate.year, relDate.month, relDate.day);
        final diffDays = relDay.difference(today).inDays;

        // Keep unreleased movies (diffDays >= 0) and recently released movies (diffDays >= -14)
        return diffDays >= -14;
      }).toList();

      if (eligible.isEmpty) {
        await prefs.setString(syncKey, todayStr);
        return;
      }

      bool atLeastOneSuccess = false;
      bool hadNetworkFailure = false;

      for (final movie in eligible) {
        if (isClosed || state is! MovieWatchlistSuccess) break;
        final movieId = (movie['id'] as num?)?.toInt();
        if (movieId == null) continue;

        // Skip if movie was deleted from watchlist or marked as watched mid-sync
        if (state is MovieWatchlistSuccess) {
          final currentMovies = (state as MovieWatchlistSuccess).movies;
          final stillEligible = currentMovies.any(
            (m) => m['id'] == movieId && m['isWatched'] != true,
          );
          if (!stillEligible) continue;
        }

        try {
          final details = await tmdbClient!.getMovieDetails(
            movieId,
            forceRefresh: true,
          );
          atLeastOneSuccess = true;

          final tmdbReleaseDate = details['release_date'] as String? ?? '';
          final currentReleaseDate =
              (movie['releaseDate'] ?? movie['release_date']) as String? ?? '';
          final tmdbRuntime = (details['runtime'] as num?)?.toInt() ?? 0;
          final currentRuntime = (movie['runtime'] as num?)?.toInt() ?? 0;
          final tmdbPoster = details['poster_path'] as String?;
          final currentPoster =
              (movie['posterPath'] ?? movie['poster_path']) as String?;
          final tmdbBackdrop = details['backdrop_path'] as String?;
          final currentBackdrop =
              (movie['backdropPath'] ?? movie['backdrop_path']) as String?;
          final tmdbVote = (details['vote_average'] as num?)?.toDouble();

          final bool dateChanged = tmdbReleaseDate != currentReleaseDate;
          final bool runtimeChanged =
              tmdbRuntime > 0 && tmdbRuntime != currentRuntime;
          final bool posterChanged =
              tmdbPoster != null &&
              tmdbPoster.isNotEmpty &&
              (currentPoster == null || currentPoster.isEmpty);
          final bool backdropChanged =
              tmdbBackdrop != null &&
              tmdbBackdrop.isNotEmpty &&
              (currentBackdrop == null || currentBackdrop.isEmpty);

          if (dateChanged ||
              runtimeChanged ||
              posterChanged ||
              backdropChanged) {
            await movieWatchlistRepository.updateMovieDetails(
              uid: uid,
              movieId: movieId,
              releaseDate: dateChanged ? tmdbReleaseDate : null,
              runtime: runtimeChanged ? tmdbRuntime : null,
              posterPath: posterChanged ? tmdbPoster : null,
              backdropPath: backdropChanged ? tmdbBackdrop : null,
              voteAverage: tmdbVote,
            );
          }

          // Throttle requests (250ms delay) to prevent TMDb API/Cloudflare connection resets
          await Future.delayed(const Duration(milliseconds: 250));
        } catch (e) {
          hadNetworkFailure = true;
          debugPrint('Error syncing movie $movieId: $e');
        }
      }

      if (atLeastOneSuccess && !hadNetworkFailure && state is MovieWatchlistSuccess) {
        await prefs.setString(syncKey, todayStr);
      }
    } catch (e) {
      debugPrint('Error in syncUpcomingMovies: $e');
    }
  }

  Future<void> updateMovieReleaseDate({
    required String uid,
    required int movieId,
    required String releaseDate,
    int? runtime,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
  }) async {
    try {
      await movieWatchlistRepository.updateMovieDetails(
        uid: uid,
        movieId: movieId,
        releaseDate: releaseDate,
        runtime: runtime,
        posterPath: posterPath,
        backdropPath: backdropPath,
        voteAverage: voteAverage,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.updateMovieReleaseDate: $e');
    }
  }

  Future<void> addMovie({
    required String uid,
    required int movieId,
    required String title,
    required String? posterPath,
    required String? backdropPath,
    required String? releaseDate,
    required int runtime,
    required double voteAverage,
    String? genres,
    bool isWatched = false,
    bool isFavorite = false,
  }) async {
    try {
      await movieWatchlistRepository.addMovie(
        uid: uid,
        movieId: movieId,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        releaseDate: releaseDate,
        runtime: runtime,
        voteAverage: voteAverage,
        genres: genres,
        isWatched: isWatched,
        isFavorite: isFavorite,
      );
      // No scheduling here — the Firestore write lands on the watchlist stream,
      // which submits the whole list. Scheduling directly would bypass the
      // pending-notification cap that reconcile enforces.
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.addMovie: $e');
    }
  }

  Future<void> toggleWatched({
    required String uid,
    required int movieId,
    required bool isWatched,
  }) async {
    try {
      await movieWatchlistRepository.toggleWatched(
        uid: uid,
        movieId: movieId,
        isWatched: isWatched,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.toggleWatched: $e');
    }
  }

  Future<void> toggleFavorite({
    required String uid,
    required int movieId,
    required bool isFavorite,
  }) async {
    try {
      await movieWatchlistRepository.toggleFavorite(
        uid: uid,
        movieId: movieId,
        isFavorite: isFavorite,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.toggleFavorite: $e');
    }
  }

  Future<void> removeMovie({required String uid, required int movieId}) async {
    try {
      await movieWatchlistRepository.removeMovie(uid: uid, movieId: movieId);

      // Cancel scheduled notification if it exists
      await NotificationService().cancelNotification(
        NotificationMedia.movie,
        movieId,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.removeMovie: $e');
    }
  }

  void clearWatchlist() {
    _watchlistSubscription?.cancel();
    _watchlistSubscription = null;
    _backfillingMovieIds.clear();
    _failedMovieIds.clear();
    _isSyncing = false;
    _activeSyncFuture = null;
    emit(MovieWatchlistInitial());
  }

  @override
  Future<void> close() {
    _watchlistSubscription?.cancel();
    return super.close();
  }
}
