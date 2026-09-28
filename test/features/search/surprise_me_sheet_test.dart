import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/features/dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import 'package:popverse/features/dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import 'package:popverse/features/movies/presentation/cubit/movie_watchlist_state.dart';
import 'package:popverse/features/search/presentation/widgets/surprise_me_sheet.dart';

import 'fake_explore_tmdb_client.dart';

class FakeSurpriseTmdbClient extends FakeExploreTmdbClient {
  @override
  Future<Map<String, dynamic>> discoverTvShowsWithFiltersPaginated({
    int page = 1,
    String sortBy = 'first_air_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? firstAirDateGte,
    String? airDateGte,
    String? airDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    return {
      'results': titles(1, 10, language: language ?? 'en'),
      'total_pages': 5,
    };
  }

  @override
  Future<Map<String, dynamic>> discoverMoviesWithFiltersPaginated({
    int page = 1,
    String sortBy = 'primary_release_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? primaryReleaseDateGte,
    String? primaryReleaseDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    return {
      'results': titles(1, 10, language: language ?? 'en'),
      'total_pages': 5,
    };
  }

  @override
  Future<List<dynamic>> discoverTvShowsWithFilters({
    int page = 1,
    String sortBy = 'first_air_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? firstAirDateGte,
    String? airDateGte,
    String? airDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    return titles(1, 10, language: language ?? 'en');
  }

  @override
  Future<List<dynamic>> discoverMoviesWithFilters({
    int page = 1,
    String sortBy = 'primary_release_date.desc',
    List<int>? genreIds,
    String? language,
    String? originCountry,
    String? primaryReleaseDateGte,
    String? primaryReleaseDateLte,
    String? year,
    String? watchProviderId,
    int? minVoteCount,
    bool forceRefresh = false,
    bool throwOnError = false,
  }) async {
    return titles(1, 10, language: language ?? 'en');
  }
}

class FakeMovieWatchlistCubit extends Cubit<MovieWatchlistState>
    implements MovieWatchlistCubit {
  FakeMovieWatchlistCubit() : super(const MovieWatchlistSuccess([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTvShowWatchlistCubit extends Cubit<TvShowWatchlistState>
    implements TvShowWatchlistCubit {
  FakeTvShowWatchlistCubit() : super(const TvShowWatchlistSuccess([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSurpriseTmdbClient client;
  late FakeMovieWatchlistCubit movieWatchlist;
  late FakeTvShowWatchlistCubit tvWatchlist;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    client = FakeSurpriseTmdbClient();
    movieWatchlist = FakeMovieWatchlistCubit();
    tvWatchlist = FakeTvShowWatchlistCubit();
  });

  tearDown(() {
    movieWatchlist.close();
    tvWatchlist.close();
  });

  Widget createSubject({String? initialLanguage}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MovieWatchlistCubit>.value(value: movieWatchlist),
        BlocProvider<TvShowWatchlistCubit>.value(value: tvWatchlist),
      ],
      child: RepositoryProvider<TmdbClient>.value(
        value: client,
        child: MaterialApp(
          home: Scaffold(
            body: SurpriseMeSheet(initialLanguage: initialLanguage),
          ),
        ),
      ),
    );
  }

  testWidgets('renders SurpriseMeSheet with default All language button', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Surprise Me 🎲'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
  });

  testWidgets('renders SurpriseMeSheet with initial language active', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject(initialLanguage: 'ko'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Surprise Me 🎲'), findsOneWidget);
    expect(find.text('🇰🇷'), findsOneWidget);
    expect(find.text('KO'), findsOneWidget);
  });

  testWidgets('normalizes initialLanguage "all" to null unfiltered state', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject(initialLanguage: 'all'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Surprise Me 🎲'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
  });

  testWidgets('tapping language button opens bottom sheet with all options', (
    tester,
  ) async {
    await tester.pumpWidget(createSubject());
    await tester.pump(const Duration(milliseconds: 350));

    // Tap on the language filter button
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Verify title and subtitle of sheet
    expect(find.text('Filter by Language'), findsOneWidget);

    // Verify that explore languages are present
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2)); // label + nativeName
    expect(find.text('Marathi'), findsOneWidget);
    expect(find.text('Tamil'), findsOneWidget);
    expect(find.text('Telugu'), findsOneWidget);
    expect(find.text('Malayalam'), findsOneWidget);
    expect(find.text('Korean'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    expect(find.text('Spanish'), findsOneWidget);
    expect(find.text('French'), findsOneWidget);

    // Verify native names
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('मराठी'), findsOneWidget);
    expect(find.text('한국어'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);
  });

  testWidgets('selecting a language updates the filter button', (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pump(const Duration(milliseconds: 350));

    // Tap on the language filter button
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Tap on Hindi
    await tester.tap(find.text('Hindi'));
    await tester.pumpAndSettle();

    // Filter button now reflects Hindi
    expect(find.text('🇮🇳'), findsOneWidget);
    expect(find.text('HI'), findsOneWidget);
  });
}
