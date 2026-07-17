abstract class MovieWatchlistRepository {
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid);
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
  });
  Future<void> toggleWatched({
    required String uid,
    required int movieId,
    required bool isWatched,
  });
  Future<void> toggleFavorite({
    required String uid,
    required int movieId,
    required bool isFavorite,
  });
  Future<void> removeMovie({
    required String uid,
    required int movieId,
  });
  Future<void> updateMovieGenres({
    required String uid,
    required int movieId,
    required String genres,
  });
}
