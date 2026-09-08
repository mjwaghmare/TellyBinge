import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import 'movie_details_state.dart';

class MovieDetailsCubit extends Cubit<MovieDetailsState> {
  final TmdbClient tmdbClient;
  int _loadGeneration = 0;

  MovieDetailsCubit({required this.tmdbClient}) : super(MovieDetailsInitial());

  Future<void> loadMovieDetails(int movieId) async {
    final capturedGeneration = ++_loadGeneration;
    emit(MovieDetailsLoading());

    try {
      // Fetch main details first
      final movieDetails = await tmdbClient.getMovieDetails(movieId);

      if (_loadGeneration != capturedGeneration || isClosed) return;

      // EMIT EARLY: So the UI loads instantly with primary details!
      emit(
        MovieDetailsSuccess(
          movieDetails: movieDetails,
          movieCredits: const {'cast': [], 'crew': []},
          similarMovies: const [],
          collectionParts: const [],
          collectionSectionTitle: 'Franchise',
          isCastLoading: true,
          isCollectionLoading: true,
          isSimilarLoading: true,
        ),
      );

      // Helper to get current success state
      MovieDetailsSuccess? getSuccessState() {
        if (isClosed ||
            state is! MovieDetailsSuccess ||
            _loadGeneration != capturedGeneration) {
          return null;
        }
        return state as MovieDetailsSuccess;
      }

      // Now fire off the secondary requests independently without blocking the UI
      final belongsToCollection = movieDetails['belongs_to_collection'];

      Future<Map<String, dynamic>> fetchCollection() async {
        if (belongsToCollection != null &&
            belongsToCollection is Map &&
            belongsToCollection['id'] != null) {
          final collectionId =
              (belongsToCollection['id'] as num?)?.toInt() ?? 0;
          if (collectionId > 0) {
            try {
              final collectionDetails = await tmdbClient.getCollectionDetails(
                collectionId,
              );
              final parts = collectionDetails['parts'] as List<dynamic>? ?? [];
              final filteredParts = parts
                  .where((item) => (item['id'] as num?)?.toInt() != movieId)
                  .toList();

              filteredParts.sort((a, b) {
                final aDateStr = a['release_date'] as String? ?? '';
                final bDateStr = b['release_date'] as String? ?? '';
                if (aDateStr.isEmpty) return 1;
                if (bDateStr.isEmpty) return -1;
                try {
                  return DateTime.parse(
                    bDateStr,
                  ).compareTo(DateTime.parse(aDateStr));
                } catch (_) {
                  return 0;
                }
              });

              final collectionName =
                  belongsToCollection['name'] as String? ?? 'Franchise';
              return {
                'parts': filteredParts,
                'title': 'More from $collectionName',
              };
            } catch (e) {
              return {'parts': [], 'title': 'Franchise'};
            }
          }
        }
        return {'parts': [], 'title': 'Franchise'};
      }

      Future<List<dynamic>> fetchSimilar() async {
        try {
          final rawSimilar = await tmdbClient.getSimilarMovies(movieId);
          final similarMovies = List<dynamic>.from(rawSimilar);
          similarMovies.removeWhere(
            (m) => (m['id'] as num?)?.toInt() == movieId,
          );
          return similarMovies;
        } catch (e) {
          return [];
        }
      }

      // 1. Fetch Cast
      unawaited(
        tmdbClient
            .getMovieCredits(movieId)
            .then((credits) {
              final s = getSuccessState();
              if (s != null) {
                emit(s.copyWith(movieCredits: credits, isCastLoading: false));
              }
            })
            .catchError((_) {
              final s = getSuccessState();
              if (s != null) {
                emit(
                  s.copyWith(
                    movieCredits: const {'cast': [], 'crew': []},
                    isCastLoading: false,
                  ),
                );
              }
            }),
      );

      // 2. Fetch Collection
      unawaited(
        fetchCollection()
            .then((collectionResult) {
              final s = getSuccessState();
              if (s != null) {
                final collectionParts =
                    collectionResult['parts'] as List<dynamic>? ?? [];
                final collectionSectionTitle =
                    collectionResult['title'] as String? ?? 'Franchise';
                emit(
                  s.copyWith(
                    collectionParts: collectionParts,
                    collectionSectionTitle: collectionSectionTitle,
                    isCollectionLoading: false,
                  ),
                );
              }
            })
            .catchError((_) {
              final s = getSuccessState();
              if (s != null) {
                emit(s.copyWith(isCollectionLoading: false));
              }
            }),
      );

      // 3. Fetch Similar Movies
      unawaited(
        fetchSimilar()
            .then((similarMovies) {
              final s = getSuccessState();
              if (s != null) {
                emit(
                  s.copyWith(
                    similarMovies: similarMovies,
                    isSimilarLoading: false,
                  ),
                );
              }
            })
            .catchError((_) {
              final s = getSuccessState();
              if (s != null) {
                emit(s.copyWith(isSimilarLoading: false));
              }
            }),
      );
    } catch (e) {
      if (!isClosed && _loadGeneration == capturedGeneration) {
        emit(MovieDetailsError(e.toString()));
      }
    }
  }
}
