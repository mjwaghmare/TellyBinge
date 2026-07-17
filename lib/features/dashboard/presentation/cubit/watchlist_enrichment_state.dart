import 'package:equatable/equatable.dart';
import '../models/enriched_show.dart';

abstract class WatchlistEnrichmentState extends Equatable {
  const WatchlistEnrichmentState();

  @override
  List<Object> get props => [];
}

class WatchlistEnrichmentInitial extends WatchlistEnrichmentState {}

class WatchlistEnrichmentLoading extends WatchlistEnrichmentState {}

class WatchlistEnrichmentLoaded extends WatchlistEnrichmentState {
  final List<EnrichedShow> enrichedShows;

  const WatchlistEnrichmentLoaded(this.enrichedShows);

  @override
  List<Object> get props => [enrichedShows];
}

class WatchlistEnrichmentError extends WatchlistEnrichmentState {
  final String message;

  const WatchlistEnrichmentError(this.message);

  @override
  List<Object> get props => [message];
}
