import 'package:equatable/equatable.dart';

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

  const ShowDetailsSuccess({
    required this.details,
    required this.mediaType,
    required this.seasonsData,
  });

  ShowDetailsSuccess copyWith({
    Map<String, dynamic>? details,
    String? mediaType,
    Map<int, List<dynamic>>? seasonsData,
  }) {
    return ShowDetailsSuccess(
      details: details ?? this.details,
      mediaType: mediaType ?? this.mediaType,
      seasonsData: seasonsData ?? this.seasonsData,
    );
  }

  @override
  List<Object?> get props => [details, mediaType, seasonsData];
}

class ShowDetailsError extends ShowDetailsState {
  final String message;

  const ShowDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}
