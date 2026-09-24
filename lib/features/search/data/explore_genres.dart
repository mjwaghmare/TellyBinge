import 'explore_sources.dart';

/// Represents a selectable genre filter pill in the Explore tab.
class GenreOption {
  final String label;
  final String emoji;
  final int? movieGenreId;
  final int? tvGenreId;

  /// Optional language requirement (e.g. Japanese 'ja' for Anime).
  final String? requiredLanguage;

  const GenreOption({
    required this.label,
    this.emoji = '',
    this.movieGenreId,
    this.tvGenreId,
    this.requiredLanguage,
  });

  /// True when this option represents the unfiltered Explore feed.
  bool get isAll =>
      movieGenreId == null &&
      tvGenreId == null &&
      (requiredLanguage == null || requiredLanguage!.isEmpty);

  /// Resolves the specific TMDB genre ID based on media type.
  int? genreIdFor(ExploreMediaType type) =>
      type == ExploreMediaType.movie ? movieGenreId : tvGenreId;

  String get displayName => emoji.isNotEmpty ? '$emoji $label' : label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenreOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          movieGenreId == other.movieGenreId &&
          tvGenreId == other.tvGenreId &&
          requiredLanguage == other.requiredLanguage;

  @override
  int get hashCode =>
      label.hashCode ^
      movieGenreId.hashCode ^
      tvGenreId.hashCode ^
      requiredLanguage.hashCode;
}

/// Curated genre pill options offered in the Explore tab.
const kExploreGenres = <GenreOption>[
  GenreOption(label: 'All'),
  GenreOption(label: 'Action', emoji: '💥', movieGenreId: 28, tvGenreId: 10759),
  GenreOption(label: 'Sci-Fi', emoji: '🚀', movieGenreId: 878, tvGenreId: 10765),
  GenreOption(label: 'Drama', emoji: '🎭', movieGenreId: 18, tvGenreId: 18),
  GenreOption(label: 'Comedy', emoji: '😂', movieGenreId: 35, tvGenreId: 35),
  GenreOption(label: 'Horror', emoji: '👻', movieGenreId: 27, tvGenreId: 9648),
  GenreOption(
    label: 'Anime',
    emoji: '🌸',
    movieGenreId: 16,
    tvGenreId: 16,
    requiredLanguage: 'ja',
  ),
  GenreOption(label: 'Thriller', emoji: '🔪', movieGenreId: 53, tvGenreId: 80),
  GenreOption(
    label: 'Romance',
    emoji: '❤️',
    movieGenreId: 10749,
    tvGenreId: 10766,
  ),
];
