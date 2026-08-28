import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/achievement.dart';
import '../../domain/services/achievements_service.dart';
import 'achievements_state.dart';

class AchievementsCubit extends Cubit<AchievementsState> {
  AchievementsCubit() : super(AchievementsInitial());

  /// Evaluate all achievements from the current watchlist data.
  void evaluate({
    required List<Map<String, dynamic>> movies,
    required List<Map<String, dynamic>> shows,
  }) {
    final achievements = AchievementsService.evaluate(
      movies: movies,
      shows: shows,
    );
    emit(AchievementsLoaded(achievements: achievements));
  }

  /// Filter achievements by category (null = show all).
  void setFilter(AchievementCategory? category) {
    final current = state;
    if (current is AchievementsLoaded) {
      emit(current.copyWith(activeFilter: () => category));
    }
  }
}
