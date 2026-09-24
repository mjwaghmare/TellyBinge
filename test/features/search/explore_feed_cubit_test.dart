import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/data/explore_genres.dart';
import 'package:popverse/features/search/data/explore_sources.dart';
import 'package:popverse/features/search/presentation/cubit/explore_feed_cubit.dart';
import 'package:popverse/features/search/presentation/cubit/explore_feed_state.dart';

import 'fake_explore_tmdb_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tv = ExploreMediaType.tv;

  late FakeExploreTmdbClient client;
  late DateTime now;
  late ExploreFeedCubit cubit;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    now = DateTime(2026, 9, 23, 12);
    client = FakeExploreTmdbClient(
      respond: (call) async => switch (call.method) {
        'trendingTv' => titles(100 * call.page, 20),
        'topRatedTv' => titles(1000 + 100 * call.page, 20),
        'onTheAirTv' => titles(5000 + 100 * call.page, 20),
        'discoverTv' => titles(7000 + 100 * call.page, 20),
        _ => const [],
      },
    );
    cubit = ExploreFeedCubit(tmdbClient: client, clock: () => now);
  });

  tearDown(() => cubit.close());

  /// Lets every pending fetch resolve.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ExploreRow row(ExploreSection section) =>
      cubit.state.feedFor(tv).rowFor(section);

  test('ensureLoaded fetches each source once, rows start loading', () async {
    cubit.ensureLoaded(tv);
    expect(row(ExploreSection.trending).isLoading, isTrue);

    await settle();
    expect(client.calls.map((c) => c.method).toSet(), {
      'trendingTv',
      'topRatedTv',
      'onTheAirTv',
      'discoverTv',
    });
    expect(row(ExploreSection.trending).items, hasLength(20));
    expect(row(ExploreSection.forYou).page, 1);
    // Top 5 reads from the trending row rather than fetching again.
    expect(row(ExploreSection.topWeek), row(ExploreSection.trending));

    client.calls.clear();
    cubit.ensureLoaded(tv);
    await settle();
    expect(client.calls, isEmpty);
  });

  test('a failed or empty section ends loaded with no items', () async {
    client.respond = (call) async {
      if (call.method == 'topRatedTv') throw Exception('offline');
      return call.method == 'onTheAirTv' ? const [] : titles(1, 20);
    };
    cubit.ensureLoaded(tv);
    await settle();

    expect(row(ExploreSection.forYou).isLoading, isFalse);
    expect(row(ExploreSection.forYou).items, isEmpty);
    expect(row(ExploreSection.newlyAdded).items, isEmpty);
    expect(row(ExploreSection.trending).items, hasLength(20));
  });

  test('results from before a language change are dropped', () async {
    final slow = Completer<List<dynamic>>();
    client.respond = (call) =>
        call.language == null ? slow.future : Future.value(titles(900, 20));

    cubit.ensureLoaded(tv);
    await settle();
    cubit.setLanguage(tv, 'hi');
    await settle();
    slow.complete(titles(1, 20));
    await settle();

    expect(cubit.state.feedFor(tv).language, 'hi');
    expect(row(ExploreSection.trending).items.first['id'], 900);
  });

  test('setGenre updates feed genre and reloads with genre', () async {
    const action = GenreOption(
      label: 'Action',
      emoji: '💥',
      movieGenreId: 28,
      tvGenreId: 10759,
    );

    cubit.ensureLoaded(tv);
    await settle();

    client.calls.clear();
    cubit.setGenre(tv, action);
    expect(cubit.state.feedFor(tv).genre, action);
    expect(row(ExploreSection.trending).isLoading, isTrue);

    await settle();
    expect(client.calls, isNotEmpty);
    expect(
      client.calls.where((c) => c.genreIds != null),
      isNotEmpty,
    );

    // Setting 'All' clears genre back to null
    client.calls.clear();
    cubit.setGenre(tv, const GenreOption(label: 'All'));
    expect(cubit.state.feedFor(tv).genre, isNull);
  });

  test('fillRow tops a row up with page 2 exactly once', () async {
    cubit.ensureLoaded(tv);
    await settle();
    client.calls.clear();

    await cubit.fillRow(tv, ExploreSection.forYou);
    await cubit.fillRow(tv, ExploreSection.forYou);

    expect(client.calls, hasLength(1));
    expect(client.calls.single.page, 2);
    expect(row(ExploreSection.forYou).items, hasLength(40));
    expect(row(ExploreSection.forYou).page, 2);
  });

  test(
    'refresh bypasses the cache and keeps rows it could not refetch',
    () async {
      cubit.ensureLoaded(tv);
      await settle();
      final before = row(ExploreSection.trending).items;

      client.calls.clear();
      client.respond = (call) async => const []; // offline
      await cubit.refresh(tv);

      expect(
        client.calls,
        everyElement(predicate<ExploreCall>((c) => c.forceRefresh)),
      );
      expect(row(ExploreSection.trending).items, same(before));
    },
  );

  test('ensureLoaded refreshes a feed older than staleAfter', () async {
    cubit.ensureLoaded(tv);
    await settle();
    client.calls.clear();

    now = now.add(const Duration(hours: 1));
    cubit.ensureLoaded(tv);
    await settle();
    expect(client.calls, isEmpty);

    now = now.add(ExploreFeedCubit.staleAfter);
    cubit.ensureLoaded(tv);
    await settle();
    expect(client.calls, hasLength(4));
    expect(
      client.calls,
      everyElement(predicate<ExploreCall>((c) => c.forceRefresh)),
    );
  });

  group('appendUniqueById', () {
    test('appends only unseen ids, keeping order', () {
      final merged = appendUniqueById(titles(1, 3), [
        {'id': 2},
        {'id': 4},
        {'id': '5'},
        {'id': null},
      ]);
      expect(merged.map((e) => exploreIdOf(e['id'])), [1, 2, 3, 4, 5]);
    });

    test('returns the same list when nothing is new', () {
      final existing = titles(1, 3);
      expect(appendUniqueById(existing, titles(1, 2)), same(existing));
      expect(appendUniqueById(existing, const []), same(existing));
    });
  });
}
