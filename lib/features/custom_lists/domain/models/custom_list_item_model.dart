import 'package:equatable/equatable.dart';

class CustomListItemModel extends Equatable {
  final int id;
  final String mediaType; // 'movie' or 'tv'
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseDate;
  final DateTime addedAt;

  const CustomListItemModel({
    required this.id,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0.0,
    this.releaseDate,
    required this.addedAt,
  });

  bool get isMovie => mediaType == 'movie';
  bool get isTvShow => mediaType == 'tv';

  factory CustomListItemModel.fromJson(Map<String, dynamic> json) {
    return CustomListItemModel(
      id: json['id'] as int? ?? 0,
      mediaType: json['mediaType'] as String? ?? 'movie',
      title: json['title'] as String? ?? '',
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['releaseDate'] as String?,
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaType': mediaType,
      'title': title,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'voteAverage': voteAverage,
      'releaseDate': releaseDate,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  CustomListItemModel copyWith({
    int? id,
    String? mediaType,
    String? title,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
    String? releaseDate,
    DateTime? addedAt,
  }) {
    return CustomListItemModel(
      id: id ?? this.id,
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      voteAverage: voteAverage ?? this.voteAverage,
      releaseDate: releaseDate ?? this.releaseDate,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    mediaType,
    title,
    posterPath,
    backdropPath,
    voteAverage,
    releaseDate,
    addedAt,
  ];
}
