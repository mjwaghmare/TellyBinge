import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/errors/failures.dart';
import 'package:popverse/features/movies/domain/repositories/movie_watchlist_repository.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_state.dart';

class MockMovieWatchlistRepository implements MovieWatchlistRepository {
  final _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  bool shouldThrow = false;

  void emitWatchlist(List<Map<String, dynamic>> movies) {
    _streamController.add(movies);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) => _streamController.stream;

  @override
  Stream<bool> watchPendingWrites(String uid) => const Stream.empty();

  @override
  Future<void> toggleWatched({
    required String uid,
    required int movieId,
    required bool isWatched,
  }) async {
    if (shouldThrow) {
      throw const SocketException('No network connection');
    }
  }

  @override
  Future<void> toggleFavorite({
    required String uid,
    required int movieId,
    required bool isFavorite,
  }) async {
    if (shouldThrow) {
      throw Exception('Write failed');
    }
  }

  @override
  Future<void> removeMovie({required String uid, required int movieId}) async {
    if (shouldThrow) {
      throw Exception('Delete failed');
    }
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
    if (shouldThrow) {
      throw Exception('Add failed');
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
  }) async {}

  @override
  Future<void> updateMovieGenres({
    required String uid,
    required int movieId,
    required String genres,
  }) async {}
}

void main() {
  late MockMovieWatchlistRepository repository;
  late MovieWatchlistCubit cubit;

  final initialMovies = [
    {
      'id': 101,
      'title': 'Inception',
      'isWatched': false,
      'isFavorite': false,
    },
  ];

  setUp(() {
    repository = MockMovieWatchlistRepository();
    cubit = MovieWatchlistCubit(movieWatchlistRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('MovieWatchlistCubit write operations', () {
    test('toggleWatched optimistically updates state when persistence succeeds', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      expect(cubit.state, isA<MovieWatchlistSuccess>());
      expect((cubit.state as MovieWatchlistSuccess).movies.first['isWatched'], isFalse);

      await cubit.toggleWatched(uid: 'user_1', movieId: 101, isWatched: true);

      expect(cubit.state, isA<MovieWatchlistSuccess>());
      expect((cubit.state as MovieWatchlistSuccess).movies.first['isWatched'], isTrue);
    });

    test('toggleWatched rolls back state, broadcasts Failure, and rethrows Failure on error', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      repository.shouldThrow = true;
      Failure? streamFailure;
      final sub = cubit.failureStream.listen((f) => streamFailure = f);

      expect(
        () => cubit.toggleWatched(uid: 'user_1', movieId: 101, isWatched: true),
        throwsA(isA<NetworkFailure>()),
      );

      await pumpEventQueue();

      // State rolled back to original
      expect((cubit.state as MovieWatchlistSuccess).movies.first['isWatched'], isFalse);
      // Failure stream received typed failure
      expect(streamFailure, isA<NetworkFailure>());

      await sub.cancel();
    });

    test('toggleFavorite rolls back state and rethrows Failure on error', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      repository.shouldThrow = true;

      expect(
        () => cubit.toggleFavorite(uid: 'user_1', movieId: 101, isFavorite: true),
        throwsA(isA<UnexpectedFailure>()),
      );

      await pumpEventQueue();
      expect((cubit.state as MovieWatchlistSuccess).movies.first['isFavorite'], isFalse);
    });

    test('removeMovie rolls back state and rethrows Failure on error', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      repository.shouldThrow = true;

      expect(
        () => cubit.removeMovie(uid: 'user_1', movieId: 101),
        throwsA(isA<UnexpectedFailure>()),
      );

      await pumpEventQueue();
      expect((cubit.state as MovieWatchlistSuccess).movies.length, equals(1));
    });
  });
}
