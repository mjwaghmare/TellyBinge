import '../../../../core/sync/pending_writes.dart';
import '../models/tv_show_watchlist_item.dart';

abstract class TvWatchlistRepository {
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid);
  Stream<PendingWrites> watchPendingWrites(String uid);
  Future<void> addShow({
    required String uid,
    required int showId,
    required String name,
    required String? posterPath,
    required String? backdropPath,
    required String? firstAirDate,
    required double voteAverage,
    dynamic originCountry,
    String? originalLanguage,
  });
  Future<void> stopWatchingShow({required String uid, required int showId});
  Future<void> continueWatchingShow({required String uid, required int showId});
  Future<void> removeShow({required String uid, required int showId});
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
  Future<void> updateShowEnrichment({
    required String uid,
    required int showId,
    required Map<String, dynamic> enrichmentData,
  });
  Future<TvShowWatchlistItem?> getShow({
    required String uid,
    required int showId,
  });
  Future<List<TvShowWatchlistItem>> getShows({required String uid});
}
