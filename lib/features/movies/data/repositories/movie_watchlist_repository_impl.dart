import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/movie_watchlist_repository.dart';

class MovieWatchlistRepositoryImpl implements MovieWatchlistRepository {
  final FirebaseFirestore _firestore;

  MovieWatchlistRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
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
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
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
    });
  }

  @override
  Future<void> toggleWatched({
    required String uid,
    required int movieId,
    required bool isWatched,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .doc(movieId.toString())
        .update({
      'isWatched': isWatched,
    });
  }

  @override
  Future<void> toggleFavorite({
    required String uid,
    required int movieId,
    required bool isFavorite,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .doc(movieId.toString())
        .update({
      'isFavorite': isFavorite,
    });
  }

  @override
  Future<void> removeMovie({
    required String uid,
    required int movieId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .doc(movieId.toString())
        .delete();
  }

  @override
  Future<void> updateMovieGenres({
    required String uid,
    required int movieId,
    required String genres,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('movies')
        .doc(movieId.toString())
        .update({'genres': genres});
  }
}
