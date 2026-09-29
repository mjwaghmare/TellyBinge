import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/sync/pending_writes.dart';
import '../../../../core/sync/pending_writes_firestore.dart';
import '../../../../core/sync/snapshot_data_changes.dart';
import '../../domain/models/tv_show_watchlist_item.dart';
import '../../domain/repositories/tv_watchlist_repository.dart';

class TvWatchlistRepositoryImpl implements TvWatchlistRepository {
  final FirebaseFirestore _firestore;

  TvWatchlistRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _showsCollection(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.shows);

  CollectionReference<Map<String, dynamic>> _historyCollection(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.history);

  /// Shared Firestore listener and controller that replays the latest snapshot
  /// to new listeners without canceling the underlying Firestore subscription.
  StreamController<QuerySnapshot<Map<String, dynamic>>>? _snapshotController;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  QuerySnapshot<Map<String, dynamic>>? _latestSnapshot;
  String? _snapshotUid;
  final Set<StreamController<QuerySnapshot<Map<String, dynamic>>>> _activeWrappers = {};

  void _cleanupSharedListener() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    if (_snapshotController != null && !_snapshotController!.isClosed) {
      _snapshotController!.close();
    }
    _snapshotController = null;
    _latestSnapshot = null;
    _snapshotUid = null;
  }

  void _ensureSharedListener(String uid) {
    if (_snapshotUid != uid) {
      _cleanupSharedListener();
      _snapshotUid = uid;
      for (final wrapper in _activeWrappers.toList()) {
        if (!wrapper.isClosed) {
          wrapper.close();
        }
      }
      _activeWrappers.clear();
    }

    if (_snapshotController == null || _snapshotController!.isClosed) {
      _snapshotController =
          StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();

      _firestoreSub = _showsCollection(uid)
          .orderBy('addedAt', descending: true)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              _latestSnapshot = snapshot;
              if (_snapshotController != null && !_snapshotController!.isClosed) {
                _snapshotController!.add(snapshot);
              }
            },
            onError: (error, stack) {
              if (_snapshotController != null && !_snapshotController!.isClosed) {
                _snapshotController!.addError(error, stack);
              }
            },
            onDone: () {
              final controller = _snapshotController;
              _cleanupSharedListener();
              if (controller != null && !controller.isClosed) {
                controller.close();
              }
            },
          );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _snapshotStream(String uid) {
    late final StreamController<QuerySnapshot<Map<String, dynamic>>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? broadcastSub;

    controller = StreamController<QuerySnapshot<Map<String, dynamic>>>(
      onListen: () {
        if (_snapshotUid != null && _snapshotUid != uid) {
          if (!controller.isClosed) {
            controller.close();
          }
          return;
        }

        _ensureSharedListener(uid);
        _activeWrappers.add(controller);

        QuerySnapshot<Map<String, dynamic>>? lastEmitted;
        final currentLatest = _latestSnapshot;
        if (currentLatest != null) {
          lastEmitted = currentLatest;
          controller.add(currentLatest);
        }
        broadcastSub = _snapshotController?.stream.listen(
          (snapshot) {
            if (snapshot != lastEmitted) {
              lastEmitted = snapshot;
              controller.add(snapshot);
            }
          },
          onError: controller.addError,
          onDone: () {
            _activeWrappers.remove(controller);
            if (!controller.isClosed) {
              controller.close();
            }
          },
        );
      },
      onCancel: () {
        broadcastSub?.cancel();
        _activeWrappers.remove(controller);
        if (!controller.isClosed) {
          controller.close();
        }
        if (_activeWrappers.isEmpty) {
          _cleanupSharedListener();
        }
      },
    );

    return controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) {
    return _snapshotStream(uid).transform(dataChangesOnly());
  }

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) {
    return _snapshotStream(uid).map(pendingWritesFromSnapshot).distinct();
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
    dynamic originCountry,
    String? originalLanguage,
  }) async {
    await _showsCollection(uid)
        .doc(showId.toString())
        .set({
          'id': showId,
          'name': name,
          'posterPath': posterPath ?? '',
          'backdropPath': backdropPath ?? '',
          'firstAirDate': firstAirDate ?? '',
          'voteAverage': voteAverage,
          'origin_country': ?originCountry,
          'original_language': ?originalLanguage,
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
    await _showsCollection(uid)
        .doc(showId.toString())
        .update({'status': 'STOPPED'});
  }

  @override
  Future<void> continueWatchingShow({
    required String uid,
    required int showId,
  }) async {
    await _showsCollection(uid)
        .doc(showId.toString())
        .update({'status': FieldValue.delete()});
  }

  @override
  Future<void> removeShow({required String uid, required int showId}) async {
    await _showsCollection(uid)
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

    final docRef = _showsCollection(uid).doc(showId.toString());
    final historyRef = _historyCollection(uid).doc('${showId}_$episodeKey');

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

    await _showsCollection(uid).doc(showId.toString()).update(updates);
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

    await _showsCollection(uid).doc(showId.toString()).update(updates);
  }

  @override
  Future<void> toggleFavorite({
    required String uid,
    required int showId,
    required bool isFavorite,
  }) async {
    await _showsCollection(uid)
        .doc(showId.toString())
        .update({'isFavorite': isFavorite});
  }

  @override
  Future<void> updateShowEnrichment({
    required String uid,
    required int showId,
    required Map<String, dynamic> enrichmentData,
  }) async {
    await _showsCollection(uid)
        .doc(showId.toString())
        .update(enrichmentData);
  }

  @override
  Future<TvShowWatchlistItem?> getShow({
    required String uid,
    required int showId,
  }) async {
    final doc = await _showsCollection(uid).doc(showId.toString()).get();
    return doc.exists && doc.data() != null
        ? TvShowWatchlistItem.fromMap(doc.data()!)
        : null;
  }

  @override
  Future<List<TvShowWatchlistItem>> getShows({required String uid}) async {
    final snapshot = await _showsCollection(uid)
        .orderBy('addedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TvShowWatchlistItem.fromMap(doc.data()))
        .toList();
  }
}
