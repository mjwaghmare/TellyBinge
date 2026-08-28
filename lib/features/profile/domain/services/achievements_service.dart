import 'package:flutter/material.dart';
import '../models/achievement.dart';

/// Evaluates all achievements from the user's movie and TV show data.
///
/// All computation is synchronous and derived directly from the in-memory
/// watchlist states — no additional network or Firestore calls required.
class AchievementsService {
  AchievementsService._();

  /// Evaluate every achievement against the provided user data.
  static List<Achievement> evaluate({
    required List<Map<String, dynamic>> movies,
    required List<Map<String, dynamic>> shows,
  }) {
    // Pre-compute shared stats.
    final watchedMovies =
        movies.where((m) => m['isWatched'] == true).toList();
    final watchedMoviesCount = watchedMovies.length;
    final totalEpisodes = shows.fold<int>(
      0,
      (sum, s) =>
          sum + (List<dynamic>.from(s['watchedEpisodes'] ?? [])).length,
    );
    final totalMovieMinutes = watchedMovies.fold<int>(
      0,
      (sum, m) => sum + ((m['runtime'] as num?)?.toInt() ?? 0),
    );
    // Rough average of 42 min per TV episode.
    final totalShowMinutes = totalEpisodes * 42;
    final totalMinutes = totalMovieMinutes + totalShowMinutes;
    final totalDays = totalMinutes / (24 * 60);

    final watchedShows = shows.where((s) {
      final eps = s['watchedEpisodes'];
      return eps is List && eps.isNotEmpty;
    }).toList();

    // Genre helpers.
    final movieGenres = _extractGenreCountsFromMovies(watchedMovies);
    final showGenreNames = _extractGenreNamesFromShows(watchedShows);
    final uniqueGenreCount = _countUniqueGenres(watchedMovies, watchedShows);

    // History-based helpers.
    final hasNightOwl = _hasTimeRange(watchedMovies, watchedShows, 1, 0, 4, 30);
    final hasEarlyBird = _hasTimeRange(watchedMovies, watchedShows, 5, 0, 7, 30);
    final marathonDayEpisodes = _maxEpisodesInSingleDay(shows);
    final weekendStats = _weekendStats(watchedMovies, watchedShows);
    final completedSeriesCount = _completedSeriesCount(shows);
    final streakDays = _longestStreak(watchedMovies, watchedShows);
    final comebackDays = _longestInactivityGap(watchedMovies, watchedShows);
    final hasClassicMovie = _hasClassicMovie(watchedMovies);
    final doubleFeatureDay = _doubleFeatureDayCount(watchedMovies);

    return [
      // ── 1. WATCH VOLUME ──
      _multi(
        baseId: 'first_step',
        title: 'First Step',
        description: 'Log your very first Movie or TV Episode',
        category: AchievementCategory.volume,
        icon: Icons.rocket_launch_rounded,
        assetPath: 'assets/awards/first_step.jpg',
        current: watchedMoviesCount + totalEpisodes,
        tiers: const {AchievementTier.none: 1},
      ),
      _multi(
        baseId: 'movie_buff',
        title: 'Movie Buff',
        description: 'Watch movies to earn higher tiers',
        category: AchievementCategory.volume,
        icon: Icons.movie_creation_rounded,
        assetPath: 'assets/awards/movie_buff.jpg',
        current: watchedMoviesCount,
        tiers: const {
          AchievementTier.bronze: 25,
          AchievementTier.silver: 100,
          AchievementTier.gold: 250,
          AchievementTier.diamond: 500,
        },
      ),
      _multi(
        baseId: 'binge_master',
        title: 'Binge Master',
        description: 'Watch TV episodes to climb tiers',
        category: AchievementCategory.volume,
        icon: Icons.live_tv_rounded,
        assetPath: 'assets/awards/binge_master.jpg',
        current: totalEpisodes,
        tiers: const {
          AchievementTier.bronze: 50,
          AchievementTier.silver: 250,
          AchievementTier.gold: 1000,
          AchievementTier.diamond: 2500,
        },
      ),
      _multi(
        baseId: 'time_lord',
        title: 'Time Lord',
        description: 'Accumulate total watch time',
        category: AchievementCategory.volume,
        icon: Icons.schedule_rounded,
        assetPath: 'assets/awards/time_lord.jpg',
        current: totalDays.floor(),
        tiers: const {
          AchievementTier.bronze: 1, // 1 day
          AchievementTier.silver: 7,
          AchievementTier.gold: 30,
          AchievementTier.diamond: 100,
        },
      ),

      // ── 2. BINGEING & VIEWING HABITS ──
      _multi(
        baseId: 'series_finisher',
        title: 'Series Finisher',
        description: 'Complete all seasons of a TV series',
        category: AchievementCategory.habits,
        icon: Icons.check_circle_rounded,
        assetPath: 'assets/awards/series_finisher.jpg',
        current: completedSeriesCount,
        tiers: const {
          AchievementTier.bronze: 1,
          AchievementTier.silver: 5,
          AchievementTier.gold: 20,
          AchievementTier.diamond: 50,
        },
      ),
      Achievement(
        id: 'weekend_warrior',
        title: 'Weekend Warrior',
        description: 'Watch 10+ episodes or 3+ movies in a single weekend',
        category: AchievementCategory.habits,
        icon: Icons.weekend_rounded,
        assetPath: 'assets/awards/weekend_warrior.jpg',
        currentValue: weekendStats,
        targetValue: 1,
        isUnlocked: weekendStats >= 1,
      ),
      Achievement(
        id: 'marathon_runner',
        title: 'Marathon Runner',
        description: 'Log 5+ episodes of the same show in a single day',
        category: AchievementCategory.habits,
        icon: Icons.directions_run_rounded,
        assetPath: 'assets/awards/marathon_runner.jpg',
        currentValue: marathonDayEpisodes,
        targetValue: 5,
        isUnlocked: marathonDayEpisodes >= 5,
      ),
      Achievement(
        id: 'night_owl',
        title: 'Night Owl',
        description: 'Log an item between 1:00 AM and 4:30 AM',
        category: AchievementCategory.habits,
        icon: Icons.nightlight_rounded,
        assetPath: 'assets/awards/night_owl.jpg',
        currentValue: hasNightOwl ? 1 : 0,
        targetValue: 1,
        isUnlocked: hasNightOwl,
      ),
      Achievement(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Log an item before 7:30 AM',
        category: AchievementCategory.habits,
        icon: Icons.wb_sunny_rounded,
        assetPath: 'assets/awards/early_bird.jpg',
        currentValue: hasEarlyBird ? 1 : 0,
        targetValue: 1,
        isUnlocked: hasEarlyBird,
      ),

      // ── 3. GENRE MASTERY ──
      _multi(
        baseId: 'scream_king',
        title: 'Scream King',
        description: 'Watch Horror titles',
        category: AchievementCategory.genres,
        icon: Icons.whatshot_rounded,
        assetPath: 'assets/awards/scream_king.jpg',
        current: (movieGenres['Horror'] ?? 0) + (showGenreNames['Horror'] ?? 0),
        tiers: const {
          AchievementTier.bronze: 10,
          AchievementTier.silver: 25,
          AchievementTier.gold: 50,
        },
      ),
      _multi(
        baseId: 'space_explorer',
        title: 'Space Explorer',
        description: 'Watch Sci-Fi titles',
        category: AchievementCategory.genres,
        icon: Icons.rocket_rounded,
        assetPath: 'assets/awards/space_explorer.jpg',
        current: (movieGenres['Science Fiction'] ?? 0) +
            (showGenreNames['Sci-Fi & Fantasy'] ?? 0),
        tiers: const {
          AchievementTier.bronze: 10,
          AchievementTier.silver: 25,
          AchievementTier.gold: 50,
        },
      ),
      _multi(
        baseId: 'otaku',
        title: 'Otaku',
        description: 'Watch Animation / Anime titles',
        category: AchievementCategory.genres,
        icon: Icons.animation_rounded,
        assetPath: 'assets/awards/otaku.jpg',
        current: (movieGenres['Animation'] ?? 0) +
            (showGenreNames['Animation'] ?? 0),
        tiers: const {
          AchievementTier.bronze: 20,
          AchievementTier.silver: 100,
          AchievementTier.gold: 300,
        },
      ),
      _multi(
        baseId: 'true_detective',
        title: 'True Detective',
        description: 'Watch Crime & Mystery titles',
        category: AchievementCategory.genres,
        icon: Icons.search_rounded,
        assetPath: 'assets/awards/true_detective.jpg',
        current: (movieGenres['Crime'] ?? 0) +
            (movieGenres['Mystery'] ?? 0) +
            (showGenreNames['Crime'] ?? 0) +
            (showGenreNames['Mystery'] ?? 0),
        tiers: const {
          AchievementTier.bronze: 15,
          AchievementTier.silver: 40,
        },
      ),
      Achievement(
        id: 'hopeless_romantic',
        title: 'Hopeless Romantic',
        description: 'Watch 15 Romance titles',
        category: AchievementCategory.genres,
        icon: Icons.favorite_rounded,
        assetPath: 'assets/awards/hopeless_romantic.jpg',
        currentValue: (movieGenres['Romance'] ?? 0) +
            (showGenreNames['Romance'] ?? 0),
        targetValue: 15,
        isUnlocked: ((movieGenres['Romance'] ?? 0) +
                (showGenreNames['Romance'] ?? 0)) >=
            15,
      ),
      Achievement(
        id: 'mind_bender',
        title: 'Mind Bender',
        description: 'Watch 10 Thriller titles',
        category: AchievementCategory.genres,
        icon: Icons.psychology_rounded,
        assetPath: 'assets/awards/mind_bender.jpg',
        currentValue: (movieGenres['Thriller'] ?? 0) +
            (showGenreNames['Thriller'] ?? 0),
        targetValue: 10,
        isUnlocked: ((movieGenres['Thriller'] ?? 0) +
                (showGenreNames['Thriller'] ?? 0)) >=
            10,
      ),
      Achievement(
        id: 'genre_hopper',
        title: 'Genre Hopper',
        description: 'Watch titles across 8+ different genres',
        category: AchievementCategory.genres,
        icon: Icons.shuffle_rounded,
        assetPath: 'assets/awards/genre_hopper.jpg',
        currentValue: uniqueGenreCount,
        targetValue: 8,
        isUnlocked: uniqueGenreCount >= 8,
      ),

      // ── 4. CONSISTENCY & STREAKS ──
      _multi(
        baseId: 'streak_master',
        title: 'Streak Master',
        description: 'Maintain a daily logging streak',
        category: AchievementCategory.streaks,
        icon: Icons.local_fire_department_rounded,
        assetPath: 'assets/awards/streak_master.jpg',
        current: streakDays,
        tiers: const {
          AchievementTier.bronze: 3,
          AchievementTier.silver: 7,
          AchievementTier.gold: 30,
          AchievementTier.diamond: 100,
        },
      ),
      Achievement(
        id: 'comeback_kid',
        title: 'Comeback Kid',
        description: 'Return and log after 14+ days of inactivity',
        category: AchievementCategory.streaks,
        icon: Icons.replay_rounded,
        assetPath: 'assets/awards/comeback_kid.jpg',
        currentValue: comebackDays >= 14 ? 1 : 0,
        targetValue: 1,
        isUnlocked: comebackDays >= 14,
      ),

      // ── 5. SPECIAL & SECRET ──
      Achievement(
        id: 'classic_connoisseur',
        title: 'Classic Connoisseur',
        description: 'Watch a movie released before 1980',
        category: AchievementCategory.special,
        icon: Icons.auto_awesome_rounded,
        assetPath: 'assets/awards/classic_connoisseur.jpg',
        currentValue: hasClassicMovie ? 1 : 0,
        targetValue: 1,
        isUnlocked: hasClassicMovie,
      ),
      Achievement(
        id: 'double_feature',
        title: 'Double Feature',
        description: 'Watch two 2.5h+ movies in a single day',
        category: AchievementCategory.special,
        icon: Icons.theaters_rounded,
        assetPath: 'assets/awards/double_feature.jpg',
        currentValue: doubleFeatureDay,
        targetValue: 1,
        isUnlocked: doubleFeatureDay >= 1,
      ),
    ];
  }

  // ── HELPER: create the best-tier achievement for a multi-tier badge ──
  static Achievement _multi({
    required String baseId,
    required String title,
    required String description,
    required AchievementCategory category,
    required IconData icon,
    required String assetPath,
    required int current,
    required Map<AchievementTier, int> tiers,
  }) {
    // Find the highest tier the user has reached.
    AchievementTier activeTier = AchievementTier.none;
    int activeTarget = tiers.values.first;
    bool hasReachedAnyTier = false;

    for (final entry in tiers.entries) {
      if (current >= entry.value) {
        activeTier = entry.key;
        hasReachedAnyTier = true;
      }
    }

    // The next target is the tier above the active one, or the highest tier
    // if the user has already maxed out.
    AchievementTier? nextTier;
    for (final entry in tiers.entries) {
      if (current < entry.value) {
        nextTier = entry.key;
        activeTarget = entry.value;
        break;
      }
    }

    // If all tiers are maxed, use the highest tier's target.
    if (nextTier == null) {
      activeTarget = tiers.values.last;
    }

    final isUnlocked = hasReachedAnyTier;

    return Achievement(
      id: baseId,
      title: title,
      description: description,
      category: category,
      tier: activeTier,
      icon: icon,
      assetPath: assetPath,
      currentValue: current,
      targetValue: activeTarget,
      isUnlocked: isUnlocked,
    );
  }

  // ── GENRE EXTRACTION ──

  static Map<String, int> _extractGenreCountsFromMovies(
      List<Map<String, dynamic>> watchedMovies) {
    final Map<String, int> counts = {};
    for (final movie in watchedMovies) {
      final genres = movie['genres'];
      if (genres is List) {
        for (final g in genres) {
          final name = g is Map ? (g['name'] as String?) : g?.toString();
          if (name != null && name.isNotEmpty) {
            counts[name] = (counts[name] ?? 0) + 1;
          }
        }
      }
    }
    return counts;
  }

  static Map<String, int> _extractGenreNamesFromShows(
      List<Map<String, dynamic>> shows) {
    final Map<String, int> counts = {};
    for (final show in shows) {
      final genres = show['genres'];
      if (genres is List) {
        for (final g in genres) {
          final name = g is Map ? (g['name'] as String?) : g?.toString();
          if (name != null && name.isNotEmpty) {
            counts[name] = (counts[name] ?? 0) + 1;
          }
        }
      }
    }
    return counts;
  }

  static int _countUniqueGenres(
    List<Map<String, dynamic>> watchedMovies,
    List<Map<String, dynamic>> shows,
  ) {
    final Set<String> genres = {};
    for (final movie in watchedMovies) {
      final g = movie['genres'];
      if (g is List) {
        for (final genre in g) {
          final name = genre is Map ? (genre['name'] as String?) : genre?.toString();
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }
    for (final show in shows) {
      final g = show['genres'];
      if (g is List) {
        for (final genre in g) {
          final name = genre is Map ? (genre['name'] as String?) : genre?.toString();
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }
    return genres.length;
  }

  // ── TIME-OF-DAY CHECKS ──

  static bool _hasTimeRange(
    List<Map<String, dynamic>> movies,
    List<Map<String, dynamic>> shows,
    int startHour,
    int startMin,
    int endHour,
    int endMin,
  ) {
    for (final m in movies) {
      final dt = _parseDate(m['watchedAt']);
      if (dt != null && _inTimeRange(dt, startHour, startMin, endHour, endMin)) {
        return true;
      }
    }
    for (final s in shows) {
      final episodes = s['watchedEpisodes'] as List?;
      if (episodes == null || episodes.isEmpty) continue;
      final datesMap = s['episodeWatchedDates'] as Map?;
      for (final ep in episodes) {
        final epKey = ep.toString();
        final rawVal = datesMap?[epKey];
        final epDateStr = rawVal is String ? rawVal : null;
        final dt = _parseDate(epDateStr ?? s['addedAt']);
        if (dt != null && _inTimeRange(dt, startHour, startMin, endHour, endMin)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _inTimeRange(
      DateTime dt, int sh, int sm, int eh, int em) {
    final mins = dt.hour * 60 + dt.minute;
    return mins >= sh * 60 + sm && mins <= eh * 60 + em;
  }

  // ── DAY-BASED COUNTERS ──

  static Map<String, int> _movieWatchDayCounts(
      List<Map<String, dynamic>> movies) {
    final Map<String, int> dayCounts = {};
    for (final m in movies) {
      final dt = _parseDate(m['watchedAt']);
      if (dt != null) {
        final key = _dayKey(dt);
        dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      }
    }
    return dayCounts;
  }

  static Map<String, int> _episodeWatchDayCounts(
      List<Map<String, dynamic>> shows) {
    final Map<String, int> dayCounts = {};
    for (final s in shows) {
      final episodes = List<dynamic>.from(s['watchedEpisodes'] ?? []);
      if (episodes.isEmpty) continue;
      final datesMap = s['episodeWatchedDates'] as Map?;
      for (final ep in episodes) {
        final epKey = ep.toString();
        final rawVal = datesMap?[epKey];
        final epDateStr = rawVal is String ? rawVal : null;
        final dt = _parseDate(epDateStr ?? s['addedAt']);
        if (dt != null) {
          final key = _dayKey(dt);
          dayCounts[key] = (dayCounts[key] ?? 0) + 1;
        }
      }
    }
    return dayCounts;
  }

  static int _maxEpisodesInSingleDay(List<Map<String, dynamic>> shows) {
    int maxEpisodes = 0;
    for (final s in shows) {
      final episodes = List<dynamic>.from(s['watchedEpisodes'] ?? []);
      if (episodes.isEmpty) continue;
      final datesMap = s['episodeWatchedDates'] as Map?;
      final Map<String, int> showDayCounts = {};
      for (final ep in episodes) {
        final epKey = ep.toString();
        final rawVal = datesMap?[epKey];
        final epDateStr = rawVal is String ? rawVal : null;
        final dt = _parseDate(epDateStr ?? s['addedAt']);
        if (dt != null) {
          final key = _dayKey(dt);
          showDayCounts[key] = (showDayCounts[key] ?? 0) + 1;
        }
      }
      for (final count in showDayCounts.values) {
        if (count > maxEpisodes) maxEpisodes = count;
      }
    }
    return maxEpisodes;
  }

  // ── WEEKEND STATS ──
  static int _weekendStats(
    List<Map<String, dynamic>> movies,
    List<Map<String, dynamic>> shows,
  ) {
    final movieDays = _movieWatchDayCounts(movies);
    final epDays = _episodeWatchDayCounts(shows);
    final allDays = <String>{...movieDays.keys, ...epDays.keys};

    final Map<String, int> weekendMovieCounts = {};
    final Map<String, int> weekendEpCounts = {};

    for (final dayKey in allDays) {
      final dt = DateTime.tryParse(dayKey);
      if (dt == null) continue;
      if (dt.weekday != DateTime.saturday && dt.weekday != DateTime.sunday) {
        continue;
      }

      // Group Saturday and Sunday into the same weekend (keyed by Saturday).
      final sat = dt.weekday == DateTime.saturday
          ? dt
          : dt.subtract(const Duration(days: 1));
      final weekendKey = _dayKey(sat);

      final movs = movieDays[dayKey] ?? 0;
      final eps = epDays[dayKey] ?? 0;

      weekendMovieCounts[weekendKey] =
          (weekendMovieCounts[weekendKey] ?? 0) + movs;
      weekendEpCounts[weekendKey] =
          (weekendEpCounts[weekendKey] ?? 0) + eps;
    }

    final allWeekendKeys = <String>{
      ...weekendMovieCounts.keys,
      ...weekendEpCounts.keys,
    };
    for (final weekendKey in allWeekendKeys) {
      final totalEps = weekendEpCounts[weekendKey] ?? 0;
      final totalMovs = weekendMovieCounts[weekendKey] ?? 0;
      if (totalEps >= 10 || totalMovs >= 3) {
        return 1;
      }
    }
    return 0;
  }

  // ── SERIES COMPLETION ──
  static int _completedSeriesCount(List<Map<String, dynamic>> shows) {
    int count = 0;
    for (final s in shows) {
      final watchedEpisodes =
          List<dynamic>.from(s['watchedEpisodes'] ?? []);
      final totalEpisodes = (s['totalEpisodes'] as num?)?.toInt() ?? 0;
      if (totalEpisodes > 0 && watchedEpisodes.length >= totalEpisodes) {
        count++;
      }
    }
    return count;
  }

  // ── STREAKS ──
  static int _longestStreak(
    List<Map<String, dynamic>> movies,
    List<Map<String, dynamic>> shows,
  ) {
    final Set<String> activeDays = {};

    for (final m in movies) {
      final dt = _parseDate(m['watchedAt']);
      if (dt != null) activeDays.add(_dayKey(dt));
    }
    for (final s in shows) {
      final episodes = List<dynamic>.from(s['watchedEpisodes'] ?? []);
      final datesMap = s['episodeWatchedDates'] as Map?;
      for (final ep in episodes) {
        final epKey = ep.toString();
        final rawVal = datesMap?[epKey];
        final epDateStr = rawVal is String ? rawVal : null;
        final dt = _parseDate(epDateStr ?? s['addedAt']);
        if (dt != null) activeDays.add(_dayKey(dt));
      }
    }

    if (activeDays.isEmpty) return 0;

    final sorted = activeDays.toList()..sort();
    int maxStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      if (curr.difference(prev).inDays == 1) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 1;
      }
    }
    return maxStreak;
  }

  static int _longestInactivityGap(
    List<Map<String, dynamic>> movies,
    List<Map<String, dynamic>> shows,
  ) {
    final Set<String> activeDays = {};

    for (final m in movies) {
      final dt = _parseDate(m['watchedAt']);
      if (dt != null) activeDays.add(_dayKey(dt));
    }
    for (final s in shows) {
      final episodes = List<dynamic>.from(s['watchedEpisodes'] ?? []);
      final datesMap = s['episodeWatchedDates'] as Map?;
      for (final ep in episodes) {
        final epKey = ep.toString();
        final rawVal = datesMap?[epKey];
        final epDateStr = rawVal is String ? rawVal : null;
        final dt = _parseDate(epDateStr ?? s['addedAt']);
        if (dt != null) activeDays.add(_dayKey(dt));
      }
    }

    if (activeDays.length < 2) return 0;

    final sorted = activeDays.toList()..sort();
    int maxGap = 0;

    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.parse(sorted[i - 1]);
      final curr = DateTime.parse(sorted[i]);
      final gap = curr.difference(prev).inDays;
      if (gap > maxGap) maxGap = gap;
    }
    return maxGap;
  }

  // ── SPECIAL BADGES ──
  static bool _hasClassicMovie(List<Map<String, dynamic>> movies) {
    for (final m in movies) {
      final releaseDateStr = m['releaseDate'] as String?;
      if (releaseDateStr != null) {
        final dt = DateTime.tryParse(releaseDateStr);
        if (dt != null && dt.year < 1980) return true;
      }
    }
    return false;
  }

  static int _doubleFeatureDayCount(List<Map<String, dynamic>> movies) {
    // Group long movies (150+ min) by day, check if any day has 2+.
    final Map<String, int> dayCounts = {};
    for (final m in movies) {
      if (m['isWatched'] != true) continue;
      final runtime = (m['runtime'] as num?)?.toInt() ?? 0;
      if (runtime < 150) continue;
      final dt = _parseDate(m['watchedAt']);
      if (dt != null) {
        final key = _dayKey(dt);
        dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      }
    }
    for (final count in dayCounts.values) {
      if (count >= 2) return 1;
    }
    return 0;
  }

  // ── UTILITIES ──
  static DateTime? _parseDate(dynamic value) {
    if (value is String) {
      final dt = DateTime.tryParse(value);
      return dt?.toLocal();
    }
    return null;
  }

  static String _dayKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
