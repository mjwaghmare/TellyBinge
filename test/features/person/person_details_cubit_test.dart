import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/features/person/presentation/cubit/person_details_cubit.dart';
import 'package:popverse/features/person/presentation/cubit/person_details_state.dart';

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
  group('PersonDetailsCubit', () {
    final samplePersonResponse = {
      'id': 1234,
      'name': 'Cillian Murphy',
      'known_for_department': 'Acting',
      'biography': 'Irish actor known for Oppenheimer and Peaky Blinders.',
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
          },
          {
            'id': 202,
            'media_type': 'tv',
            'name': 'Peaky Blinders',
            'character': 'Thomas Shelby',
            'vote_count': 9500,
            'popularity': 88.0,
            'vote_average': 8.6,
          },
          {
            'id': 103,
            'media_type': 'movie',
            'title': 'Inception',
            'character': 'Robert Fischer',
            'vote_count': 35000,
            'popularity': 75.0,
            'vote_average': 8.4,
          },
          // Duplicate entry to test deduplication
          {
            'id': 101,
            'media_type': 'movie',
            'title': 'Oppenheimer (Re-release)',
            'character': 'J. Robert Oppenheimer',
            'vote_count': 100,
            'popularity': 10.0,
          },
        ],
        'crew': [
          {
            'id': 303,
            'media_type': 'movie',
            'title': 'Small Things Like These',
            'job': 'Director',
            'vote_count': 50,
            'popularity': 12.0,
          }
        ],
      },
    };

    test('initial state is PersonDetailsInitial', () {
      final cubit = PersonDetailsCubit(tmdbClient: FakeTmdbClient());
      expect(cubit.state, isA<PersonDetailsInitial>());
      cubit.close();
    });

    test('loads and deduplicates person works, correctly calculating counts',
        () async {
      final fakeClient = FakeTmdbClient(
        onGetPersonDetails: (id) => samplePersonResponse,
      );
      final cubit = PersonDetailsCubit(tmdbClient: fakeClient);

      await cubit.loadPersonDetails(1234);

      expect(cubit.state, isA<PersonDetailsSuccess>());
      final state = cubit.state as PersonDetailsSuccess;

      expect(state.person['name'], equals('Cillian Murphy'));
      // 3 unique cast entries + 1 unique director crew entry = 4 total
      expect(state.totalCount, equals(4));
      expect(state.movieCount, equals(3));
      expect(state.tvCount, equals(1));
      expect(state.selectedFilter, equals('all'));
      expect(state.displayedWorks.length, equals(4));

      // Oppenheimer (id 101) appears only once despite duplicate in response
      final oppenheimerEntries =
          state.allWorks.where((w) => w['id'] == 101 && w['media_type'] == 'movie');
      expect(oppenheimerEntries.length, equals(1));

      await cubit.close();
    });

    test('filters works by movie, tv, and all', () async {
      final fakeClient = FakeTmdbClient(
        onGetPersonDetails: (id) => samplePersonResponse,
      );
      final cubit = PersonDetailsCubit(tmdbClient: fakeClient);

      await cubit.loadPersonDetails(1234);

      // Filter by Movie
      cubit.setFilter('movie');
      var state = cubit.state as PersonDetailsSuccess;
      expect(state.selectedFilter, equals('movie'));
      expect(state.displayedWorks.length, equals(3));
      expect(
        state.displayedWorks.every((w) => w['media_type'] == 'movie'),
        isTrue,
      );

      // Filter by TV
      cubit.setFilter('tv');
      state = cubit.state as PersonDetailsSuccess;
      expect(state.selectedFilter, equals('tv'));
      expect(state.displayedWorks.length, equals(1));
      expect(state.displayedWorks.first['title'] ?? state.displayedWorks.first['name'],
          equals('Peaky Blinders'));

      // Filter by All
      cubit.setFilter('all');
      state = cubit.state as PersonDetailsSuccess;
      expect(state.selectedFilter, equals('all'));
      expect(state.displayedWorks.length, equals(4));

      await cubit.close();
    });

    test('emits PersonDetailsError when API returns empty or invalid data',
        () async {
      final fakeClient = FakeTmdbClient(
        onGetPersonDetails: (id) => {},
      );
      final cubit = PersonDetailsCubit(tmdbClient: fakeClient);

      await cubit.loadPersonDetails(999);

      expect(cubit.state, isA<PersonDetailsError>());
      final state = cubit.state as PersonDetailsError;
      expect(state.message, contains('Unable to load actor details'));

      await cubit.close();
    });

    test(
        'PersonDetailsSuccess equality and hashCode consistency with distinct instances',
        () {
      final stateA = PersonDetailsSuccess(
        person: {'id': 1234, 'name': 'Cillian Murphy'},
        allWorks: [
          {'id': 101, 'media_type': 'movie'},
        ],
        displayedWorks: [
          {'id': 101, 'media_type': 'movie'},
        ],
        selectedFilter: 'all',
      );

      final stateB = PersonDetailsSuccess(
        person: {'id': 1234, 'name': 'Cillian Murphy'},
        allWorks: [
          {'id': 101, 'media_type': 'movie'},
        ],
        displayedWorks: [
          {'id': 101, 'media_type': 'movie'},
        ],
        selectedFilter: 'all',
      );

      expect(stateA == stateB, isTrue);
      expect(stateA.hashCode, equals(stateB.hashCode));
    });
  });
}
