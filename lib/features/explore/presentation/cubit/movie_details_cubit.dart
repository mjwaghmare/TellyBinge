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
              belongsToCollection['id'] != null) {
            final collectionId = belongsToCollection['id'] as int;
            try {
              final collectionDetails = await tmdbClient.getCollectionDetails(
                collectionId,
              );
              final parts = collectionDetails['parts'] as List<dynamic>? ?? [];
              final filteredParts = parts
                  .where((item) => item['id'] != movieId)
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
          return {'parts': [], 'title': 'Franchise'};
        }

        Future<List<dynamic>> fetchSimilar() async {
          try {
            final rawSimilar = await tmdbClient.getSimilarMovies(movieId);
            List<dynamic> similarMovies = List<dynamic>.from(rawSimilar);
            similarMovies.removeWhere((m) => m['id'] == movieId);

            if (similarMovies.length < 5) {
              try {
                final genres = movieDetails['genres'] as List<dynamic>? ?? [];
                final genreIds = <int>[];
                for (var g in genres) {
                  if (g is Map && g['id'] != null) {
                    final rawId = g['id'];
                    if (rawId is num) {
                      genreIds.add(rawId.toInt());
                    } else if (rawId is String) {
                      final parsed = int.tryParse(rawId);
                      if (parsed != null) genreIds.add(parsed);
                    }
                  }
                }
                final fallback = await tmdbClient.discoverMoviesWithFilters(
                  genreIds: genreIds.isNotEmpty ? genreIds : null,
                  sortBy: 'popularity.desc',
                );
                for (var f in fallback) {
                  if (f is Map && f['id'] != null) {
                    final fId = f['id'];
                    if (!similarMovies.any((m) => m['id'] == fId) &&
                        fId != movieId) {
                      similarMovies.add(f);
                    }
                  }
                }
              } catch (_) {
                // Ignore fallback failure so fetched similarMovies are preserved
              }
            }

            return similarMovies;
          } catch (e) {
            return [];
          }
        }

        // 1. Fetch Cast
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
                    movieCredits: {'cast': [], 'crew': []},
                    isCastLoading: false,
                  ),
                );
              }
            });

        // 2. Fetch Collection
        fetchCollection()
            .then((collectionResult) {
              final s = getSuccessState();
              if (s != null) {
                final collectionParts =
                    collectionResult['parts'] as List<dynamic>;
                final collectionSectionTitle =
                    collectionResult['title'] as String;
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
            });

        // 3. Fetch Similar Movies
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
            });
    } catch (e) {
      if (!isClosed && _loadGeneration == capturedGeneration) {
        emit(MovieDetailsError(e.toString()));
      }
    }
  }
}
