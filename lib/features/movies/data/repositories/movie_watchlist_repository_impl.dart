import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/sync/pending_writes.dart';
import '../../../../core/sync/pending_writes_firestore.dart';
import '../../../../core/sync/snapshot_data_changes.dart';
import '../../domain/repositories/movie_watchlist_repository.dart';

class MovieWatchlistRepositoryImpl implements MovieWatchlistRepository {
  final FirebaseFirestore _firestore;

  MovieWatchlistRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _moviesCollection(String uid) =>
      _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.movies);

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

      _firestoreSub = _moviesCollection(uid)
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
    dynamic originCountry,
    String? originalLanguage,
    bool isWatched = false,
    bool isFavorite = false,
  }) async {
    await _moviesCollection(uid)
        .doc(movieId.toString())
        .set({
          'id': movieId,
          'title': title,
          'posterPath': posterPath ?? '',
          'backdropPath': backdropPath ?? '',
          'releaseDate': releaseDate ?? '',
          'runtime': runtime,
          'voteAverage': voteAverage,
          'genres': genres ?? '',
          'origin_country': ?originCountry,
          'original_language': ?originalLanguage,
          'isWatched': isWatched,
          'isFavorite': isFavorite,
          'addedAt': DateTime.now().toIso8601String(),
          if (isWatched) 'watchedAt': DateTime.now().toIso8601String(),
        });
  }

  @override
  Future<void> toggleWatched({
    required String uid,
    required int movieId,
    required bool isWatched,
  }) async {
    await _moviesCollection(uid)
        .doc(movieId.toString())
        .update({
          'isWatched': isWatched,
          if (isWatched) 'watchedAt': DateTime.now().toIso8601String(),
        });
  }

  @override
  Future<void> toggleFavorite({
    required String uid,
    required int movieId,
    required bool isFavorite,
  }) async {
    await _moviesCollection(uid)
        .doc(movieId.toString())
        .update({'isFavorite': isFavorite});
  }

  @override
  Future<void> removeMovie({required String uid, required int movieId}) async {
    await _moviesCollection(uid)
        .doc(movieId.toString())
        .delete();
  }

  @override
  Future<void> updateMovieGenres({
    required String uid,
    required int movieId,
    required String genres,
  }) async {
    await updateMovieMetadata(
      uid: uid,
      movieId: movieId,
      genres: genres,
    );
  }

  @override
  Future<void> updateMovieMetadata({
    required String uid,
    required int movieId,
    String? genres,
    dynamic originCountry,
    String? originalLanguage,
  }) async {
    final updates = <String, dynamic>{};
    if (genres != null && genres.isNotEmpty) updates['genres'] = genres;
    if (originCountry != null) updates['origin_country'] = originCountry;
    if (originalLanguage != null && originalLanguage.isNotEmpty) {
      updates['original_language'] = originalLanguage;
    }
    if (updates.isNotEmpty) {
      await _moviesCollection(uid).doc(movieId.toString()).update(updates);
    }
  }

  @override
  Future<void> updateMovieDetails({
    required String uid,
    required int movieId,
    String? releaseDate,
    int? runtime,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
  }) async {
    final updates = <String, dynamic>{};
    if (releaseDate != null) updates['releaseDate'] = releaseDate;
    if (runtime != null) updates['runtime'] = runtime;
    if (posterPath != null && posterPath.isNotEmpty) {
      updates['posterPath'] = posterPath;
    }
    if (backdropPath != null && backdropPath.isNotEmpty) {
      updates['backdropPath'] = backdropPath;
    }
    if (voteAverage != null) updates['voteAverage'] = voteAverage;

    if (updates.isNotEmpty) {
      await _moviesCollection(uid).doc(movieId.toString()).update(updates);
    }
  }
}
