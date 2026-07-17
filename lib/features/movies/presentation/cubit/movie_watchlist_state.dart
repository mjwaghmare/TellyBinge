import 'package:equatable/equatable.dart';

abstract class MovieWatchlistState extends Equatable {
  const MovieWatchlistState();

  @override
  List<Object?> get props => [];
}

class MovieWatchlistInitial extends MovieWatchlistState {}

class MovieWatchlistLoading extends MovieWatchlistState {}

class MovieWatchlistSuccess extends MovieWatchlistState {
  final List<Map<String, dynamic>> movies;

  const MovieWatchlistSuccess(this.movies);

  @override
  List<Object?> get props => [movies];
}

class MovieWatchlistError extends MovieWatchlistState {
  final String message;

  const MovieWatchlistError(this.message);

  @override
  List<Object?> get props => [message];
}
