import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';

abstract class ShowDetailsState extends Equatable {
  const ShowDetailsState();

  @override
  List<Object?> get props => [];
}

class ShowDetailsInitial extends ShowDetailsState {}

class ShowDetailsLoading extends ShowDetailsState {}

class ShowDetailsSuccess extends ShowDetailsState {
  final Map<String, dynamic> details;
  final String mediaType;
  // Maps Season Number -> List of Episode maps
  final Map<int, List<dynamic>> seasonsData;
  final bool isCastLoading;
  final bool isSimilarLoading;

  const ShowDetailsSuccess({
    required this.details,
    required this.mediaType,
    required this.seasonsData,
    this.isCastLoading = false,
    this.isSimilarLoading = false,
  });

  ShowDetailsSuccess copyWith({
    Map<String, dynamic>? details,
    String? mediaType,
    Map<int, List<dynamic>>? seasonsData,
    bool? isCastLoading,
    bool? isSimilarLoading,
  }) {
    return ShowDetailsSuccess(
      details: details ?? this.details,
      mediaType: mediaType ?? this.mediaType,
      seasonsData: seasonsData ?? this.seasonsData,
      isCastLoading: isCastLoading ?? this.isCastLoading,
      isSimilarLoading: isSimilarLoading ?? this.isSimilarLoading,
    );
  }

  @override
  List<Object?> get props => [
    details,
    mediaType,
    seasonsData,
    isCastLoading,
    isSimilarLoading,
  ];
}

class ShowDetailsError extends ShowDetailsState {
  final Failure failure;
  String get message => failure.message;

  ShowDetailsError(Object error)
      : failure = error is Failure ? error : Failure.fromException(error);

  @override
  List<Object?> get props => [failure];
}
