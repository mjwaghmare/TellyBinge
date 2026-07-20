import 'package:equatable/equatable.dart';

abstract class MovieDetailsState extends Equatable {
  const MovieDetailsState();

  @override
  List<Object?> get props => [];
}

class MovieDetailsInitial extends MovieDetailsState {}

class MovieDetailsLoading extends MovieDetailsState {}

class MovieDetailsSuccess extends MovieDetailsState {
  final Map<String, dynamic> movieDetails;
  final Map<String, dynamic> movieCredits;
  final List<dynamic> similarMovies;
  final List<dynamic> collectionParts;
  final String collectionSectionTitle;

  const MovieDetailsSuccess({
    required this.movieDetails,
    required this.movieCredits,
    required this.similarMovies,
    required this.collectionParts,
    required this.collectionSectionTitle,
  });

  MovieDetailsSuccess copyWith({
    Map<String, dynamic>? movieDetails,
    Map<String, dynamic>? movieCredits,
    List<dynamic>? similarMovies,
    List<dynamic>? collectionParts,
    String? collectionSectionTitle,
  }) {
    return MovieDetailsSuccess(
      movieDetails: movieDetails ?? this.movieDetails,
      movieCredits: movieCredits ?? this.movieCredits,
      similarMovies: similarMovies ?? this.similarMovies,
      collectionParts: collectionParts ?? this.collectionParts,
      collectionSectionTitle: collectionSectionTitle ?? this.collectionSectionTitle,
    );
  }

  @override
  List<Object?> get props => [
        movieDetails,
        movieCredits,
        similarMovies,
        collectionParts,
        collectionSectionTitle,
      ];
}

class MovieDetailsError extends MovieDetailsState {
  final String message;

  const MovieDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}
