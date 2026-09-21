import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import 'person_details_state.dart';

class PersonDetailsCubit extends Cubit<PersonDetailsState> {
  final TmdbClient tmdbClient;
  int _currentRequestId = 0;

  PersonDetailsCubit({required this.tmdbClient})
      : super(const PersonDetailsInitial());

  Future<void> loadPersonDetails(int personId) async {
    final requestId = ++_currentRequestId;
    emit(const PersonDetailsLoading());

    try {
      final personData = await tmdbClient.getPersonDetails(personId);
      if (isClosed || requestId != _currentRequestId) return;

      if (personData.isEmpty || personData['id'] == null) {
        emit(const PersonDetailsError('Unable to load actor details.'));
        return;
      }

      final combinedCredits =
          personData['combined_credits'] as Map<String, dynamic>? ?? {};
      final rawCast =
          combinedCredits['cast'] as List<dynamic>? ?? const [];
      final rawCrew =
          combinedCredits['crew'] as List<dynamic>? ?? const [];

      // Deduplicate works by media_type and id
      final Map<String, Map<String, dynamic>> deduplicated = {};

      for (final item in rawCast) {
        if (item is Map<String, dynamic>) {
          final id = item['id'];
          final mediaType = item['media_type'] as String? ?? 'movie';
          if (id != null) {
            final key = '${mediaType}_$id';
            deduplicated[key] = Map<String, dynamic>.from(item);
          }
        }
      }

      // Also include prominent directing/writing credits if not already present
      for (final item in rawCrew) {
        if (item is Map<String, dynamic>) {
          final id = item['id'];
          final mediaType = item['media_type'] as String? ?? 'movie';
          final job = item['job'] as String? ?? '';
          if (id != null && (job == 'Director' || job == 'Creator')) {
            final key = '${mediaType}_$id';
            if (!deduplicated.containsKey(key)) {
              final copy = Map<String, dynamic>.from(item);
              copy['character'] = job;
              deduplicated[key] = copy;
            }
          }
        }
      }

      final allWorks = deduplicated.values.toList();

      // Sort by popularity and vote prominence descending
      allWorks.sort((a, b) {
        final popA = (a['popularity'] as num?)?.toDouble() ?? 0.0;
        final popB = (b['popularity'] as num?)?.toDouble() ?? 0.0;
        final votesA = (a['vote_count'] as num?)?.toInt() ?? 0;
        final votesB = (b['vote_count'] as num?)?.toInt() ?? 0;

        // Weight works with a meaningful vote count higher than unreleased/fringe entries
        final scoreA = votesA > 15 ? popA : popA * 0.2;
        final scoreB = votesB > 15 ? popB : popB * 0.2;

        return scoreB.compareTo(scoreA);
      });

      emit(
        PersonDetailsSuccess(
          person: personData,
          allWorks: allWorks,
          displayedWorks: allWorks,
          selectedFilter: 'all',
        ),
      );
    } catch (e) {
      if (isClosed || requestId != _currentRequestId) return;
      emit(PersonDetailsError('Error loading person details: $e'));
    }
  }

  void setFilter(String filter) {
    final currentState = state;
    if (currentState is! PersonDetailsSuccess) return;
    if (currentState.selectedFilter == filter) return;

    final List<Map<String, dynamic>> filtered;
    if (filter == 'movie') {
      filtered = currentState.allWorks
          .where((w) => w['media_type'] == 'movie')
          .toList();
    } else if (filter == 'tv') {
      filtered = currentState.allWorks
          .where((w) => w['media_type'] == 'tv')
          .toList();
    } else {
      filtered = currentState.allWorks;
    }

    emit(
      currentState.copyWith(
        selectedFilter: filter,
        displayedWorks: filtered,
      ),
    );
  }
}
