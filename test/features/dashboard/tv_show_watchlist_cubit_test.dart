import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/errors/failures.dart';
import 'package:popverse/features/dashboard/domain/models/tv_show_watchlist_item.dart';
import 'package:popverse/features/dashboard/domain/repositories/tv_watchlist_repository.dart';
import 'package:popverse/features/dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import 'package:popverse/features/dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import 'package:popverse/core/sync/pending_writes.dart';

class MockTvWatchlistRepository implements TvWatchlistRepository {
  final _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  bool shouldThrow = false;

  void emitWatchlist(List<Map<String, dynamic>> shows) {
    _streamController.add(shows);
  }

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) => _streamController.stream;

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) => const Stream.empty();

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
    if (shouldThrow) {
      throw const SocketException('Network error');
    }
  }

  @override
  Future<void> toggleFavorite({
    required String uid,
    required int showId,
    required bool isFavorite,
  }) async {
    if (shouldThrow) {
      throw Exception('Favorite error');
    }
  }

  @override
  Future<void> removeShow({required String uid, required int showId}) async {
    if (shouldThrow) {
      throw Exception('Remove error');
    }
  }

  int stopWatchingShowCallCount = 0;
  Duration? stopWatchingShowDelay;

  @override
  Future<void> stopWatchingShow({required String uid, required int showId}) async {
    stopWatchingShowCallCount++;
    if (stopWatchingShowDelay != null) {
      await Future.delayed(stopWatchingShowDelay!);
    }
    if (shouldThrow) {
      throw Exception('Stop error');
    }
  }

  @override
  Future<void> continueWatchingShow({required String uid, required int showId}) async {
    if (shouldThrow) {
      throw Exception('Continue error');
    }
  }

  @override
  Future<void> markMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    if (shouldThrow) {
      throw Exception('Mark error');
    }
  }

  @override
  Future<void> unmarkMultipleEpisodesWatched({
    required String uid,
    required int showId,
    required List<String> episodeKeys,
  }) async {
    if (shouldThrow) {
      throw Exception('Unmark error');
    }
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
  }) async {}

  @override
  Future<void> updateShowEnrichment({
    required String uid,
    required int showId,
    required Map<String, dynamic> enrichmentData,
  }) async {}

  @override
  Future<TvShowWatchlistItem?> getShow({
    required String uid,
    required int showId,
  }) async => null;

  @override
  Future<List<TvShowWatchlistItem>> getShows({required String uid}) async => [];
}

void main() {
  late MockTvWatchlistRepository repository;
  late TvShowWatchlistCubit cubit;

  final initialShows = [
    {
      'id': 201,
      'name': 'Severance',
      'isFavorite': false,
      'isStopped': false,
      'episodes': <String, dynamic>{},
    },
  ];

  setUp(() {
    repository = MockTvWatchlistRepository();
    cubit = TvShowWatchlistCubit(tvWatchlistRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('TvShowWatchlistCubit write operations', () {
    test('toggleEpisodeWatched optimistically updates state when persistence succeeds', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      expect(cubit.state, isA<TvShowWatchlistSuccess>());

      await cubit.toggleEpisodeWatched(
        uid: 'user_1',
        showId: 201,
        episodeKey: '1-1',
        isWatched: true,
      );

      final state = cubit.state as TvShowWatchlistSuccess;
      final show = state.shows.first;
      final watched = show['watchedEpisodes'] as List<dynamic>;
      expect(watched.contains('1-1'), isTrue);
    });

    test('toggleEpisodeWatched rolls back state, broadcasts Failure, and rethrows Failure on error', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      repository.shouldThrow = true;
      Failure? streamFailure;
      final sub = cubit.failureStream.listen((f) => streamFailure = f);

      expect(
        () => cubit.toggleEpisodeWatched(
          uid: 'user_1',
          showId: 201,
          episodeKey: '1-1',
          isWatched: true,
        ),
        throwsA(isA<NetworkFailure>()),
      );

      await pumpEventQueue();

      final state = cubit.state as TvShowWatchlistSuccess;
      final watched = state.shows.first['watchedEpisodes'] as List<dynamic>? ?? [];
      expect(watched.contains('1-1'), isFalse);
      expect(streamFailure, isA<NetworkFailure>());

      await sub.cancel();
    });

    test('toggleFavorite rolls back state and rethrows Failure on error', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      repository.shouldThrow = true;

      expect(
        () => cubit.toggleFavorite(uid: 'user_1', showId: 201, isFavorite: true),
        throwsA(isA<UnexpectedFailure>()),
      );

      await pumpEventQueue();
      expect((cubit.state as TvShowWatchlistSuccess).shows.first['isFavorite'], isFalse);
    });

    test('removeShow rolls back state and rethrows Failure on error', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      repository.shouldThrow = true;

      expect(
        () => cubit.removeShow(uid: 'user_1', showId: 201),
        throwsA(isA<UnexpectedFailure>()),
      );

      await pumpEventQueue();
      expect((cubit.state as TvShowWatchlistSuccess).shows.length, equals(1));
    });

    test('stageStopWatchingShow optimistically updates status to STOPPED without immediate repository call', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      cubit.stageStopWatchingShow(
        uid: 'user_1',
        showId: 201,
        delay: const Duration(milliseconds: 100),
      );

      // Status is optimistically STOPPED
      expect(
        (cubit.state as TvShowWatchlistSuccess).shows.first['status'],
        equals('STOPPED'),
      );
      // Repository stopWatchingShow has not been called yet
      expect(repository.stopWatchingShowCallCount, equals(0));
    });

    test('cancelPendingStopWatching restores previous status and prevents repository commit', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      cubit.stageStopWatchingShow(
        uid: 'user_1',
        showId: 201,
        delay: const Duration(milliseconds: 100),
      );

      expect(
        (cubit.state as TvShowWatchlistSuccess).shows.first['status'],
        equals('STOPPED'),
      );

      // Cancel before delay expires
      final cancelled = cubit.cancelPendingStopWatching(201);
      expect(cancelled, isTrue);

      // Status is restored (null / absent in initialShows)
      expect(
        (cubit.state as TvShowWatchlistSuccess).shows.first.containsKey('status'),
        isFalse,
      );

      // Wait past the original delay
      await Future.delayed(const Duration(milliseconds: 150));
      // Repository was never called
      expect(repository.stopWatchingShowCallCount, equals(0));
    });

    test('stageStopWatchingShow commits to repository when delay expires without cancel', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      bool committed = false;
      cubit.stageStopWatchingShow(
        uid: 'user_1',
        showId: 201,
        delay: const Duration(milliseconds: 50),
        onCommitted: () => committed = true,
      );

      expect(repository.stopWatchingShowCallCount, equals(0));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(committed, isTrue);
      expect(repository.stopWatchingShowCallCount, equals(1));
      expect(
        (cubit.state as TvShowWatchlistSuccess).shows.first['status'],
        equals('STOPPED'),
      );
    });

    test('stageStopWatchingShow returns false when state is not success or show is missing', () async {
      // Not in success state
      expect(cubit.state, isA<TvShowWatchlistInitial>());
      final result1 = cubit.stageStopWatchingShow(uid: 'user_1', showId: 201);
      expect(result1, isFalse);

      // In success state, but show absent
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      final result2 = cubit.stageStopWatchingShow(uid: 'user_1', showId: 999);
      expect(result2, isFalse);

      // Show present
      final result3 = cubit.stageStopWatchingShow(uid: 'user_1', showId: 201);
      expect(result3, isTrue);
    });

    test('delayed-stop rollback only restores previousStatus when current show status is still STOPPED', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist([
        {
          'id': 201,
          'name': 'Test Show',
          'isFavorite': false,
          'status': 'WATCHING',
        }
      ]);
      await pumpEventQueue();

      repository.shouldThrow = true;
      cubit.stageStopWatchingShow(
        uid: 'user_1',
        showId: 201,
        delay: const Duration(milliseconds: 50),
      );

      expect(
        (cubit.state as TvShowWatchlistSuccess).shows.first['status'],
        equals('STOPPED'),
      );

      // User manually resumes the show before rollback fires
      cubit.emit(TvShowWatchlistSuccess([
        {
          'id': 201,
          'name': 'Test Show',
          'isFavorite': false,
          'status': 'RESUMED',
        }
      ]));

      // Wait for delayed-stop failure rollback to execute
      await Future.delayed(const Duration(milliseconds: 100));

      // Should still be RESUMED, not overwritten by rollback
      expect(
        (cubit.state as TvShowWatchlistSuccess).shows.first['status'],
        equals('RESUMED'),
      );
    });

    test('late failure in _commitStopWatchingShow does not throw when cubit is already closed', () async {
      cubit.watchWatchlist('user_1');
      repository.emitWatchlist(initialShows);
      await pumpEventQueue();

      repository.shouldThrow = true;
      repository.stopWatchingShowDelay = const Duration(milliseconds: 50);

      cubit.stageStopWatchingShow(
        uid: 'user_1',
        showId: 201,
        delay: const Duration(milliseconds: 10),
      );

      // Wait for delay timer to trigger _commitStopWatchingShow
      await Future.delayed(const Duration(milliseconds: 20));

      // Close cubit while commit is in flight
      await cubit.close();

      // Wait for delayed stopWatchingShow to complete with error
      await Future.delayed(const Duration(milliseconds: 60));
    });
  });
}
