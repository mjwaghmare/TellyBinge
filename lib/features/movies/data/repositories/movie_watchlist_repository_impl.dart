import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
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

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) {
    return _moviesCollection(uid)
        .orderBy('addedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  @override
  Stream<bool> watchPendingWrites(String uid) {
    return _moviesCollection(uid)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.metadata.hasPendingWrites)
        .distinct();
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
    await _moviesCollection(uid)
        .doc(movieId.toString())
        .update({'genres': genres});
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
