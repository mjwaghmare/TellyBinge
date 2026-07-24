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

        final belongsToCollection = movieDetails['belongs_to_collection'];
        final List<dynamic> collectionParts = [];
        String collectionSectionTitle = 'Franchise';

        if (belongsToCollection != null && belongsToCollection['id'] != null) {
          final collectionId = belongsToCollection['id'] as int;
          try {
            final collectionDetails = await tmdbClient.getCollectionDetails(
              collectionId,
            );
            final parts = collectionDetails['parts'] as List<dynamic>? ?? [];
            collectionParts.addAll(
              parts.where((item) => item['id'] != movieId),
            );
            final collectionName =
                belongsToCollection['name'] as String? ?? 'Franchise';
            collectionSectionTitle = 'More from $collectionName';
          } catch (e) {
            // Silently ignore collection load errors to not block the main page
          }
        }

        // Fetch similar movies intelligently based on language
        List<dynamic> similarMovies = [];
        try {
          final originalLanguage =
              movieDetails['original_language'] as String? ?? 'en';

          if (originalLanguage != 'en') {
            final genres = movieDetails['genres'] as List<dynamic>? ?? [];
            final genreIds = genres.map((g) => g['id'] as int).toList();

            final rawSimilar = await tmdbClient.discoverMoviesWithFilters(
              language: originalLanguage,
              genreIds: genreIds.isNotEmpty ? genreIds : null,
              sortBy: 'popularity.desc',
            );

            similarMovies = List<dynamic>.from(rawSimilar);

            // Remove the current movie itself if it appears in Discover
            similarMovies.removeWhere((m) => m['id'] == movieId);

            // Fallback to standard similar if discover returns too few
            if (similarMovies.length < 5) {
              final fallback = await tmdbClient.getSimilarMovies(movieId);
              for (var f in fallback) {
                if (!similarMovies.any((m) => m['id'] == f['id']) &&
                    f['id'] != movieId) {
                  similarMovies.add(f);
                }
              }
            }
          } else {
            // Standard collaborative filtering for English
            final rawSimilar = await tmdbClient.getSimilarMovies(movieId);
            similarMovies = List<dynamic>.from(rawSimilar);
          }
        } catch (e) {
          // Silently ignore similar movies errors
        }

        // Sort collection parts by release date descending (latest first)
        collectionParts.sort((a, b) {
          final aDateStr = a['release_date'] as String? ?? '';
          final bDateStr = b['release_date'] as String? ?? '';
          if (aDateStr.isEmpty) return 1;
          if (bDateStr.isEmpty) return -1;
          try {
            final aDate = DateTime.parse(aDateStr);
            final bDate = DateTime.parse(bDateStr);
            return bDate.compareTo(aDate);
          } catch (_) {
            return 0;
          }
        });

        // Sort similar movies by release date descending (latest first)
        similarMovies.sort((a, b) {
          final aDateStr = a['release_date'] as String? ?? '';
          final bDateStr = b['release_date'] as String? ?? '';
          if (aDateStr.isEmpty) return 1;
          if (bDateStr.isEmpty) return -1;
          try {
            final aDate = DateTime.parse(aDateStr);
            final bDate = DateTime.parse(bDateStr);
            return bDate.compareTo(aDate);
          } catch (_) {
            return 0;
          }
        });

        if (isClosed) return;

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
