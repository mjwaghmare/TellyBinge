import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import 'movie_details_state.dart';

class MovieDetailsCubit extends Cubit<MovieDetailsState> {
  final TmdbClient tmdbClient;

  MovieDetailsCubit({required this.tmdbClient}) : super(MovieDetailsInitial());

  Future<void> loadMovieDetails(int movieId) async {
    emit(MovieDetailsLoading());

    // Retry up to 3 times to handle flaky network connections
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Fetch main details and credits in parallel
        final primaryResults = await Future.wait([
          tmdbClient.getMovieDetails(movieId),
          tmdbClient.getMovieCredits(movieId).catchError(
                (_) => <String, dynamic>{'cast': [], 'crew': []},
              ),
        ]);
        final movieDetails = primaryResults[0];
        final movieCredits = primaryResults[1];

        // EMIT EARLY: So the UI loads instantly with primary details!
        if (!isClosed) {
          emit(MovieDetailsSuccess(
            movieDetails: movieDetails,
            movieCredits: movieCredits,
            similarMovies: const [],
            collectionParts: const [],
            collectionSectionTitle: 'Franchise',
          ));
        }

        // Now fire off the secondary requests in parallel without blocking the UI
        final belongsToCollection = movieDetails['belongs_to_collection'];
        
        Future<Map<String, dynamic>> fetchCollection() async {
          if (belongsToCollection != null && belongsToCollection['id'] != null) {
            final collectionId = belongsToCollection['id'] as int;
            try {
              final collectionDetails = await tmdbClient.getCollectionDetails(collectionId);
              final parts = collectionDetails['parts'] as List<dynamic>? ?? [];
              final filteredParts = parts.where((item) => item['id'] != movieId).toList();
              
              filteredParts.sort((a, b) {
                final aDateStr = a['release_date'] as String? ?? '';
                final bDateStr = b['release_date'] as String? ?? '';
                if (aDateStr.isEmpty) return 1;
                if (bDateStr.isEmpty) return -1;
                try {
                  return DateTime.parse(bDateStr).compareTo(DateTime.parse(aDateStr));
                } catch (_) {
                  return 0;
                }
              });

              final collectionName = belongsToCollection['name'] as String? ?? 'Franchise';
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
          List<dynamic> similarMovies = [];
          try {
            final originalLanguage = movieDetails['original_language'] as String? ?? 'en';

            if (originalLanguage != 'en') {
              final genres = movieDetails['genres'] as List<dynamic>? ?? [];
              final genreIds = genres.map((g) => g['id'] as int).toList();

              final rawSimilar = await tmdbClient.discoverMoviesWithFilters(
                language: originalLanguage,
                genreIds: genreIds.isNotEmpty ? genreIds : null,
                sortBy: 'popularity.desc',
              );

              similarMovies = List<dynamic>.from(rawSimilar);
              similarMovies.removeWhere((m) => m['id'] == movieId);

              if (similarMovies.length < 5) {
                final fallback = await tmdbClient.getSimilarMovies(movieId);
                for (var f in fallback) {
                  if (!similarMovies.any((m) => m['id'] == f['id']) && f['id'] != movieId) {
                    similarMovies.add(f);
                  }
                }
              }
            } else {
              final rawSimilar = await tmdbClient.getSimilarMovies(movieId);
              similarMovies = List<dynamic>.from(rawSimilar);
            }

            similarMovies.sort((a, b) {
              final aDateStr = a['release_date'] as String? ?? '';
              final bDateStr = b['release_date'] as String? ?? '';
              if (aDateStr.isEmpty) return 1;
              if (bDateStr.isEmpty) return -1;
              try {
                return DateTime.parse(bDateStr).compareTo(DateTime.parse(aDateStr));
              } catch (_) {
                return 0;
              }
            });

            return similarMovies;
          } catch (e) {
            return [];
          }
        }

        // Wait for secondary requests to finish
        final secondaryResults = await Future.wait([
          fetchCollection(),
          fetchSimilar(),
        ]);

        final collectionResult = secondaryResults[0] as Map<String, dynamic>;
        final collectionParts = collectionResult['parts'] as List<dynamic>;
        final collectionSectionTitle = collectionResult['title'] as String;
        final similarMovies = secondaryResults[1] as List<dynamic>;

        if (isClosed) return;

        // Emit again with the full data
        emit(MovieDetailsSuccess(
          movieDetails: movieDetails,
          movieCredits: movieCredits,
          similarMovies: similarMovies,
          collectionParts: collectionParts,
          collectionSectionTitle: collectionSectionTitle,
        ));
        
        // Successfully loaded, break the retry loop
        return;
      } catch (e) {
        if (attempt == 3) {
          if (!isClosed) emit(MovieDetailsError(e.toString()));
        } else {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
  }
}
