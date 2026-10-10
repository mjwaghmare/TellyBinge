class EnrichedShow {
  final Map<String, dynamic> rawShowData;

  // Watchlist specific properties
  final String episodeCode;
  final String episodeTitle;
  final String? extraCount;
  final bool isPremiere;
  final bool isNew;
  final bool isUpToDate;
  final int targetSeason;
  final int targetEpisode;
  final int totalEpisodes;
  final String watchlistStatus; // 'UP_TO_DATE', 'HAVENT_STARTED', 'WATCH_NEXT'

  // Upcoming specific properties
  final String upcomingEpisodeCode;
  final String upcomingEpisodeTitle;
  final bool upcomingIsPremiere;
  final bool upcomingIsNew;
  final DateTime? upcomingAirDate;
  final String? upcomingNetworkName;
  final int? upcomingDaysLeft;
  final bool hasUpcoming;

  EnrichedShow({
    required this.rawShowData,
    required this.episodeCode,
    required this.episodeTitle,
    this.extraCount,
    required this.isPremiere,
    required this.isNew,
    required this.isUpToDate,
    required this.targetSeason,
    required this.targetEpisode,
    this.totalEpisodes = 0,
    required this.watchlistStatus,
    required this.upcomingEpisodeCode,
    required this.upcomingEpisodeTitle,
    required this.upcomingIsPremiere,
    required this.upcomingIsNew,
    this.upcomingAirDate,
    this.upcomingNetworkName,
    this.upcomingDaysLeft,
    required this.hasUpcoming,
  });

  /// Creates an [EnrichedShow] directly from a Firebase show document.
  ///
  /// Reads pre-computed enrichment fields if they exist, otherwise falls back
  /// to sensible defaults. This enables instant UI rendering without waiting
  /// for TMDB API calls.
  factory EnrichedShow.fromShowData(Map<String, dynamic> data) {
    final watchedEpisodes = List<String>.from(data['watchedEpisodes'] ?? []);

    int targetSeason = (data['targetSeason'] as num?)?.toInt() ?? 1;
    int targetEpisode = (data['targetEpisode'] as num?)?.toInt() ?? 1;
    if (targetSeason <= 0) targetSeason = 1;
    if (targetEpisode <= 0) targetEpisode = 1;

    while (watchedEpisodes.contains('$targetSeason-$targetEpisode')) {
      targetEpisode++;
    }

    final derivedCode =
        'S${targetSeason.toString().padLeft(2, '0')} | E${targetEpisode.toString().padLeft(2, '0')}';

    final int totalEpisodes = (data['totalEpisodes'] as num?)?.toInt() ?? 0;
    final String? extraCount = data['extraCount'] as String?;
    final bool isPremiere = data['isPremiere'] as bool? ?? false;
    final bool isNewEpisode = data['isNewEpisode'] as bool? ?? false;

    // Upcoming fields
    final String upcomingEpisodeCode =
        data['upcomingEpisodeCode'] as String? ?? 'TBA';
    final String upcomingEpisodeTitle =
        data['upcomingEpisodeTitle'] as String? ?? 'No upcoming episodes';
    final bool upcomingIsPremiere =
        data['upcomingIsPremiere'] as bool? ?? false;
    final bool upcomingIsNew = data['upcomingIsNew'] as bool? ?? false;
    final bool hasUpcoming = data['hasUpcoming'] as bool? ?? false;
    final String? upcomingNetworkName = data['upcomingNetworkName'] as String?;

    DateTime? upcomingAirDate;
    int? upcomingDaysLeft;
    final String? upcomingAirDateStr = data['upcomingAirDate'] as String?;
    if (upcomingAirDateStr != null && upcomingAirDateStr.isNotEmpty) {
      try {
        final parsed = DateTime.parse(upcomingAirDateStr);
        upcomingAirDate = parsed.toLocal();
        final now = DateTime.now();
        final today = DateTime.utc(now.year, now.month, now.day);
        final targetDate = DateTime.utc(
          upcomingAirDate.year,
          upcomingAirDate.month,
          upcomingAirDate.day,
        );
        upcomingDaysLeft = targetDate.difference(today).inDays;
      } catch (_) {}
    }

    final String? storedNextCode = data['nextEpisodeCode'] as String?;

    // Check if the next unwatched episode is actually an unreleased upcoming episode.
    // Compare upcoming episode with targetSeason and targetEpisode so differently padded
    // codes match without being misled by a potentially stale storedNextCode.
    final upcomingParsed = _parseSeasonEpisode(upcomingEpisodeCode);
    final storedParsed = _parseSeasonEpisode(storedNextCode);
    final bool storedMatchesTarget = storedParsed != null &&
        storedParsed.$1 == targetSeason &&
        storedParsed.$2 == targetEpisode;

    final bool codesMatch = (upcomingParsed != null &&
            upcomingParsed.$1 == targetSeason &&
            upcomingParsed.$2 == targetEpisode) ||
        (upcomingEpisodeCode.isNotEmpty &&
            upcomingEpisodeCode != 'TBA' &&
            (upcomingEpisodeCode == derivedCode ||
                (storedMatchesTarget &&
                    upcomingEpisodeCode == storedNextCode)));

    final bool isNextUpcoming =
        hasUpcoming &&
        upcomingDaysLeft != null &&
        upcomingDaysLeft > 0 &&
        codesMatch;

    // Derive category:
    // If watchedEpisodes is not empty, the user has started watching this show.
    // If all released episodes are watched (next unwatched is upcoming, or stored category is UP_TO_DATE/FINISHED),
    // then the user is UP_TO_DATE or FINISHED.
    final String storedCategory = data['category'] as String? ?? '';
    String category;
    if (watchedEpisodes.isEmpty) {
      if (storedCategory == 'UPCOMING_ONLY') {
        category = 'UPCOMING_ONLY';
      } else {
        category = 'HAVENT_STARTED';
      }
    } else {
      final storedParsed = _parseSeasonEpisode(storedNextCode);
      final bool isStoredCodeValid = storedParsed != null &&
          !watchedEpisodes.contains('${storedParsed.$1}-${storedParsed.$2}') &&
          !watchedEpisodes.contains(storedNextCode) &&
          storedParsed.$1 == targetSeason &&
          storedParsed.$2 == targetEpisode;

      final bool hasAiredUnwatched = storedNextCode != null &&
          storedNextCode.isNotEmpty &&
          storedNextCode != 'Up to date' &&
          storedNextCode != 'TBA' &&
          isStoredCodeValid &&
          !isNextUpcoming;

      if (hasAiredUnwatched) {
        category = 'WATCH_NEXT';
      } else if (storedCategory == 'UP_TO_DATE' ||
          storedCategory == 'FINISHED' ||
          isNextUpcoming ||
          (totalEpisodes > 0 && watchedEpisodes.length >= totalEpisodes)) {
        category = (storedCategory == 'FINISHED' && !isNextUpcoming)
            ? 'FINISHED'
            : 'UP_TO_DATE';
      } else {
        category = 'WATCH_NEXT';
      }
    }

    final bool isUpToDate = category == 'UP_TO_DATE' || category == 'FINISHED';

    // Compute episode code for next unwatched episode
    String episodeCode;
    if (isUpToDate) {
      episodeCode = 'Up to date';
    } else if (storedNextCode != null &&
        storedNextCode.trim().toUpperCase() == 'TBA') {
      episodeCode = storedNextCode;
    } else {
      if (storedNextCode != null && storedNextCode.isNotEmpty) {
        final parsed = _parseSeasonEpisode(storedNextCode);
        if (parsed != null &&
            parsed.$1 == targetSeason &&
            parsed.$2 == targetEpisode) {
          episodeCode = storedNextCode;
        } else {
          episodeCode = derivedCode;
        }
      } else {
        episodeCode = derivedCode;
      }
    }

    String episodeTitle;
    final String? storedTitle = data['nextEpisodeTitle'] as String?;
    if (isUpToDate) {
      episodeTitle = 'Waiting for new episodes';
    } else if (storedTitle != null && storedTitle.isNotEmpty) {
      final String? storedNextCode = data['nextEpisodeCode'] as String?;
      if (storedNextCode != null && storedNextCode == episodeCode) {
        episodeTitle = storedTitle;
      } else {
        episodeTitle = '';
      }
    } else if (episodeCode.trim().toUpperCase() == 'TBA') {
      final status = data['status']?.toString().toLowerCase();
      final isEnded = status == 'ended' || status == 'canceled';
      episodeTitle = isEnded ? "Haven't started" : 'Waiting for premiere';
    } else {
      episodeTitle = '';
    }

    return EnrichedShow(
      rawShowData: data,
      episodeCode: episodeCode,
      episodeTitle: episodeTitle,
      extraCount: extraCount,
      isPremiere: isPremiere,
      isNew: isNewEpisode,
      isUpToDate: isUpToDate,
      targetSeason: targetSeason,
      targetEpisode: targetEpisode,
      totalEpisodes: totalEpisodes,
      watchlistStatus: category,
      upcomingEpisodeCode: upcomingEpisodeCode,
      upcomingEpisodeTitle: upcomingEpisodeTitle,
      upcomingIsPremiere: upcomingIsPremiere,
      upcomingIsNew: upcomingIsNew,
      upcomingAirDate: upcomingAirDate,
      upcomingNetworkName: upcomingNetworkName,
      upcomingDaysLeft: upcomingDaysLeft,
      hasUpcoming: hasUpcoming,
    );
  }

  EnrichedShow copyWith({Map<String, dynamic>? rawShowData}) {
    return EnrichedShow(
      rawShowData: rawShowData ?? this.rawShowData,
      episodeCode: episodeCode,
      episodeTitle: episodeTitle,
      extraCount: extraCount,
      isPremiere: isPremiere,
      isNew: isNew,
      isUpToDate: isUpToDate,
      targetSeason: targetSeason,
      targetEpisode: targetEpisode,
      totalEpisodes: totalEpisodes,
      watchlistStatus: watchlistStatus,
      upcomingEpisodeCode: upcomingEpisodeCode,
      upcomingEpisodeTitle: upcomingEpisodeTitle,
      upcomingIsPremiere: upcomingIsPremiere,
      upcomingIsNew: upcomingIsNew,
      upcomingAirDate: upcomingAirDate,
      upcomingNetworkName: upcomingNetworkName,
      upcomingDaysLeft: upcomingDaysLeft,
      hasUpcoming: hasUpcoming,
    );
  }

  /// True if the current target episode is the final episode of its season.
  bool get isSeasonFinale {
    if (targetSeason <= 0 || targetEpisode <= 0) return false;
    final seasons = rawShowData['seasons'] as List<dynamic>?;
    if (seasons != null && seasons.isNotEmpty) {
      for (final s in seasons) {
        if (s is Map && (s['season_number'] as num?)?.toInt() == targetSeason) {
          final count = (s['episode_count'] as num?)?.toInt() ?? 0;
          if (count > 0 && targetEpisode == count) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// True if completing this episode marks the entire TV show as fully watched.
  bool get isSeriesFinale {
    if (!isSeasonFinale) return false;

    // A series finale celebration only applies if the show has concluded (Ended / Canceled).
    // Returning series waiting for future seasons are season finales, not series finales.
    final status = rawShowData['status']?.toString().toLowerCase();
    final isShowEnded = status == 'ended' || status == 'canceled';
    if (!isShowEnded) return false;

    final numSeasons = (rawShowData['number_of_seasons'] as num?)?.toInt();
    int effectiveNumSeasons = numSeasons ?? 0;
    final seasons = rawShowData['seasons'] as List<dynamic>?;
    if (seasons != null && seasons.isNotEmpty) {
      final validSeasonNums = seasons.where((s) {
        if (s is! Map) return false;
        final sNum = (s['season_number'] as num?)?.toInt() ?? 0;
        final count = (s['episode_count'] as num?)?.toInt() ?? 0;
        return sNum > 0 && count > 0;
      }).map((s) => (s['season_number'] as num?)?.toInt() ?? 0);
      if (validSeasonNums.isNotEmpty) {
        effectiveNumSeasons =
            validSeasonNums.fold<int>(0, (a, b) => b > a ? b : a);
      }
    }

    if (effectiveNumSeasons > 0 && targetSeason == effectiveNumSeasons) {
      if (totalEpisodes > 0) {
        final watched = rawShowData['watchedEpisodes'];
        final watchedCount = watched is List ? watched.length : 0;
        return watchedCount + 1 >= totalEpisodes;
      }
      return true;
    }

    if (totalEpisodes > 0) {
      final watched = rawShowData['watchedEpisodes'];
      final watchedCount = watched is List ? watched.length : 0;
      return watchedCount + 1 >= totalEpisodes;
    }

    return false;
  }

  /// Parses season and episode numbers from formatted strings like `S01 | E02`, `S1E2`, etc.
  static (int, int)? _parseSeasonEpisode(String? code) {
    if (code == null || code.isEmpty) return null;
    final match = RegExp(
      r'S(\d+)\s*(?:\|\s*)?E?(\d+)',
      caseSensitive: false,
    ).firstMatch(code);
    if (match == null) return null;
    final s = int.tryParse(match.group(1) ?? '');
    final e = int.tryParse(match.group(2) ?? '');
    if (s == null || e == null) return null;
    return (s, e);
  }
}
