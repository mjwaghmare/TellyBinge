import 'package:equatable/equatable.dart';

class TvShowWatchlistItem extends Equatable {
  final int id;
  final String name;
  final String? posterPath;
  final String? backdropPath;
  final String? firstAirDate;
  final double voteAverage;
  final List<String> watchedEpisodes;
  final Map<String, String> episodeWatchedDates;
  final String? addedAt;
  final String category;
  final String nextEpisodeCode;
  final String nextEpisodeTitle;
  final int targetSeason;
  final int targetEpisode;
  final String? extraCount;
  final bool isPremiere;
  final bool isNewEpisode;
  final String upcomingEpisodeCode;
  final String upcomingEpisodeTitle;
  final String? upcomingAirDate;
  final String? upcomingNetworkName;
  final bool hasUpcoming;
  final bool upcomingIsPremiere;
  final bool upcomingIsNew;
  final int totalEpisodes;
  final String? lastEnrichedAt;
  final bool isFavorite;

  const TvShowWatchlistItem({
    required this.id,
    required this.name,
    this.posterPath,
    this.backdropPath,
    this.firstAirDate,
    this.voteAverage = 0.0,
    this.watchedEpisodes = const [],
    this.episodeWatchedDates = const {},
    this.addedAt,
    this.category = 'HAVENT_STARTED',
    this.nextEpisodeCode = '',
    this.nextEpisodeTitle = '',
    this.targetSeason = 1,
    this.targetEpisode = 1,
    this.extraCount,
    this.isPremiere = false,
    this.isNewEpisode = false,
    this.upcomingEpisodeCode = 'TBA',
    this.upcomingEpisodeTitle = 'No upcoming episodes',
    this.upcomingAirDate,
    this.upcomingNetworkName,
    this.hasUpcoming = false,
    this.upcomingIsPremiere = false,
    this.upcomingIsNew = false,
    this.totalEpisodes = 0,
    this.lastEnrichedAt,
    this.isFavorite = false,
  });

  factory TvShowWatchlistItem.fromMap(Map<String, dynamic> map) {
    return TvShowWatchlistItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name']?.toString() ?? '',
      posterPath: map['posterPath'] as String?,
      backdropPath: map['backdropPath'] as String?,
      firstAirDate: map['firstAirDate'] as String?,
      voteAverage: (map['voteAverage'] as num?)?.toDouble() ?? 0.0,
      watchedEpisodes: List<String>.from(map['watchedEpisodes'] ?? const []),
      episodeWatchedDates: map['episodeWatchedDates'] is Map
          ? (map['episodeWatchedDates'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      addedAt: map['addedAt'] as String?,
      category: map['category'] as String? ?? 'HAVENT_STARTED',
      nextEpisodeCode: map['nextEpisodeCode'] as String? ?? '',
      nextEpisodeTitle: map['nextEpisodeTitle'] as String? ?? '',
      targetSeason: (map['targetSeason'] as num?)?.toInt() ?? 1,
      targetEpisode: (map['targetEpisode'] as num?)?.toInt() ?? 1,
      extraCount: map['extraCount'] as String?,
      isPremiere: map['isPremiere'] as bool? ?? false,
      isNewEpisode: map['isNewEpisode'] as bool? ?? false,
      upcomingEpisodeCode: map['upcomingEpisodeCode'] as String? ?? 'TBA',
      upcomingEpisodeTitle:
          map['upcomingEpisodeTitle'] as String? ?? 'No upcoming episodes',
      upcomingAirDate: map['upcomingAirDate'] as String?,
      upcomingNetworkName: map['upcomingNetworkName'] as String?,
      hasUpcoming: map['hasUpcoming'] as bool? ?? false,
      upcomingIsPremiere: map['upcomingIsPremiere'] as bool? ?? false,
      upcomingIsNew: map['upcomingIsNew'] as bool? ?? false,
      totalEpisodes: (map['totalEpisodes'] as num?)?.toInt() ?? 0,
      lastEnrichedAt: map['lastEnrichedAt'] as String?,
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'firstAirDate': firstAirDate,
      'voteAverage': voteAverage,
      'watchedEpisodes': watchedEpisodes,
      'episodeWatchedDates': episodeWatchedDates,
      'addedAt': addedAt,
      'category': category,
      'nextEpisodeCode': nextEpisodeCode,
      'nextEpisodeTitle': nextEpisodeTitle,
      'targetSeason': targetSeason,
      'targetEpisode': targetEpisode,
      'extraCount': extraCount,
      'isPremiere': isPremiere,
      'isNewEpisode': isNewEpisode,
      'upcomingEpisodeCode': upcomingEpisodeCode,
      'upcomingEpisodeTitle': upcomingEpisodeTitle,
      'upcomingAirDate': upcomingAirDate,
      'upcomingNetworkName': upcomingNetworkName,
      'hasUpcoming': hasUpcoming,
      'upcomingIsPremiere': upcomingIsPremiere,
      'upcomingIsNew': upcomingIsNew,
      'totalEpisodes': totalEpisodes,
      'lastEnrichedAt': lastEnrichedAt,
      'isFavorite': isFavorite,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    posterPath,
    backdropPath,
    firstAirDate,
    voteAverage,
    watchedEpisodes,
    episodeWatchedDates,
    addedAt,
    category,
    nextEpisodeCode,
    nextEpisodeTitle,
    targetSeason,
    targetEpisode,
    extraCount,
    isPremiere,
    isNewEpisode,
    upcomingEpisodeCode,
    upcomingEpisodeTitle,
    upcomingAirDate,
    upcomingNetworkName,
    hasUpcoming,
    upcomingIsPremiere,
    upcomingIsNew,
    totalEpisodes,
    lastEnrichedAt,
    isFavorite,
  ];
}
