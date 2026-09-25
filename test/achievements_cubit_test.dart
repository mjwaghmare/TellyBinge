import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/domain/models/achievement.dart';
import 'package:popverse/features/profile/domain/repositories/achievements_repository.dart';
import 'package:popverse/features/profile/presentation/cubit/achievements_cubit.dart';
import 'package:popverse/features/profile/presentation/cubit/achievements_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAchievementsRepository implements AchievementsRepository {
  final Map<String, Map<String, DateTime>> storage = {};
  bool shouldFailSave = false;
  Duration? getDelay;

  @override
  Future<Map<String, DateTime>> getUnlockedAchievements(String uid) async {
    if (getDelay != null) {
      await Future.delayed(getDelay!);
    }
    return Map<String, DateTime>.from(storage[uid] ?? {});
  }

  @override
  Future<void> saveUnlockedAchievements(
    String uid,
    List<Achievement> achievements,
  ) async {
    if (shouldFailSave) {
      throw Exception('Firestore write failed');
    }
    final userMap = storage.putIfAbsent(uid, () => {});
    for (final a in achievements) {
      userMap['${a.id}_${a.tier.name}'] = a.unlockedAt ?? DateTime.now();
    }
  }

  @override
  Stream<Map<String, DateTime>> watchUnlockedAchievements(String uid) {
    return Stream.value(Map<String, DateTime>.from(storage[uid] ?? {}));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AchievementsCubit persistence', () {
    late SharedPreferences prefs;
    late FakeAchievementsRepository fakeRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeRepo = FakeAchievementsRepository();
    });

    test(
      'initial evaluate seeds existing achievements to repository without re-notifying',
      () async {
        final cubit = AchievementsCubit(
          achievementsRepository: fakeRepo,
          prefs: prefs,
        );

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

        // Verify seed was written to Firestore repository
        final userStorage = fakeRepo.storage['user_123'];
        expect(userStorage, isNotNull);
        expect(userStorage!.containsKey('first_step_none'), true);

        await cubit.close();
      },
    );

    test(
      'newly unlocked achievements persist to repository and populate unlockedAt',
      () async {
        final cubit = AchievementsCubit(
          achievementsRepository: fakeRepo,
          prefs: prefs,
        );

        // 1. Initial state with 0 items
        await cubit.evaluate(
          movies: [],
          shows: [],
          uid: 'user_123',
          notify: true,
        );

        var userStorage = fakeRepo.storage['user_123'];
        expect(userStorage, isNull);

        // 2. User watches an item -> unlocks First Step
        await cubit.evaluate(
          movies: [
            {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
          ],
          shows: [],
          uid: 'user_123',
          notify: true,
        );

        userStorage = fakeRepo.storage['user_123'];
        expect(userStorage, isNotNull);
        expect(userStorage!.containsKey('first_step_none'), true);

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

        await cubit.close();
      },
    );

    test(
      'migrates legacy local SharedPreferences unlocks to repository on first sign-in',
      () async {
        // Pre-populate legacy SharedPreferences
        await prefs.setStringList('unlocked_achievements_user_migrated', [
          'first_step_none',
          'movie_buff_bronze',
        ]);

        final cubit = AchievementsCubit(
          achievementsRepository: fakeRepo,
          prefs: prefs,
        );

        await cubit.evaluate(
          movies: [
            {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
          ],
          shows: [],
          uid: 'user_migrated',
          notify: false,
        );

        // Verify repository has the migrated achievements
        final userStorage = fakeRepo.storage['user_migrated'];
        expect(userStorage, isNotNull);
        expect(userStorage!.containsKey('first_step_none'), true);
        expect(userStorage.containsKey('movie_buff_bronze'), true);

        // Verify local SharedPreferences key was cleaned up after migration
        final remainingLocal = prefs.getStringList(
          'unlocked_achievements_user_migrated',
        );
        expect(remainingLocal, isNull);

        await cubit.close();
      },
    );

    test('falls back to SharedPreferences when user is guest', () async {
      final cubit = AchievementsCubit(
        achievementsRepository: fakeRepo,
        prefs: prefs,
      );

      await cubit.evaluate(
        movies: [
          {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
        ],
        shows: [],
        uid: null,
        notify: false,
      );

      final guestLocal = prefs.getStringList('unlocked_achievements_guest');
      expect(guestLocal, isNotNull);
      expect(guestLocal!.contains('first_step_none'), true);
      expect(fakeRepo.storage.isEmpty, true);

      await cubit.close();
    });

    test(
      'failed write keeps unlock pending and retries successfully on next evaluate',
      () async {
        final cubit = AchievementsCubit(
          achievementsRepository: fakeRepo,
          prefs: prefs,
        );

        // 1. Initial state (0 items)
        await cubit.evaluate(
          movies: [],
          shows: [],
          uid: 'user_retry',
          notify: false,
        );

        // 2. Simulate network failure when unlocking First Step
        fakeRepo.shouldFailSave = true;
        await cubit.evaluate(
          movies: [
            {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
          ],
          shows: [],
          uid: 'user_retry',
          notify: false,
        );

        // Write failed, so nothing in remote storage
        expect(fakeRepo.storage['user_retry'], isNull);

        // 3. Network recovers and next evaluate runs
        fakeRepo.shouldFailSave = false;
        await cubit.evaluate(
          movies: [
            {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
          ],
          shows: [],
          uid: 'user_retry',
          notify: false,
        );

        // Successfully retried and saved!
        expect(fakeRepo.storage['user_retry'], isNotNull);
        expect(
          fakeRepo.storage['user_retry']!.containsKey('first_step_none'),
          true,
        );

        await cubit.close();
      },
    );

    test('UID change during async initialization discards stale results', () async {
      final cubit = AchievementsCubit(
        achievementsRepository: fakeRepo,
        prefs: prefs,
      );

      // Pre-seed user_A with an achievement in storage
      fakeRepo.storage['user_A'] = {'first_step_none': DateTime(2026, 1, 1)};

      // user_B has no achievements
      fakeRepo.storage['user_B'] = {};

      // Introduce a delay when fetching user_A
      fakeRepo.getDelay = const Duration(milliseconds: 50);

      // Start evaluating for user_A
      final futureA = cubit.evaluate(
        movies: [
          {'isWatched': true, 'watchedAt': '2026-08-28T10:00:00.000Z'},
        ],
        shows: [],
        uid: 'user_A',
        notify: false,
      );

      // Immediately switch to user_B before user_A completes
      fakeRepo.getDelay = null;
      final futureB = cubit.evaluate(
        movies: [],
        shows: [],
        uid: 'user_B',
        notify: false,
      );

      await Future.wait([futureA, futureB]);

      // Cubit state should reflect user_B, NOT contaminated by user_A
      final loaded = cubit.state as AchievementsLoaded;
      final firstStep = loaded.achievements.firstWhere((a) => a.id == 'first_step');
      expect(firstStep.isUnlocked, false);

      await cubit.close();
    });
  });
}
