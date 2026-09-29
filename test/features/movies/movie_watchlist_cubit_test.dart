import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/errors/failures.dart';
import 'package:popverse/features/movies/domain/repositories/movie_watchlist_repository.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_state.dart';
import 'package:popverse/core/sync/pending_writes.dart';

class MockMovieWatchlistRepository implements MovieWatchlistRepository {
  final _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  bool shouldThrow = false;

  void emitWatchlist(List<Map<String, dynamic>> movies) {
    _streamController.add(movies);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) => _streamController.stream;

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) => const Stream.empty();

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

  int removeMovieCallCount = 0;
  Duration? removeMovieDelay;

  @override
  Future<void> removeMovie({required String uid, required int movieId}) async {
    removeMovieCallCount++;
    if (removeMovieDelay != null) {
      await Future.delayed(removeMovieDelay!);
    }
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
    dynamic originCountry,
    String? originalLanguage,
    bool isWatched = false,
    bool isFavorite = false,
  }) async {
    if (shouldThrow) {
      throw Exception('Add failed');
    }
  }

  @override
  Future<void> updateMovieMetadata({
    required String uid,
    required int movieId,
    String? genres,
    dynamic originCountry,
    String? originalLanguage,
  }) async {}

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

    test('stageRemoveMovie optimistically removes movie without immediate repository call', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      cubit.stageRemoveMovie(
        uid: 'user_1',
        movieId: 101,
        delay: const Duration(milliseconds: 100),
      );

      // State is optimistically empty
      expect((cubit.state as MovieWatchlistSuccess).movies, isEmpty);
      // Repository removeMovie has not been called yet
      expect(repository.removeMovieCallCount, equals(0));
    });

    test('cancelPendingMovieRemoval restores movie and prevents repository commit', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      cubit.stageRemoveMovie(
        uid: 'user_1',
        movieId: 101,
        delay: const Duration(milliseconds: 100),
      );

      expect((cubit.state as MovieWatchlistSuccess).movies, isEmpty);

      // Cancel before delay expires
      final cancelled = cubit.cancelPendingMovieRemoval(101);
      expect(cancelled, isTrue);

      // State is immediately restored
      expect((cubit.state as MovieWatchlistSuccess).movies.length, equals(1));
      expect((cubit.state as MovieWatchlistSuccess).movies.first['id'], equals(101));

      // Wait past the original delay
      await Future.delayed(const Duration(milliseconds: 150));
      // Repository was never called
      expect(repository.removeMovieCallCount, equals(0));
    });

    test('stageRemoveMovie commits to repository when delay expires without cancel', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      bool committed = false;
      cubit.stageRemoveMovie(
        uid: 'user_1',
        movieId: 101,
        delay: const Duration(milliseconds: 50),
        onCommitted: () => committed = true,
      );

      expect(repository.removeMovieCallCount, equals(0));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(committed, isTrue);
      expect(repository.removeMovieCallCount, equals(1));
      expect((cubit.state as MovieWatchlistSuccess).movies, isEmpty);
    });

    test('stageRemoveMovie returns false when state is not success or movie is missing', () async {
      // Not in success state
      expect(cubit.state, isA<MovieWatchlistInitial>());
      final result1 = cubit.stageRemoveMovie(uid: 'user_1', movieId: 101);
      expect(result1, isFalse);

      // In success state, but movie absent
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      final result2 = cubit.stageRemoveMovie(uid: 'user_1', movieId: 999);
      expect(result2, isFalse);

      // Movie present
      final result3 = cubit.stageRemoveMovie(uid: 'user_1', movieId: 101);
      expect(result3, isTrue);
    });

    test('movie entry remains filtered from watchWatchlist while removeMovie is in flight', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      repository.removeMovieDelay = const Duration(milliseconds: 100);

      cubit.stageRemoveMovie(
        uid: 'user_1',
        movieId: 101,
        delay: const Duration(milliseconds: 20),
      );

      // Wait until timer fires and removeMovie is in flight
      await Future.delayed(const Duration(milliseconds: 40));
      expect(repository.removeMovieCallCount, equals(1));

      // Repository emits a new snapshot containing the movie while delete is in flight
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      // Movie should STILL be filtered out from state because removal is in flight
      expect((cubit.state as MovieWatchlistSuccess).movies, isEmpty);

      // Now wait for removeMovie to finish
      await Future.delayed(const Duration(milliseconds: 90));
      expect((cubit.state as MovieWatchlistSuccess).movies, isEmpty);
    });

    test('flushPendingMovieRemovals awaits in-flight and newly flushed removals', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      repository.removeMovieDelay = const Duration(milliseconds: 50);

      cubit.stageRemoveMovie(
        uid: 'user_1',
        movieId: 101,
        delay: const Duration(seconds: 10),
      );

      expect(repository.removeMovieCallCount, equals(0));

      await cubit.flushPendingMovieRemovals();

      expect(repository.removeMovieCallCount, equals(1));
    });

    test('late failure in _commitRemoveMovie does not throw when cubit is already closed', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialMovies);
      await pumpEventQueue();

      repository.shouldThrow = true;
      repository.removeMovieDelay = const Duration(milliseconds: 50);

      cubit.stageRemoveMovie(
        uid: 'user_1',
        movieId: 101,
        delay: const Duration(milliseconds: 10),
      );

      // Wait for delay timer to trigger _commitRemoveMovie
      await Future.delayed(const Duration(milliseconds: 20));

      // Close cubit while commit is in flight
      await cubit.close();

      // Wait for delayed removeMovie to complete with error
      await Future.delayed(const Duration(milliseconds: 60));
    });
  });
}
