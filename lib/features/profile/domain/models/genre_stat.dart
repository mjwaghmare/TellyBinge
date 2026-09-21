import 'package:equatable/equatable.dart';

/// Aggregated statistics for a specific genre slice.
class GenreStat extends Equatable {
  /// Display name of the genre (e.g. "Drama", "Sci-Fi & Fantasy", "Other").
  final String genre;

  /// Number of movies/shows tagged with this genre.
  final int count;

  /// Percentage of the total tracked genre tags (0.0 - 100.0).
  final double percentage;

  const GenreStat({
    required this.genre,
    required this.count,
    required this.percentage,
  });

  @override
  List<Object?> get props => [genre, count, percentage];
}
