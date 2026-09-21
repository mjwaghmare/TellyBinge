import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/core/theme/app_theme.dart';
import 'package:popverse/features/person/presentation/widgets/person_details_bottom_sheet.dart';

class FakeTmdbClient extends TmdbClient {
  final Map<String, dynamic> Function(int personId)? onGetPersonDetails;

  FakeTmdbClient({this.onGetPersonDetails});

  @override
  Future<Map<String, dynamic>> getPersonDetails(int personId) async {
    if (onGetPersonDetails != null) {
      return onGetPersonDetails!(personId);
    }
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await dotenv.load(mergeWith: {});
  });

  final samplePersonData = {
    'id': 1234,
    'name': 'Cillian Murphy',
    'known_for_department': 'Acting',
    'biography': 'Acclaimed Irish film and theatre actor.',
    'birthday': '1976-05-25',
    'place_of_birth': 'Douglas, Cork, Ireland',
    'combined_credits': {
      'cast': [
        {
          'id': 101,
          'media_type': 'movie',
          'title': 'Oppenheimer',
          'character': 'J. Robert Oppenheimer',
          'vote_count': 12000,
          'popularity': 95.5,
          'vote_average': 8.9,
          'release_date': '2023-07-21',
        },
        {
          'id': 202,
          'media_type': 'tv',
          'name': 'Peaky Blinders',
          'character': 'Thomas Shelby',
          'vote_count': 9500,
          'popularity': 88.0,
          'vote_average': 8.6,
          'first_air_date': '2013-09-12',
        },
      ],
      'crew': [],
    },
  };

  Widget buildTestApp({required TmdbClient tmdbClient}) {
    return MaterialApp(
      theme: AppTheme.darkTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              PersonDetailsBottomSheet.show(
                context,
                personId: 1234,
                initialName: 'Cillian Murphy',
                tmdbClient: tmdbClient,
              );
            },
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  testWidgets('renders actor header, bio, and works list', (tester) async {
    final fakeClient = FakeTmdbClient(
      onGetPersonDetails: (id) => samplePersonData,
    );

    await tester.pumpWidget(buildTestApp(tmdbClient: fakeClient));

    // Tap to open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify actor name and department badge are rendered
    expect(find.text('Cillian Murphy'), findsOneWidget);
    expect(find.text('ACTING'), findsOneWidget);
    expect(find.text('Acclaimed Irish film and theatre actor.'), findsOneWidget);

    // Verify filter chips with counts are present
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Movies (1)'), findsOneWidget);
    expect(find.text('TV Shows (1)'), findsOneWidget);

    // Verify both works are rendered in the grid
    expect(find.text('Oppenheimer'), findsOneWidget);
    expect(find.text('Peaky Blinders'), findsOneWidget);
  });

  testWidgets('switches filter and dismisses on close button tap',
      (tester) async {
    final fakeClient = FakeTmdbClient(
      onGetPersonDetails: (id) => samplePersonData,
    );

    await tester.pumpWidget(buildTestApp(tmdbClient: fakeClient));

    // Tap to open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Filter to Movies only
    await tester.tap(find.text('Movies (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Oppenheimer'), findsOneWidget);
    expect(find.text('Peaky Blinders'), findsNothing);

    // Filter to TV Shows only
    await tester.tap(find.text('TV Shows (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Oppenheimer'), findsNothing);
    expect(find.text('Peaky Blinders'), findsOneWidget);

    // Tap close button to dismiss sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Sheet dismissed, only initial trigger remains
    expect(find.text('Cillian Murphy'), findsNothing);
    expect(find.text('Open Sheet'), findsOneWidget);
  });
}
