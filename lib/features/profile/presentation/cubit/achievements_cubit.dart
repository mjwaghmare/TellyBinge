import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../domain/models/achievement.dart';
import '../../domain/services/achievements_service.dart';
import '../widgets/achievement_unlock_banner.dart';
import 'achievements_state.dart';

class AchievementsCubit extends Cubit<AchievementsState> {
  final SharedPreferences? prefs;
  final GlobalKey<NavigatorState>? navigatorKey;

  AchievementsCubit({
    this.prefs,
    this.navigatorKey,
  }) : super(AchievementsInitial());

  /// Evaluates achievements using the watchlist and auth state from [context].
  static Future<void> evaluateFromContext(
    BuildContext context, {
    bool notify = true,
  }) async {
    final authState = context.read<AuthCubit>().state;
    final uid = authState is Authenticated ? authState.user.uid : null;

    final movieState = context.read<MovieWatchlistCubit>().state;
    final showState = context.read<TvShowWatchlistCubit>().state;

    final movies = movieState is MovieWatchlistSuccess
        ? movieState.movies
        : <Map<String, dynamic>>[];
    final shows = showState is TvShowWatchlistSuccess
        ? showState.shows
        : <Map<String, dynamic>>[];

    await context.read<AchievementsCubit>().evaluate(
          movies: movies,
          shows: shows,
          uid: uid,
          notify: notify,
        );
  }

  /// Evaluate all achievements from the current watchlist data and detect new unlocks.
  Future<void> evaluate({
    required List<Map<String, dynamic>> movies,
    required List<Map<String, dynamic>> shows,
    String? uid,
    bool notify = true,
  }) async {
    final achievements = AchievementsService.evaluate(
      movies: movies,
      shows: shows,
    );

    final current = state;
    final activeFilter =
        current is AchievementsLoaded ? current.activeFilter : null;
    emit(AchievementsLoaded(
      achievements: achievements,
      activeFilter: activeFilter,
    ));

    await _processNewUnlocks(achievements, uid: uid, notify: notify);
  }

  Future<void> _processNewUnlocks(
    List<Achievement> achievements, {
    String? uid,
    required bool notify,
  }) async {
    final preferences = prefs;
    if (preferences == null) return;

    final storageKey = 'unlocked_achievements_${uid ?? 'guest'}';
    final savedList = preferences.getStringList(storageKey);
    final currentlyUnlocked = achievements.where((a) => a.isUnlocked).toList();

    // First time initializing: seed existing unlocked achievements without spamming notifications
    if (savedList == null) {
      final initialKeys =
          currentlyUnlocked.map((a) => '${a.id}_${a.tier.name}').toList();
      try {
        await preferences.setStringList(storageKey, initialKeys);
      } catch (e) {
        debugPrint('AchievementsCubit: Failed to seed achievements: $e');
      }
      return;
    }

    final savedSet = savedList.toSet();
    final newlyUnlocked = <Achievement>[];

    for (final a in currentlyUnlocked) {
      final key = '${a.id}_${a.tier.name}';
      if (!savedSet.contains(key)) {
        savedSet.add(key);
        newlyUnlocked.add(a);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      bool persisted = false;
      try {
        persisted = await preferences.setStringList(storageKey, savedSet.toList());
      } catch (e) {
        debugPrint('AchievementsCubit: Failed to persist achievements: $e');
      }

      if (persisted && notify) {
        final context = navigatorKey?.currentContext;
        if (context != null && context.mounted) {
          for (final achievement in newlyUnlocked) {
            AchievementUnlockBanner.show(context, achievement);
          }
        }
      }
    }
  }

  /// Filter achievements by category (null = show all).
  void setFilter(AchievementCategory? category) {
    final current = state;
    if (current is AchievementsLoaded) {
      emit(current.copyWith(activeFilter: () => category));
    }
  }
}
