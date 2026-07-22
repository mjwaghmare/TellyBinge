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
    while (watchedEpisodes.contains('$targetSeason-$targetEpisode')) {
      targetEpisode++;
    }

    // Derive category from stored field, or fall back to watchedEpisodes
    final String category = data['category'] as String? ??
        (watchedEpisodes.isEmpty ? 'HAVENT_STARTED' : 'WATCH_NEXT');

    final bool isUpToDate = category == 'UP_TO_DATE';

    // Read pre-computed display fields with defaults
    String episodeCode = data['nextEpisodeCode'] as String? ?? '';
    final String storedCode = 'S${targetSeason.toString().padLeft(2, '0')} | E${(targetEpisode - 1).toString().padLeft(2, '0')}';
    if (episodeCode.isEmpty || episodeCode == storedCode) {
      episodeCode = 'S${targetSeason.toString().padLeft(2, '0')} | E${targetEpisode.toString().padLeft(2, '0')}';
    }
    if (isUpToDate) {
      episodeCode = 'Up to date';
    }
    final String episodeTitle = data['nextEpisodeTitle'] as String? ??
        (isUpToDate ? 'Waiting for new episodes' : '');
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
    final String? upcomingNetworkName =
        data['upcomingNetworkName'] as String?;

    DateTime? upcomingAirDate;
    int? upcomingDaysLeft;
    final String? upcomingAirDateStr = data['upcomingAirDate'] as String?;
    if (upcomingAirDateStr != null && upcomingAirDateStr.isNotEmpty) {
      try {
        upcomingAirDate = DateTime.parse(upcomingAirDateStr).toLocal();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final targetDate = DateTime(
          upcomingAirDate.year,
          upcomingAirDate.month,
          upcomingAirDate.day,
        );
        upcomingDaysLeft = targetDate.difference(today).inDays;
      } catch (_) {}
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

  EnrichedShow copyWith({
    Map<String, dynamic>? rawShowData,
  }) {
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
}
