import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<void> removeShow({
    required String uid,
    required int showId,
  }) async {
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
      batch.update(docRef, {
        'watchedEpisodes': FieldValue.arrayUnion([episodeKey]),
      });
      batch.set(historyRef, {
        'showId': showId,
        'showName': showName ?? 'Unknown Show',
        'showPoster': showPoster ?? '',
        'episodeKey': episodeKey,
        'episodeTitle': episodeTitle ?? 'Unknown Episode',
        'watchedAt': DateTime.now().toIso8601String(),
      });
    } else {
      batch.update(docRef, {
        'watchedEpisodes': FieldValue.arrayRemove([episodeKey]),
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
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update({
      'watchedEpisodes': FieldValue.arrayUnion(episodeKeys),
    });
  }

  @override
  Future<void> unmarkMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shows')
        .doc(showId.toString())
        .update({
      'watchedEpisodes': FieldValue.arrayRemove(episodeKeys),
    });
  }
}
