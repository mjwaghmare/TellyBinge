import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/domain/models/achievement.dart';
import 'package:popverse/features/profile/presentation/cubit/achievements_cubit.dart';
import 'package:popverse/features/profile/presentation/cubit/achievements_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AchievementsCubit unlock tracking', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test(
      'initial evaluate seeds existing achievements without re-notifying',
      () async {
        final cubit = AchievementsCubit(prefs: prefs);

        // User already has 1 watched movie on initial startup
        await cubit.evaluate(
          movies: [
            {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
          ],
          shows: [],
          uid: 'user_123',
          notify: true,
        );

        expect(cubit.state, isA<AchievementsLoaded>());
        final loaded = cubit.state as AchievementsLoaded;
        final firstStep = loaded.achievements.firstWhere(
          (a) => a.id == 'first_step',
        );
        expect(firstStep.isUnlocked, true);

        // Verify seed was written to SharedPreferences
        final saved = prefs.getStringList('unlocked_achievements_user_123');
        expect(saved, isNotNull);
        expect(saved!.contains('first_step_none'), true);

        cubit.close();
      },
    );

    test(
      'newly unlocked achievements update storage and emit properly',
      () async {
        final cubit = AchievementsCubit(prefs: prefs);

        // 1. Initial state with 0 items
        await cubit.evaluate(
          movies: [],
          shows: [],
          uid: 'user_123',
          notify: true,
        );

        var saved = prefs.getStringList('unlocked_achievements_user_123');
        expect(saved, isNotNull);
        expect(saved!.contains('first_step_none'), false);

        // 2. User watches an item -> unlocks First Step
        await cubit.evaluate(
          movies: [
            {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
          ],
          shows: [],
          uid: 'user_123',
          notify: true,
        );

        saved = prefs.getStringList('unlocked_achievements_user_123');
        expect(saved!.contains('first_step_none'), true);

        // 3. User sets filter
        cubit.setFilter(AchievementCategory.volume);
        final filteredState = cubit.state as AchievementsLoaded;
        expect(filteredState.activeFilter, AchievementCategory.volume);
        expect(
          filteredState.filtered.every(
            (a) => a.category == AchievementCategory.volume,
          ),
          true,
        );

        cubit.close();
      },
    );
  });
}
