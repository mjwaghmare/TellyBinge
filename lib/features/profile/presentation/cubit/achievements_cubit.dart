import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_storage_keys.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../domain/models/achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../../domain/services/achievements_service.dart';
import '../widgets/achievement_unlock_banner.dart';
import 'achievements_state.dart';

class AchievementsCubit extends Cubit<AchievementsState> {
  final AchievementsRepository? achievementsRepository;
  final SharedPreferences? prefs;
  final GlobalKey<NavigatorState>? navigatorKey;

  /// In-memory cache of unlocked achievement keys to their unlock timestamp.
  final Map<String, DateTime> _unlockedMap = {};
  String? _loadedUid;

  AchievementsCubit({
    this.achievementsRepository,
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

    if (movieState is! MovieWatchlistSuccess ||
        showState is! TvShowWatchlistSuccess) {
      return;
    }

    final movies = movieState.movies;
    final shows = showState.shows;

    await context.read<AchievementsCubit>().evaluate(
      movies: movies,
      shows: shows,
      uid: uid,
      notify: notify,
    );
  }

  /// Evaluate all achievements from current watchlist data and detect new unlocks.
  Future<void> evaluate({
    required List<Map<String, dynamic>> movies,
    required List<Map<String, dynamic>> shows,
    String? uid,
    bool notify = true,
  }) async {
    final isInitialized = await _ensureInitialized(uid);
    if (!isInitialized || _loadedUid != uid) return;

    final evaluated = AchievementsService.evaluate(
      movies: movies,
      shows: shows,
    );

    // Hydrate unlocked achievements with persisted timestamps
    final achievements = evaluated.map((a) {
      final key = '${a.id}_${a.tier.name}';
      if (a.isUnlocked && _unlockedMap.containsKey(key)) {
        return a.copyWith(unlockedAt: _unlockedMap[key]);
      }
      return a;
    }).toList();

    if (_loadedUid != uid) return;

    final current = state;
    final activeFilter = current is AchievementsLoaded
        ? current.activeFilter
        : null;
    emit(
      AchievementsLoaded(
        achievements: achievements,
        activeFilter: activeFilter,
      ),
    );

    await _processNewUnlocks(achievements, uid: uid, notify: notify);
  }

  Future<bool> _ensureInitialized(String? uid) async {
    if (_loadedUid == uid && _unlockedMap.isNotEmpty) return true;
    _loadedUid = uid;
    _unlockedMap.clear();

    if (uid != null && achievementsRepository != null) {
      try {
        final remote = await achievementsRepository!.getUnlockedAchievements(uid);
        // Discard result if UID changed while fetching
        if (_loadedUid != uid) return false;
        _unlockedMap.addAll(remote);

        // One-time migration from local SharedPreferences if present
        if (prefs != null) {
          final storageKey = '${AppStorageKeys.unlockedAchievementsPrefix}$uid';
          final savedList = prefs!.getStringList(storageKey);
          if (savedList != null && savedList.isNotEmpty) {
            final now = DateTime.now();
            final toMigrate = <Achievement>[];
            final pendingMigrationMap = <String, DateTime>{};
            for (final key in savedList) {
              if (!_unlockedMap.containsKey(key)) {
                pendingMigrationMap[key] = now;
                final parts = key.split('_');
                final baseId = parts.length > 1
                    ? parts.sublist(0, parts.length - 1).join('_')
                    : key;
                final tierName = parts.length > 1 ? parts.last : 'none';
                final tier = AchievementTier.values.firstWhere(
                  (t) => t.name == tierName,
                  orElse: () => AchievementTier.none,
                );
                toMigrate.add(Achievement(
                  id: baseId,
                  title: baseId,
                  description: '',
                  category: AchievementCategory.volume,
                  tier: tier,
                  icon: Icons.emoji_events_rounded,
                  targetValue: 1,
                  isUnlocked: true,
                  unlockedAt: now,
                  assetPath: '',
                ));
              }
            }
            if (toMigrate.isNotEmpty) {
              await achievementsRepository!.saveUnlockedAchievements(uid, toMigrate);
              if (_loadedUid != uid) return false;
              _unlockedMap.addAll(pendingMigrationMap);
            }
            if (_loadedUid == uid) {
              await prefs!.remove(storageKey);
            }
          }
        }
      } catch (e) {
        debugPrint('AchievementsCubit: Failed to load from repository: $e');
      }
    } else if (prefs != null) {
      final storageKey = '${AppStorageKeys.unlockedAchievementsPrefix}guest';
      final savedList = prefs!.getStringList(storageKey);
      if (savedList != null) {
        final now = DateTime.now();
        for (final key in savedList) {
          _unlockedMap[key] = now;
        }
      }
    }
    return _loadedUid == uid;
  }

  Future<void> _processNewUnlocks(
    List<Achievement> achievements, {
    String? uid,
    required bool notify,
  }) async {
    final currentlyUnlocked = achievements.where((a) => a.isUnlocked).toList();
    if (currentlyUnlocked.isEmpty) return;

    final isFirstRun = _unlockedMap.isEmpty;
    final now = DateTime.now();

    if (isFirstRun) {
      final pendingSeedMap = <String, DateTime>{};
      for (final a in currentlyUnlocked) {
        final key = '${a.id}_${a.tier.name}';
        pendingSeedMap[key] = now;
      }

      bool seedSucceeded = false;
      if (uid != null && achievementsRepository != null) {
        try {
          await achievementsRepository!.saveUnlockedAchievements(uid, currentlyUnlocked);
          seedSucceeded = true;
        } catch (e) {
          debugPrint('AchievementsCubit: Failed to seed achievements in Firestore: $e');
        }
      } else if (prefs != null) {
        try {
          final storageKey = '${AppStorageKeys.unlockedAchievementsPrefix}guest';
          await prefs!.setStringList(storageKey, pendingSeedMap.keys.toList());
          seedSucceeded = true;
        } catch (e) {
          debugPrint('AchievementsCubit: Failed to seed achievements in SharedPreferences: $e');
        }
      }

      if (seedSucceeded) {
        if (_loadedUid != uid) return;
        _unlockedMap.addAll(pendingSeedMap);
      }
      return;
    }

    final newlyUnlocked = <Achievement>[];
    final pendingUnlocksMap = <String, DateTime>{};
    for (final a in currentlyUnlocked) {
      final key = '${a.id}_${a.tier.name}';
      if (!_unlockedMap.containsKey(key)) {
        pendingUnlocksMap[key] = now;
        newlyUnlocked.add(a.copyWith(unlockedAt: now));
      }
    }

    if (newlyUnlocked.isEmpty) return;

    bool saveSucceeded = false;
    if (uid != null && achievementsRepository != null) {
      try {
        await achievementsRepository!.saveUnlockedAchievements(uid, newlyUnlocked);
        saveSucceeded = true;
      } catch (e) {
        debugPrint('AchievementsCubit: Failed to persist achievements to Firestore: $e');
      }
    } else if (prefs != null) {
      try {
        final storageKey = '${AppStorageKeys.unlockedAchievementsPrefix}guest';
        final combinedKeys = {..._unlockedMap.keys, ...pendingUnlocksMap.keys}.toList();
        await prefs!.setStringList(storageKey, combinedKeys);
        saveSucceeded = true;
      } catch (e) {
        debugPrint('AchievementsCubit: Failed to persist achievements to SharedPreferences: $e');
      }
    }

    if (saveSucceeded) {
      if (_loadedUid != uid) return;
      _unlockedMap.addAll(pendingUnlocksMap);

      if (notify) {
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
