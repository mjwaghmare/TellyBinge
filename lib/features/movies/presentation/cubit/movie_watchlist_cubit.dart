import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/repositories/movie_watchlist_repository.dart';
import 'movie_watchlist_state.dart';

class MovieWatchlistCubit extends Cubit<MovieWatchlistState> {
  final MovieWatchlistRepository movieWatchlistRepository;
  final TmdbClient? tmdbClient;
  StreamSubscription? _watchlistSubscription;

  final _failureController = StreamController<Failure>.broadcast();
  Stream<Failure> get failureStream => _failureController.stream;

  // Sets to manage concurrent requests and failure retry loops
  final Set<int> _backfillingMovieIds = {};

  /// Movies TMDB has no genres, country or language for, for [_watchedUid].
  /// Retrying them on every watchlist emission used to fetch and rewrite them
  /// forever.
  final Set<int> _metadataUnavailableMovieIds = {};
  String? _watchedUid;
  final Map<int, DateTime> _failedMovieIds = {};
  final Map<int, _PendingMovieRemoval> _pendingMovieRemovals = {};
  bool _isSyncing = false;
  Future<void>? _activeSyncFuture;

  MovieWatchlistCubit({required this.movieWatchlistRepository, this.tmdbClient})
    : super(MovieWatchlistInitial());

  void watchWatchlist(String uid) {
    emit(MovieWatchlistLoading());
    _watchlistSubscription?.cancel();
    if (uid != _watchedUid) {
      _metadataUnavailableMovieIds.clear();
      _watchedUid = uid;
    }

    _watchlistSubscription = movieWatchlistRepository
        .watchWatchlist(uid)
        .listen(
          (movies) {
            final activeMovies = _pendingMovieRemovals.isEmpty
                ? movies
                : movies
                    .where((m) => !_pendingMovieRemovals
                        .containsKey((m['id'] as num?)?.toInt()))
                    .toList();
            emit(MovieWatchlistSuccess(activeMovies));

            // Hand the whole watchlist over; the service reconciles it against
            // what's actually scheduled. Watched movies are simply absent here and
            // get cancelled as a result.
            NotificationService().submitTitles(NotificationMedia.movie, [
              for (final movie in activeMovies)
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
            _backfillMissingMetadata(uid, movies);

            // Check if upcoming/recent movie release dates need their once-a-day sync
            syncUpcomingMovies(uid, movies: movies);
          },
          onError: (error) {
            emit(MovieWatchlistError(error.toString()));
          },
        );
  }

  // Sequential backfiller that manages lock set and delays requests
  Future<void> _backfillMissingMetadata(
    String uid,
    List<Map<String, dynamic>> movies,
  ) async {
    if (tmdbClient == null) return;

    // Prioritize watched movies first so user's Cinema Passport updates quickly
    final sortedMovies = List<Map<String, dynamic>>.from(movies)
      ..sort((a, b) {
        final aWatched = a['isWatched'] == true ? 1 : 0;
        final bWatched = b['isWatched'] == true ? 1 : 0;
        return bWatched.compareTo(aWatched);
      });

    final now = DateTime.now();
    for (final movie in sortedMovies) {
      if (isClosed) break;
      final genres = movie['genres'];
      final country = movie['origin_country'];
      final lang = movie['original_language'];
      final missingGenres = genres == null ||
          (genres is String && genres.isEmpty);
      final missingCountry = country == null ||
          (country is String && country.isEmpty) ||
          (country is List && country.isEmpty);
      final missingLang = lang == null ||
          (lang is String && lang.isEmpty);

      if (missingGenres || missingCountry || missingLang) {
        final movieId = (movie['id'] as num?)?.toInt();
        if (movieId != null) {
          if (_backfillingMovieIds.contains(movieId)) continue;
          if (_metadataUnavailableMovieIds.contains(movieId)) continue;
          final failedAt = _failedMovieIds[movieId];
          if (failedAt != null &&
              now.difference(failedAt).inMinutes < 5) {
            continue;
          }

          _backfillingMovieIds.add(movieId);
          try {
            await _fillMissingMetadata(uid, movieId, movie);
            _failedMovieIds.remove(movieId);
            // Throttle requests (250ms delay) to prevent TMDb API/Cloudflare connection resets
            await Future.delayed(const Duration(milliseconds: 250));
          } catch (_) {
            _failedMovieIds[movieId] = DateTime.now();
          } finally {
            _backfillingMovieIds.remove(movieId);
          }
        }
      }
    }
  }

  // Helper method rethrows error so backfill process can register the failure
  Future<void> _fillMissingMetadata(
    String uid,
    int movieId,
    Map<String, dynamic> movie,
  ) async {
    try {
      if (tmdbClient == null) return;
      final details = await tmdbClient!.getMovieDetails(movieId);
      final List<dynamic>? genresList = details['genres'] as List<dynamic>?;
      final genresStr = (genresList != null && genresList.isNotEmpty)
          ? genresList.map((g) => g['name'] as String? ?? '').join(', ')
          : '';

      final countries = details['origin_country'] as List<dynamic>?;
      final originCountry = (countries != null && countries.isNotEmpty)
          ? countries
          : (details['production_countries'] as List<dynamic>?)
              ?.map((c) => (c as Map<String, dynamic>)['iso_3166_1']?.toString())
              .whereType<String>()
              .toList();
      final originalLanguage = details['original_language'] as String?;

      final hasCountry = originCountry != null && originCountry.isNotEmpty;
      final hasLang = originalLanguage != null && originalLanguage.isNotEmpty;

      // Write only values that exist and differ from what's stored; an empty
      // result would still read as "missing" and be fetched again.
      await movieWatchlistRepository.updateMovieMetadata(
        uid: uid,
        movieId: movieId,
        genres: genresStr.isNotEmpty && movie['genres'] != genresStr ? genresStr : null,
        originCountry: hasCountry && movie['origin_country']?.toString() != originCountry.toString()
            ? originCountry
            : null,
        originalLanguage: hasLang && movie['original_language'] != originalLanguage
            ? originalLanguage
            : null,
      );

      // Recorded only after a successful write, so a failed update is retried,
      // and only if this task's user is still the one being watched.
      if (uid == _watchedUid && (genresStr.isEmpty || !hasCountry || !hasLang)) {
        _metadataUnavailableMovieIds.add(movieId);
      }
    } catch (e) {
      debugPrint('Error filling missing metadata for movie $movieId: $e');
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
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
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
    dynamic originCountry,
    String? originalLanguage,
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
        originCountry: originCountry,
        originalLanguage: originalLanguage,
        isWatched: isWatched,
        isFavorite: isFavorite,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.addMovie: $e');
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> toggleWatched({
    required String uid,
    required int movieId,
    required bool isWatched,
  }) async {
    final previousState = state;
    if (state is MovieWatchlistSuccess) {
      final currentMovies = (state as MovieWatchlistSuccess).movies;
      final updatedMovies = currentMovies.map((m) {
        if ((m['id'] as num?)?.toInt() == movieId) {
          final copy = Map<String, dynamic>.from(m);
          copy['isWatched'] = isWatched;
          if (isWatched) {
            copy['watchedAt'] = DateTime.now().toIso8601String();
          } else {
            copy.remove('watchedAt');
          }
          return copy;
        }
        return m;
      }).toList();
      emit(MovieWatchlistSuccess(updatedMovies));
    }

    try {
      await movieWatchlistRepository.toggleWatched(
        uid: uid,
        movieId: movieId,
        isWatched: isWatched,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.toggleWatched: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> toggleFavorite({
    required String uid,
    required int movieId,
    required bool isFavorite,
  }) async {
    final previousState = state;
    if (state is MovieWatchlistSuccess) {
      final currentMovies = (state as MovieWatchlistSuccess).movies;
      final updatedMovies = currentMovies.map((m) {
        if ((m['id'] as num?)?.toInt() == movieId) {
          final copy = Map<String, dynamic>.from(m);
          copy['isFavorite'] = isFavorite;
          return copy;
        }
        return m;
      }).toList();
      emit(MovieWatchlistSuccess(updatedMovies));
    }

    try {
      await movieWatchlistRepository.toggleFavorite(
        uid: uid,
        movieId: movieId,
        isFavorite: isFavorite,
      );
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.toggleFavorite: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  Future<void> removeMovie({required String uid, required int movieId}) async {
    _pendingMovieRemovals[movieId]?.timer.cancel();
    _pendingMovieRemovals.remove(movieId);

    final previousState = state;
    if (state is MovieWatchlistSuccess) {
      final currentMovies = (state as MovieWatchlistSuccess).movies;
      final updatedMovies = currentMovies
          .where((m) => (m['id'] as num?)?.toInt() != movieId)
          .toList();
      emit(MovieWatchlistSuccess(updatedMovies));
    }

    try {
      await movieWatchlistRepository.removeMovie(uid: uid, movieId: movieId);

      // Cancel scheduled notification if it exists
      await NotificationService()
          .cancelNotification(
            NotificationMedia.movie,
            movieId,
          )
          .catchError((_) {});
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.removeMovie: $e');
      if (!isClosed) {
        emit(previousState);
      }
      final failure = Failure.fromException(e);
      _failureController.add(failure);
      throw failure;
    }
  }

  bool stageRemoveMovie({
    required String uid,
    required int movieId,
    Duration delay = const Duration(seconds: 4),
    VoidCallback? onCommitted,
  }) {
    if (state is! MovieWatchlistSuccess) return false;

    final currentMovies = (state as MovieWatchlistSuccess).movies;
    final index = currentMovies.indexWhere(
      (m) => (m['id'] as num?)?.toInt() == movieId,
    );
    if (index == -1) return false;

    final movieData = currentMovies[index];

    // Cancel existing pending removal timer for this movie if any
    _pendingMovieRemovals[movieId]?.timer.cancel();

    // Optimistically remove from state
    final updatedMovies = List<Map<String, dynamic>>.from(currentMovies)..removeAt(index);
    emit(MovieWatchlistSuccess(updatedMovies));

    late final _PendingMovieRemoval pendingRecord;
    final timer = Timer(delay, () {
      pendingRecord.commitFuture = _commitRemoveMovie(
        pendingRecord,
        onCommitted: onCommitted,
      );
    });

    pendingRecord = _PendingMovieRemoval(
      uid: uid,
      movieId: movieId,
      movieData: movieData,
      originalIndex: index,
      timer: timer,
    );
    _pendingMovieRemovals[movieId] = pendingRecord;
    return true;
  }

  Future<void> _commitRemoveMovie(
    _PendingMovieRemoval pendingRecord, {
    VoidCallback? onCommitted,
  }) async {
    pendingRecord.isCommitting = true;
    try {
      await movieWatchlistRepository.removeMovie(
        uid: pendingRecord.uid,
        movieId: pendingRecord.movieId,
      );
      if (_pendingMovieRemovals[pendingRecord.movieId] == pendingRecord) {
        _pendingMovieRemovals.remove(pendingRecord.movieId);
      }
      await NotificationService()
          .cancelNotification(NotificationMedia.movie, pendingRecord.movieId)
          .catchError((_) {});
      onCommitted?.call();
    } catch (e) {
      if (_pendingMovieRemovals[pendingRecord.movieId] == pendingRecord) {
        _pendingMovieRemovals.remove(pendingRecord.movieId);
      }
      debugPrint('Error committing delayed movie removal: $e');
      if (!isClosed && state is MovieWatchlistSuccess) {
        final restored = List<Map<String, dynamic>>.from(
          (state as MovieWatchlistSuccess).movies,
        );
        final insertIdx = pendingRecord.originalIndex.clamp(0, restored.length);
        restored.insert(insertIdx, pendingRecord.movieData);
        emit(MovieWatchlistSuccess(restored));
      }
      final failure = Failure.fromException(e);
      if (!_failureController.isClosed) {
        _failureController.add(failure);
      }
    }
  }

  bool cancelPendingMovieRemoval(int movieId) {
    final pending = _pendingMovieRemovals[movieId];
    if (pending == null || pending.isCommitting) return false;

    _pendingMovieRemovals.remove(movieId);
    pending.timer.cancel();

    if (!isClosed && state is MovieWatchlistSuccess) {
      final currentMovies = List<Map<String, dynamic>>.from(
        (state as MovieWatchlistSuccess).movies,
      );
      final insertIdx = pending.originalIndex.clamp(0, currentMovies.length);
      currentMovies.insert(insertIdx, pending.movieData);
      emit(MovieWatchlistSuccess(currentMovies));
    }
    return true;
  }

  Future<void> flushPendingMovieRemovals() async {
    if (_pendingMovieRemovals.isEmpty) return;

    final pendingList = _pendingMovieRemovals.values.toList();
    for (final pending in pendingList) {
      if (!pending.isCommitting) {
        pending.timer.cancel();
        pending.commitFuture = _commitRemoveMovie(pending);
      }
    }

    await Future.wait(
      pendingList
          .map((p) => p.commitFuture)
          .whereType<Future<void>>(),
    );
  }

  void clearWatchlist() {
    unawaited(flushPendingMovieRemovals());
    _watchlistSubscription?.cancel();
    _watchlistSubscription = null;
    _backfillingMovieIds.clear();
    _failedMovieIds.clear();
    _metadataUnavailableMovieIds.clear();
    _watchedUid = null;
    _isSyncing = false;
    _activeSyncFuture = null;
    emit(MovieWatchlistInitial());
  }

  @override
  Future<void> close() async {
    await flushPendingMovieRemovals();
    await _watchlistSubscription?.cancel();
    await _failureController.close();
    return super.close();
  }
}

class _PendingMovieRemoval {
  final String uid;
  final int movieId;
  final Map<String, dynamic> movieData;
  final int originalIndex;
  final Timer timer;
  bool isCommitting = false;
  Future<void>? commitFuture;

  _PendingMovieRemoval({
    required this.uid,
    required this.movieId,
    required this.movieData,
    required this.originalIndex,
    required this.timer,
  });
}
