import 'package:equatable/equatable.dart';

class MovieWatchlistItem extends Equatable {
  final int id;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final int runtime;
  final double voteAverage;
  final String? genres;
  final bool isWatched;
  final bool isFavorite;
  final String? addedAt;
  final String? watchedAt;

  const MovieWatchlistItem({
    required this.id,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtime = 0,
    this.voteAverage = 0.0,
    this.genres,
    this.isWatched = false,
    this.isFavorite = false,
    this.addedAt,
    this.watchedAt,
  });

  factory MovieWatchlistItem.fromMap(Map<String, dynamic> map) {
    return MovieWatchlistItem(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? '',
      posterPath: map['posterPath'] as String?,
      backdropPath: map['backdropPath'] as String?,
      releaseDate: map['releaseDate'] as String?,
      runtime: (map['runtime'] as num?)?.toInt() ?? 0,
      voteAverage: (map['voteAverage'] as num?)?.toDouble() ?? 0.0,
      genres: map['genres'] as String?,
      isWatched: map['isWatched'] as bool? ?? false,
      isFavorite: map['isFavorite'] as bool? ?? false,
      addedAt: map['addedAt'] as String?,
      watchedAt: map['watchedAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'releaseDate': releaseDate,
      'runtime': runtime,
      'voteAverage': voteAverage,
      'genres': genres,
      'isWatched': isWatched,
      'isFavorite': isFavorite,
      'addedAt': addedAt,
      'watchedAt': watchedAt,
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    posterPath,
    backdropPath,
    releaseDate,
    runtime,
    voteAverage,
    genres,
    isWatched,
    isFavorite,
    addedAt,
    watchedAt,
  ];
}
