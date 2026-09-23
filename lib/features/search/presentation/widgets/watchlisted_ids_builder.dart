import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../data/explore_sources.dart';
import '../cubit/explore_feed_cubit.dart';

/// Rebuilds with the ids on the user's show or movie watchlist, which Explore
/// hides from its rows and grids.
class WatchlistedIdsBuilder extends StatelessWidget {
  const WatchlistedIdsBuilder({
    super.key,
    required this.type,
    required this.builder,
  });

  final ExploreMediaType type;
  final Widget Function(BuildContext context, Set<int> ids) builder;

  @override
  Widget build(BuildContext context) {
    if (type == ExploreMediaType.tv) {
      return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
        builder: (context, state) => builder(
          context,
          state is TvShowWatchlistSuccess ? _idsOf(state.shows) : const {},
        ),
      );
    }
    return BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
      builder: (context, state) => builder(
        context,
        state is MovieWatchlistSuccess ? _idsOf(state.movies) : const {},
      ),
    );
  }

  static Set<int> _idsOf(List<dynamic> items) => {
    for (final item in items) ?exploreIdOf(item['id']),
  };
}
