import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
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

  MovieWatchlistCubit({
    required this.movieWatchlistRepository,
    this.tmdbClient,
  }) : super(MovieWatchlistInitial());

  void watchWatchlist(String uid) {
    emit(MovieWatchlistLoading());
    _watchlistSubscription?.cancel();
    
    _watchlistSubscription = movieWatchlistRepository.watchWatchlist(uid).listen(
      (movies) {
        emit(MovieWatchlistSuccess(movies));

        // Hand the whole watchlist over; the service reconciles it against
        // what's actually scheduled. Watched movies are simply absent here and
        // get cancelled as a result.
        NotificationService().submitTitles(
          NotificationMedia.movie,
          [
            for (final movie in movies)
              if ((movie['isWatched'] as bool? ?? false) == false &&
                  (movie['id'] as num?) != null &&
                  (movie['releaseDate'] as String?) != null)
                PendingNotification(
                  media: NotificationMedia.movie,
                  mediaId: (movie['id'] as num).toInt(),
                  title:
                      'Upcoming Release: ${movie['title'] as String? ?? 'Movie'}',
                  body:
                      '${movie['title'] as String? ?? 'Movie'} is releasing soon!',
                  releaseDateStr: movie['releaseDate'] as String,
                ),
          ],
        );

        // Start backfilling in the background sequentially to avoid socket rate limiting
        _backfillMissingGenres(uid, movies);
      },
      onError: (error) {
        emit(MovieWatchlistError(error.toString()));
      },
    );
  }

  // Sequential backfiller that manages lock set and delays requests
  Future<void> _backfillMissingGenres(String uid, List<Map<String, dynamic>> movies) async {
    if (tmdbClient == null) return;
    
    for (final movie in movies) {
      if (isClosed) break;
      if (!movie.containsKey('genres')) {
        final movieId = (movie['id'] as num?)?.toInt();
        if (movieId != null) {
          if (_backfillingMovieIds.contains(movieId) || _failedMovieIds.contains(movieId)) {
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

  Future<void> removeMovie({
    required String uid,
    required int movieId,
  }) async {
    try {
      await movieWatchlistRepository.removeMovie(
        uid: uid,
        movieId: movieId,
      );
      
      // Cancel scheduled notification if it exists
      await NotificationService().cancelNotification(NotificationMedia.movie, movieId);
    } catch (e) {
      debugPrint('Error in MovieWatchlistCubit.removeMovie: $e');
    }
  }

  @override
  Future<void> close() {
    _watchlistSubscription?.cancel();
    return super.close();
  }
}
