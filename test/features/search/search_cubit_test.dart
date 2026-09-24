import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/search/presentation/cubit/search_cubit.dart';
import 'package:popverse/features/search/presentation/cubit/search_state.dart';

import 'fake_explore_tmdb_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeExploreTmdbClient client;
  late SearchCubit cubit;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    client = FakeExploreTmdbClient();
    cubit = SearchCubit(tmdbClient: client, isTv: true);
  });

  tearDown(() => cubit.close());

  SearchResultsSuccess results() => cubit.state as SearchResultsSuccess;

  test('queries shorter than three characters stay on the feed', () async {
    cubit.onSearchTextChanged('ab');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(cubit.state, isA<SearchInitial>());
    expect(client.calls, isEmpty);
  });

  test('searches its own media type after the debounce', () async {
    client.respond = (call) async => titles(1, 20);
    cubit.onSearchTextChanged('dark');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(client.calls.single.method, 'searchTv');
    expect(results().results, hasLength(20));
  });

  test('clear drops a search that is still in flight', () async {
    final slow = Completer<List<dynamic>>();
    client.respond = (call) => slow.future;

    final search = cubit.executeSearch('dark');
    cubit.clear();
    slow.complete(titles(1, 20));
    await search;

    expect(cubit.state, isA<SearchInitial>());
  });

  test('close drops a search that is still in flight without emitting after disposal', () async {
    final slow = Completer<List<dynamic>>();
    client.respond = (call) => slow.future;

    final search = cubit.executeSearch('dark');
    await cubit.close();
    slow.complete(titles(1, 20));
    await expectLater(search, completes);
  });

  group('with a language filter', () {
    setUp(() => cubit.setLanguage('hi'));

    test('scans past pages with no match instead of ending', () async {
      // Page 1 is all English, page 2 has the Hindi results.
      client.respond = (call) async =>
          call.page == 1 ? titles(1, 20) : titles(100, 20, language: 'hi');

      await cubit.executeSearch('dark');

      expect(client.calls.map((c) => c.page), [1, 2]);
      expect(results().results, hasLength(20));
      expect(results().results.first['original_language'], 'hi');
      expect(results().page, 2);
      expect(results().hasReachedMax, isFalse);
    });

    test('gives up after five pages without a match', () async {
      client.respond = (call) async => titles(call.page * 100, 20);

      await cubit.executeSearch('dark');

      expect(client.calls, hasLength(5));
      expect(results().results, isEmpty);
      expect(results().hasReachedMax, isTrue);
    });

    test('loadMore continues from the last page scanned', () async {
      client.respond = (call) async => switch (call.page) {
        2 => titles(200, 20, language: 'hi'),
        4 => titles(400, 20, language: 'hi'),
        _ => titles(call.page * 100, 20),
      };

      await cubit.executeSearch('dark');
      client.calls.clear();
      await cubit.loadMore();

      expect(client.calls.map((c) => c.page), [3, 4]);
      expect(results().results, hasLength(40));
      expect(results().page, 4);
    });

    test('an empty page means TMDB ran out', () async {
      client.respond = (call) async =>
          call.page == 1 ? titles(1, 20, language: 'hi') : const [];

      await cubit.executeSearch('dark');
      await cubit.loadMore();

      expect(results().results, hasLength(20));
      expect(results().hasReachedMax, isTrue);
    });
  });
}
