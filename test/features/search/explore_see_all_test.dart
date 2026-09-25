import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/features/dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import 'package:popverse/features/dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_state.dart';
import 'package:popverse/features/search/data/explore_sources.dart';
import 'package:popverse/features/search/presentation/pages/explore_see_all_page.dart';
import 'package:popverse/features/search/presentation/widgets/explore_poster_grid.dart';

import 'fake_explore_tmdb_client.dart';

class FakeMovieWatchlistCubit extends Cubit<MovieWatchlistState>
    implements MovieWatchlistCubit {
  FakeMovieWatchlistCubit([List<Map<String, dynamic>> items = const []])
      : super(MovieWatchlistSuccess(items));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTvShowWatchlistCubit extends Cubit<TvShowWatchlistState>
    implements TvShowWatchlistCubit {
  FakeTvShowWatchlistCubit([List<Map<String, dynamic>> items = const []])
      : super(TvShowWatchlistSuccess(items));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeExploreTmdbClient client;
  late FakeMovieWatchlistCubit movieWatchlist;
  late FakeTvShowWatchlistCubit tvWatchlist;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    client = FakeExploreTmdbClient();
    movieWatchlist = FakeMovieWatchlistCubit();
    tvWatchlist = FakeTvShowWatchlistCubit();
  });

  tearDown(() {
    movieWatchlist.close();
    tvWatchlist.close();
  });

  Widget createSubject({
    ExploreMediaType type = ExploreMediaType.movie,
    ExploreSection section = ExploreSection.trending,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MovieWatchlistCubit>.value(value: movieWatchlist),
        BlocProvider<TvShowWatchlistCubit>.value(value: tvWatchlist),
      ],
      child: RepositoryProvider<TmdbClient>.value(
        value: client,
        child: MaterialApp(
          home: ExploreSeeAllPage(
            type: type,
            section: section,
          ),
        ),
      ),
    );
  }

  testWidgets('displays error and RETRY button on page 1 failure, and retrying succeeds', (
    tester,
  ) async {
    var fail = true;
    client.respond = (call) async {
      if (fail) throw Exception('Network offline');
      return titles(1, 20);
    };

    await tester.pumpWidget(createSubject());
    // Initial pump shows skeleton
    expect(find.byType(ExplorePosterGrid), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Page 1 failed: error message and RETRY button
    expect(find.text('Failed to load explore content.'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('Title 1'), findsNothing);

    // Now network comes back online, tap RETRY
    fail = false;
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Page 1 successfully loaded
    expect(find.text('Failed to load explore content.'), findsNothing);
    expect(find.text('Title 1'), findsOneWidget);
  });

  testWidgets('later page failure preserves existing items and displays retry footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    client.respond = (call) async {
      if (call.page == 1) {
        return titles(1, 20);
      }
      throw Exception('Page 2 offline');
    };

    await tester.pumpWidget(createSubject());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Page 1 loaded
    expect(find.text('Title 1'), findsOneWidget);

    // Scroll down to trigger page 2
    final scrollable = find.byType(CustomScrollView);
    expect(scrollable, findsOneWidget);

    await tester.drag(scrollable, const Offset(0, -600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Scroll until retry footer is in viewport
    await tester.dragUntilVisible(
      find.text('Retry'),
      scrollable,
      const Offset(0, -100),
    );
    await tester.drag(scrollable, const Offset(0, -150));
    await tester.pump();

    expect(find.text('Failed to load more data.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Network recovers for page 2
    client.respond = (call) async {
      if (call.page == 1) return titles(1, 20);
      if (call.page == 2) return titles(21, 20);
      return const [];
    };

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Retry succeeded, error footer gone
    expect(find.text('Failed to load more data.'), findsNothing);
  });
}
