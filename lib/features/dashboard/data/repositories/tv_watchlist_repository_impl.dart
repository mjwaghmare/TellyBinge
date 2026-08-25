import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/tv_show_watchlist_item.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';

class TvWatchlistRepositoryImpl implements TvWatchlistRepository {
  final FirebaseFirestore _firestore;

  TvWatchlistRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Future<void> addShow({
    required String uid,
    required int showId,
    required String name,
    required String? posterPath,
    required String? backdropPath,
    required String? firstAirDate,
    required double voteAverage,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .set({
          'id': showId,
          'name': name,
          'posterPath': posterPath ?? '',
          'backdropPath': backdropPath ?? '',
          'firstAirDate': firstAirDate ?? '',
          'voteAverage': voteAverage,
          'watchedEpisodes': [],
          'episodeWatchedDates': {},
          'addedAt': DateTime.now().toIso8601String(),
          'category': 'HAVENT_STARTED',
          'nextEpisodeCode': '',
          'nextEpisodeTitle': '',
          'targetSeason': 1,
          'targetEpisode': 1,
          'extraCount': null,
          'isPremiere': false,
          'isNewEpisode': false,
          'upcomingEpisodeCode': 'TBA',
          'upcomingEpisodeTitle': 'No upcoming episodes',
          'upcomingAirDate': null,
          'upcomingNetworkName': null,
          'hasUpcoming': false,
          'upcomingIsPremiere': false,
          'upcomingIsNew': false,
          'lastEnrichedAt': '',
        });
  }

  @override
  Future<void> stopWatchingShow({
    required String uid,
    required int showId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update({'status': 'STOPPED'});
  }

  @override
  Future<void> continueWatchingShow({
    required String uid,
    required int showId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update({'status': FieldValue.delete()});
  }

  @override
  Future<void> removeShow({required String uid, required int showId}) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .delete();
  }

  @override
  Future<void> toggleEpisodeWatched({
    required String uid,
    required int showId,
    required String episodeKey,
    required bool isWatched,
    String? showName,
    String? showPoster,
    String? episodeTitle,
  }) async {
    final batch = _firestore.batch();

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString());

    final historyRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('history')
        .doc('${showId}_$episodeKey');

    if (isWatched) {
      final now = DateTime.now().toIso8601String();
      batch.update(docRef, {
        'watchedEpisodes': FieldValue.arrayUnion([episodeKey]),
        'episodeWatchedDates.$episodeKey': now,
      });
      batch.set(historyRef, {
        'showId': showId,
        'showName': showName ?? 'Unknown Show',
        'showPoster': showPoster ?? '',
        'episodeKey': episodeKey,
        'episodeTitle': episodeTitle ?? 'Unknown Episode',
        'watchedAt': now,
      });
    } else {
      batch.update(docRef, {
        'watchedEpisodes': FieldValue.arrayRemove([episodeKey]),
        'episodeWatchedDates.$episodeKey': FieldValue.delete(),
      });
      batch.delete(historyRef);
    }

    await batch.commit();
  }

  @override
  Future<void> markMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    final Map<String, dynamic> updates = {
      'watchedEpisodes': FieldValue.arrayUnion(episodeKeys),
    };
    final now = DateTime.now().toIso8601String();
    for (var key in episodeKeys) {
      updates['episodeWatchedDates.$key'] = now;
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update(updates);
  }

  @override
  Future<void> unmarkMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    final Map<String, dynamic> updates = {
      'watchedEpisodes': FieldValue.arrayRemove(episodeKeys),
    };
    for (var key in episodeKeys) {
      updates['episodeWatchedDates.$key'] = FieldValue.delete();
    }

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update(updates);
  }

  @override
  Future<void> toggleFavorite({
    required String uid,
    required int showId,
    required bool isFavorite,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update({'isFavorite': isFavorite});
  }

  @override
  Future<void> updateShowEnrichment({
    required String uid,
    required int showId,
    required Map<String, dynamic> enrichmentData,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update(enrichmentData);
  }

  @override
  Future<TvShowWatchlistItem?> getShow({
    required String uid,
    required int showId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .get();
    return doc.exists && doc.data() != null
        ? TvShowWatchlistItem.fromMap(doc.data()!)
        : null;
  }

  @override
  Future<List<TvShowWatchlistItem>> getShows({required String uid}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .orderBy('addedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TvShowWatchlistItem.fromMap(doc.data()))
        .toList();
  }
}



