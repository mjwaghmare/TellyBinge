import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';

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
  final bool isCastLoading;
  final bool isCollectionLoading;
  final bool isSimilarLoading;

  const MovieDetailsSuccess({
    required this.movieDetails,
    required this.movieCredits,
    required this.similarMovies,
    required this.collectionParts,
    required this.collectionSectionTitle,
    this.isCastLoading = false,
    this.isCollectionLoading = false,
    this.isSimilarLoading = false,
  });

  MovieDetailsSuccess copyWith({
    Map<String, dynamic>? movieDetails,
    Map<String, dynamic>? movieCredits,
    List<dynamic>? similarMovies,
    List<dynamic>? collectionParts,
    String? collectionSectionTitle,
    bool? isCastLoading,
    bool? isCollectionLoading,
    bool? isSimilarLoading,
  }) {
    return MovieDetailsSuccess(
      movieDetails: movieDetails ?? this.movieDetails,
      movieCredits: movieCredits ?? this.movieCredits,
      similarMovies: similarMovies ?? this.similarMovies,
      collectionParts: collectionParts ?? this.collectionParts,
      collectionSectionTitle:
          collectionSectionTitle ?? this.collectionSectionTitle,
      isCastLoading: isCastLoading ?? this.isCastLoading,
      isCollectionLoading: isCollectionLoading ?? this.isCollectionLoading,
      isSimilarLoading: isSimilarLoading ?? this.isSimilarLoading,
    );
  }

  @override
  List<Object?> get props => [
    movieDetails,
    movieCredits,
    similarMovies,
    collectionParts,
    collectionSectionTitle,
    isCastLoading,
    isCollectionLoading,
    isSimilarLoading,
  ];
}

class MovieDetailsError extends MovieDetailsState {
  final Failure failure;
  String get message => failure.message;

  MovieDetailsError(Object error)
      : failure = error is Failure ? error : Failure.fromException(error);

  @override
  List<Object?> get props => [failure];
}
