abstract class TvWatchlistRepository {
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid);
  Future<void> addShow({
    required String uid,
    required int showId,
    required String name,
    required String? posterPath,
    required String? backdropPath,
    required String? firstAirDate,
    required double voteAverage,
  });
  Future<void> stopWatchingShow({
    required String uid,
    required int showId,
  });
  Future<void> continueWatchingShow({
    required String uid,
    required int showId,
  });
  Future<void> removeShow({
    required String uid,
    required int showId,
  });
  Future<void> toggleEpisodeWatched({
    required String uid,
    required int showId,
    required String episodeKey,
    required bool isWatched,
    String? showName,
    String? showPoster,
    String? episodeTitle,
  });
  Future<void> markMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  });
  Future<void> unmarkMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  });
  Future<void> toggleFavorite({
    required String uid,
    required int showId,
    required bool isFavorite,
  });
}
