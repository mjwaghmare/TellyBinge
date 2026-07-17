import 'package:equatable/equatable.dart';

abstract class TvShowWatchlistState extends Equatable {
  const TvShowWatchlistState();

  @override
  List<Object?> get props => [];
}

class TvShowWatchlistInitial extends TvShowWatchlistState {}

class TvShowWatchlistLoading extends TvShowWatchlistState {}

class TvShowWatchlistSuccess extends TvShowWatchlistState {
  final List<Map<String, dynamic>> shows;

  const TvShowWatchlistSuccess(this.shows);

  @override
  List<Object?> get props => [shows];
}

class TvShowWatchlistError extends TvShowWatchlistState {
  final String message;

  const TvShowWatchlistError(this.message);

  @override
  List<Object?> get props => [message];
}
