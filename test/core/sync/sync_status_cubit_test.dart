import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/sync/pending_writes.dart';
import 'package:popverse/core/sync/sync_status_cubit.dart';
import 'package:popverse/features/custom_lists/domain/models/custom_list_item_model.dart';
import 'package:popverse/features/custom_lists/domain/models/custom_list_model.dart';
import 'package:popverse/features/custom_lists/domain/repositories/custom_lists_repository.dart';
import 'package:popverse/features/dashboard/domain/models/tv_show_watchlist_item.dart';
import 'package:popverse/features/dashboard/domain/repositories/tv_watchlist_repository.dart';
import 'package:popverse/features/movies/domain/repositories/movie_watchlist_repository.dart';

class FakeMovieWatchlistRepository implements MovieWatchlistRepository {
  final pendingController = StreamController<PendingWrites>.broadcast();

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) => pendingController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) => const Stream.empty();

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
  }) async {}

  @override
  Future<void> updateMovieMetadata({
    required String uid,
    required int movieId,
    String? genres,
    dynamic originCountry,
    String? originalLanguage,
  }) async {}

  @override
  Future<void> removeMovie({required String uid, required int movieId}) async {}

  @override
  Future<void> toggleFavorite({required String uid, required int movieId, required bool isFavorite}) async {}

  @override
  Future<void> toggleWatched({required String uid, required int movieId, required bool isWatched}) async {}

  @override
  Future<void> updateMovieDetails({required String uid, required int movieId, String? releaseDate, int? runtime, String? posterPath, String? backdropPath, double? voteAverage}) async {}

  @override
  Future<void> updateMovieGenres({required String uid, required int movieId, required String genres}) async {}

  void dispose() => pendingController.close();
}

class FakeTvWatchlistRepository implements TvWatchlistRepository {
  final pendingController = StreamController<PendingWrites>.broadcast();

  void dispose() => pendingController.close();

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) => pendingController.stream;

  @override
  Stream<List<Map<String, dynamic>>> watchWatchlist(String uid) => const Stream.empty();

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
  Future<void> continueWatchingShow({required String uid, required int showId}) async {}

  @override
  Future<TvShowWatchlistItem?> getShow({required String uid, required int showId}) async => null;

  @override
  Future<List<TvShowWatchlistItem>> getShows({required String uid}) async => [];

  @override
  Future<void> markMultipleEpisodesWatched({required String uid, required int showId, required List<String> episodeKeys}) async {}

  @override
  Future<void> removeShow({required String uid, required int showId}) async {}

  @override
  Future<void> stopWatchingShow({required String uid, required int showId}) async {}

  @override
  Future<void> toggleEpisodeWatched({required String uid, required int showId, required String episodeKey, required bool isWatched, String? showName, String? showPoster, String? episodeTitle}) async {}

  @override
  Future<void> toggleFavorite({required String uid, required int showId, required bool isFavorite}) async {}

  @override
  Future<void> unmarkMultipleEpisodesWatched({required String uid, required int showId, required List<String> episodeKeys}) async {}

  @override
  Future<void> updateShowEnrichment({required String uid, required int showId, required Map<String, dynamic> enrichmentData}) async {}
}

class FakeCustomListsRepository implements CustomListsRepository {
  final pendingController = StreamController<PendingWrites>.broadcast();

  void dispose() => pendingController.close();

  @override
  Stream<PendingWrites> watchPendingWrites(String uid) => pendingController.stream;

  @override
  Stream<List<CustomListModel>> watchCustomLists(String uid) => const Stream.empty();

  @override
  Future<String> createList({required String uid, required String name, String? description}) async => 'id';

  @override
  Future<void> deleteList({required String uid, required String listId}) async {}

  @override
  Future<void> removeItemFromList({required String uid, required String listId, required int mediaId, required String mediaType}) async {}

  @override
  Future<void> toggleItemInList({required String uid, required String listId, required CustomListItemModel item}) async {}

  @override
  Future<void> updateList({required String uid, required String listId, required String name, String? description}) async {}
}

PendingWrites offline(int count) => PendingWrites(count: count, isOnline: false);
PendingWrites online(int count) => PendingWrites(count: count);

void main() {
  late FakeMovieWatchlistRepository movieRepo;
  late FakeTvWatchlistRepository tvRepo;
  late FakeCustomListsRepository listsRepo;
  late SyncStatusCubit cubit;

  setUp(() {
    movieRepo = FakeMovieWatchlistRepository();
    tvRepo = FakeTvWatchlistRepository();
    listsRepo = FakeCustomListsRepository();
    cubit = SyncStatusCubit(
      movieWatchlistRepository: movieRepo,
      tvWatchlistRepository: tvRepo,
      customListsRepository: listsRepo,
      pendingDebounceDuration: Duration.zero,
      settleDuration: Duration.zero,
    );
  });

  tearDown(() async {
    await cubit.close();
    movieRepo.dispose();
    tvRepo.dispose();
    listsRepo.dispose();
  });

  group('SyncStatusCubit', () {
    test('initial state has hasPendingWrites false and shouldShowBanner false', () {
      expect(cubit.state.hasPendingWrites, isFalse);
      expect(cubit.state.justSynced, isFalse);
      expect(cubit.state.shouldShowBanner, isFalse);
    });

    test('emits hasPendingWrites true when any repository emits true', () async {
      cubit.startMonitoring('test_uid');

      movieRepo.pendingController.add(offline(1));
      await pumpEventQueue();

      expect(cubit.state.hasPendingWrites, isTrue);
      expect(cubit.state.shouldShowBanner, isTrue);
      expect(cubit.state.bannerText, equals('Offline · 1 change waiting'));
    });

    test('transitions to justSynced when all pending writes resolve to false', () async {
      cubit.startMonitoring('test_uid');

      movieRepo.pendingController.add(offline(1));
      await pumpEventQueue();
      expect(cubit.state.hasPendingWrites, isTrue);

      movieRepo.pendingController.add(PendingWrites.none);
      await pumpEventQueue();

      expect(cubit.state.hasPendingWrites, isFalse);
      expect(cubit.state.justSynced, isTrue);
      expect(cubit.state.shouldShowBanner, isTrue);
      expect(cubit.state.bannerText, equals('All changes synced'));
    });

    test('offline banner counts queued changes across sources', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(offline(2));
      tvRepo.pendingController.add(offline(1));
      await pumpEventQueue();

      expect(cubit.state.pendingCount, 3);
      expect(cubit.state.isSyncing, isFalse);
      expect(cubit.state.bannerText, 'Offline · 3 changes waiting');
    });

    test('reports progress once back online', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(offline(4));
      await pumpEventQueue();
      expect(cubit.state.progress, 0);

      movieRepo.pendingController.add(online(1));
      await pumpEventQueue();

      expect(cubit.state.isSyncing, isTrue);
      expect(cubit.state.bannerText, 'Syncing');
      expect(cubit.state.progress, 0.75);
    });

    test('writes queued mid-sync grow the total instead of resetting it', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(online(10));
      await pumpEventQueue();
      movieRepo.pendingController.add(online(6));
      await pumpEventQueue();
      expect(cubit.state.progress, closeTo(0.4, 1e-9));

      tvRepo.pendingController.add(online(3));
      await pumpEventQueue();

      expect(cubit.state.syncTotal, 13);
      expect(cubit.state.progress, closeTo(4 / 13, 1e-9));
    });

    test('progress starts from zero again after a completed sync', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(offline(5));
      await pumpEventQueue();
      movieRepo.pendingController.add(online(5));
      await pumpEventQueue();
      movieRepo.pendingController.add(PendingWrites.none);
      await pumpEventQueue();
      expect(cubit.state.justSynced, isTrue);
      expect(cubit.state.syncTotal, 0);

      movieRepo.pendingController.add(online(2));
      await pumpEventQueue();

      expect(cubit.state.syncTotal, 2);
      expect(cubit.state.progress, 0);
    });

    test('background writes while online never show the banner', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(online(8)); // e.g. TMDB enrichment
      await pumpEventQueue();
      expect(cubit.state.shouldShowBanner, isFalse);

      movieRepo.pendingController.add(PendingWrites.none);
      await pumpEventQueue();
      expect(cubit.state.shouldShowBanner, isFalse);
      expect(cubit.state.justSynced, isFalse);
    });

    test('progress counts only what was queued when the banner started', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(online(6)); // hidden background writes
      await pumpEventQueue();
      movieRepo.pendingController.add(offline(2));
      await pumpEventQueue();

      expect(cubit.state.shouldShowBanner, isTrue);
      expect(cubit.state.syncTotal, 2);
    });

    test('resets to default state on stopMonitoring', () async {
      cubit.startMonitoring('test_uid');
      movieRepo.pendingController.add(offline(1));
      await pumpEventQueue();
      expect(cubit.state.hasPendingWrites, isTrue);

      cubit.stopMonitoring();
      expect(cubit.state.hasPendingWrites, isFalse);
      expect(cubit.state.justSynced, isFalse);
      expect(cubit.state.shouldShowBanner, isFalse);
    });

    testWidgets('debounces transient writes so offline banner does not emit prematurely', (tester) async {
      final debouncedCubit = SyncStatusCubit(
        movieWatchlistRepository: movieRepo,
        tvWatchlistRepository: tvRepo,
        customListsRepository: listsRepo,
        pendingDebounceDuration: const Duration(seconds: 2),
        settleDuration: Duration.zero,
      );

      debouncedCubit.updatePending('movies', offline(1));
      // Immediately, hasPendingWrites should still be false
      expect(debouncedCubit.state.hasPendingWrites, isFalse);

      // Advance 500ms (write finishes well within 2s debounce)
      await tester.pump(const Duration(milliseconds: 500));
      debouncedCubit.updatePending('movies', PendingWrites.none);

      // Advance past the 2s mark
      await tester.pump(const Duration(seconds: 3));
      expect(debouncedCubit.state.hasPendingWrites, isFalse);
      expect(debouncedCubit.state.justSynced, isFalse);

      await debouncedCubit.close();
    });

    testWidgets('emits hasPendingWrites true when writes remain pending past debounce duration', (tester) async {
      final debouncedCubit = SyncStatusCubit(
        movieWatchlistRepository: movieRepo,
        tvWatchlistRepository: tvRepo,
        customListsRepository: listsRepo,
        pendingDebounceDuration: const Duration(seconds: 2),
        settleDuration: Duration.zero,
      );

      debouncedCubit.updatePending('movies', offline(1));
      expect(debouncedCubit.state.hasPendingWrites, isFalse);

      // Advance 1 second - still within debounce window
      await tester.pump(const Duration(seconds: 1));
      expect(debouncedCubit.state.hasPendingWrites, isFalse);

      // Elapse past 2s debounce window (stalled / offline write)
      await tester.pump(const Duration(seconds: 2));
      expect(debouncedCubit.state.hasPendingWrites, isTrue);
      expect(debouncedCubit.state.shouldShowBanner, isTrue);

      // Resolves now that user is reconnected
      debouncedCubit.updatePending('movies', PendingWrites.none);
      expect(debouncedCubit.state.justSynced, isTrue);

      await debouncedCubit.close();
    });
  });
}
