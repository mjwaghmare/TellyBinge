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
      label == 'All' ||
      (movieGenreId == null &&
          tvGenreId == null &&
          (requiredLanguage == null || requiredLanguage!.isEmpty));

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
  GenreOption(label: 'Adventure', emoji: '🗺️', movieGenreId: 12, tvGenreId: 10759),
  GenreOption(label: 'Comedy', emoji: '😂', movieGenreId: 35, tvGenreId: 35),
  GenreOption(label: 'Crime', emoji: '🕵️', movieGenreId: 80, tvGenreId: 80),
  GenreOption(label: 'Drama', emoji: '🎭', movieGenreId: 18, tvGenreId: 18),
  GenreOption(label: 'Family', emoji: '👨‍👩‍👧', movieGenreId: 10751, tvGenreId: 10751),
  GenreOption(label: 'History', emoji: '📜', movieGenreId: 36, tvGenreId: 10768),
  GenreOption(label: 'Horror', emoji: '👻', movieGenreId: 27, tvGenreId: 9648),
  GenreOption(label: 'Reality', emoji: '🌟', movieGenreId: 10764, tvGenreId: 10764),
  GenreOption(
    label: 'Romance',
    emoji: '❤️',
    movieGenreId: 10749,
    tvGenreId: 10766,
  ),
  GenreOption(label: 'Sci-Fi', emoji: '🚀', movieGenreId: 878, tvGenreId: 10765),
  GenreOption(label: 'Thriller', emoji: '🔪', movieGenreId: 53, tvGenreId: 80),
  GenreOption(
    label: 'Anime',
    emoji: '🌸',
    movieGenreId: 16,
    tvGenreId: 16,
    requiredLanguage: 'ja',
  ),
];

/// Determines the user's most frequent genre from their saved watchlist items.
///
/// Inspects both TV and Movie watchlist schemas (supporting comma-delimited
/// genre names, genre maps, and genre ID lists). Returns null if no matching
/// curated genre from [kExploreGenres] is found.
GenreOption? resolveTopWatchlistGenre({
  List<Map<String, dynamic>>? tvShows,
  List<Map<String, dynamic>>? movies,
}) {
  final counts = <GenreOption, int>{};

  final activeGenres = kExploreGenres.where((g) => !g.isAll).toList();

  void recordMatch(GenreOption genre) {
    counts[genre] = (counts[genre] ?? 0) + 1;
  }

  void processItem(Map<String, dynamic> item) {
    final itemMatches = <GenreOption>{};

    // 1. Check rawGenreIds / genre_ids
    final rawGenreIds = item['genre_ids'] ?? item['genreIds'];
    if (rawGenreIds is List) {
      for (final id in rawGenreIds) {
        final intId = (id as num?)?.toInt();
        if (intId == null) continue;
        for (final g in activeGenres) {
          if (g.movieGenreId == intId || g.tvGenreId == intId) {
            itemMatches.add(g);
          }
        }
      }
    }

    // 2. Check genres string or list
    final rawGenres = item['genres'];
    if (rawGenres is String && rawGenres.trim().isNotEmpty) {
      for (final part in rawGenres.split(',')) {
        final name = part.trim().toLowerCase();
        if (name.isEmpty) continue;
        for (final g in activeGenres) {
          final labelLower = g.label.toLowerCase();
          if (name == labelLower ||
              (labelLower == 'sci-fi' && (name.contains('sci-fi') || name.contains('science fiction')))) {
            itemMatches.add(g);
          }
        }
      }
    } else if (rawGenres is List) {
      for (final g in rawGenres) {
        String? name;
        if (g is Map) {
          name = (g['name'] as String?)?.trim().toLowerCase();
        } else if (g is String) {
          name = g.trim().toLowerCase();
        }
        if (name != null && name.isNotEmpty) {
          for (final opt in activeGenres) {
            final labelLower = opt.label.toLowerCase();
            if (name == labelLower ||
                (labelLower == 'sci-fi' && (name.contains('sci-fi') || name.contains('science fiction')))) {
              itemMatches.add(opt);
            }
          }
        }
      }
    }

    for (final matched in itemMatches) {
      recordMatch(matched);
    }
  }

  if (tvShows != null) {
    for (final show in tvShows) {
      processItem(show);
    }
  }
  if (movies != null) {
    for (final movie in movies) {
      processItem(movie);
    }
  }

  if (counts.isEmpty) return null;

  var topCount = 0;
  GenreOption? topGenre;
  for (final entry in counts.entries) {
    if (entry.value > topCount) {
      topCount = entry.value;
      topGenre = entry.key;
    }
  }
  return topGenre;
}

/// Resolves a list of stored genre label strings into curated [GenreOption]s.
List<GenreOption> resolvePreferredGenres(List<String> labels) {
  if (labels.isEmpty) return const [];
  final activeGenres = kExploreGenres.where((g) => !g.isAll).toList();
  final result = <GenreOption>[];
  for (final label in labels) {
    final clean = label.trim().toLowerCase();
    for (final genre in activeGenres) {
      if (genre.label.toLowerCase() == clean && !result.contains(genre)) {
        result.add(genre);
        break;
      }
    }
  }
  return result;
}
