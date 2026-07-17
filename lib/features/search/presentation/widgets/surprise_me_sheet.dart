import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import 'rolling_dice_button.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';

class SurpriseMeSheet extends StatefulWidget {
  const SurpriseMeSheet({super.key});

  @override
  State<SurpriseMeSheet> createState() => _SurpriseMeSheetState();
}

class _SurpriseMeSheetState extends State<SurpriseMeSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Random _random = Random();

  // History to avoid showing the same page recently
  final List<int> _seenTvPages = [];
  final List<int> _seenMoviePages = [];
  static const int _maxHistory = 100;

  List<dynamic> _tvShows = [];
  List<dynamic> _movies = [];

  bool _isLoadingTv = true;
  bool _isLoadingMovies = true;

  String? _tvError;
  String? _movieError;

  final ScrollController _tvScrollController = ScrollController();
  final ScrollController _movieScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _loadTvShows();
    _loadMovies();
  }

  bool get _isCurrentTabLoading {
    return _tabController.index == 0 ? _isLoadingTv : _isLoadingMovies;
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _loadTvShows() async {
    final tmdbClient = context.read<TmdbClient>();

    setState(() {
      _isLoadingTv = true;
      _tvError = null;
    });

    if (_tvScrollController.hasClients) {
      _tvScrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final tvState = context.read<TvShowWatchlistCubit>().state;
      final addedIds = <int>{};
      if (tvState is TvShowWatchlistSuccess) {
        for (var show in tvState.shows) {
          final rawId = show['id'];
          if (rawId is int) {
            addedIds.add(rawId);
          } else if (rawId is String) {
            final parsed = int.tryParse(rawId);
            if (parsed != null) addedIds.add(parsed);
          }
        }
      }

      List<dynamic> validResults = [];
      int retryCount = 0;

      while (validResults.length < 15 && retryCount < 10) {
        int page;
        do {
          page = _random.nextInt(250) + 1;
        } while (_seenTvPages.contains(page));

        _seenTvPages.add(page);
        if (_seenTvPages.length > _maxHistory) {
          _seenTvPages.removeAt(0);
        }

        final results = await tmdbClient.discoverTvShowsWithFilters(
          page: page,
          sortBy: 'popularity.desc',
          firstAirDateGte: '2020-01-01',
        );

        if (!mounted) return;

        results.shuffle(_random);
        results.removeWhere((item) => addedIds.contains(item['id']));

        for (var item in results) {
          if (validResults.length < 15 && !validResults.any((e) => e['id'] == item['id'])) {
            validResults.add(item);
          }
        }
        retryCount++;
      }

      if (mounted) {
        setState(() {
          _tvShows = validResults;
          _isLoadingTv = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tvError = 'Failed to load surprises.';
          _isLoadingTv = false;
        });
      }
    }
  }

  Future<void> _loadMovies() async {
    final tmdbClient = context.read<TmdbClient>();

    setState(() {
      _isLoadingMovies = true;
      _movieError = null;
    });

    if (_movieScrollController.hasClients) {
      _movieScrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final movieState = context.read<MovieWatchlistCubit>().state;
      final addedIds = <int>{};
      if (movieState is MovieWatchlistSuccess) {
        for (var movie in movieState.movies) {
          final rawId = movie['id'];
          if (rawId is int) {
            addedIds.add(rawId);
          } else if (rawId is String) {
            final parsed = int.tryParse(rawId);
            if (parsed != null) addedIds.add(parsed);
          }
        }
      }

      List<dynamic> validResults = [];
      int retryCount = 0;

      while (validResults.length < 15 && retryCount < 10) {
        int page;
        do {
          page = _random.nextInt(250) + 1;
        } while (_seenMoviePages.contains(page));

        _seenMoviePages.add(page);
        if (_seenMoviePages.length > _maxHistory) {
          _seenMoviePages.removeAt(0);
        }

        final results = await tmdbClient.discoverMoviesWithFilters(
          page: page,
          sortBy: 'popularity.desc',
          primaryReleaseDateGte: '2020-01-01',
        );

        if (!mounted) return;

        results.shuffle(_random);
        results.removeWhere((item) => addedIds.contains(item['id']));

        for (var item in results) {
          if (validResults.length < 15 && !validResults.any((e) => e['id'] == item['id'])) {
            validResults.add(item);
          }
        }
        retryCount++;
      }

      if (mounted) {
        setState(() {
          _movies = validResults;
          _isLoadingMovies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _movieError = 'Failed to load surprises.';
          _isLoadingMovies = false;
        });
      }
    }
  }

  void _shuffleCurrentTab() {
    if (_tabController.index == 0) {
      _loadTvShows();
    } else {
      _loadMovies();
    }
  }

  Set<int> _getAddedTvIds(TvShowWatchlistState state) {
    if (state is TvShowWatchlistSuccess) {
      return state.shows.map<int>((e) {
        final id = e['id'];
        return id is int ? id : int.tryParse(id.toString()) ?? -1;
      }).toSet();
    }
    return {};
  }

  Set<int> _getAddedMovieIds(MovieWatchlistState state) {
    if (state is MovieWatchlistSuccess) {
      return state.movies.map<int>((e) {
        final id = e['id'];
        return id is int ? id : int.tryParse(id.toString()) ?? -1;
      }).toSet();
    }
    return {};
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tvScrollController.dispose();
    _movieScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Surprise Me 🎲',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'SHOWS'),
                Tab(text: 'MOVIES'),
              ],
            ),

            Expanded(
              child: Stack(
                children: [
                  TabBarView(
                    controller: _tabController,
                    children: [
                      BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                        builder: (context, tvState) {
                          final addedIds = _getAddedTvIds(tvState);
                          final displayShows = _tvShows
                              .where((item) => !addedIds.contains(item['id']))
                              .toList();
                          return _buildGrid(displayShows, _isLoadingTv, _tvError, true, _tvScrollController);
                        },
                      ),
                      BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
                        builder: (context, movieState) {
                          final addedIds = _getAddedMovieIds(movieState);
                          final displayMovies = _movies
                              .where((item) => !addedIds.contains(item['id']))
                              .toList();
                          return _buildGrid(displayMovies, _isLoadingMovies, _movieError, false, _movieScrollController);
                        },
                      ),
                    ],
                  ),

                  Positioned(
                    right: 20,
                    bottom: 30,
                    child: RollingDiceButton(
                      isRolling: _isCurrentTabLoading,
                      onPressed: _shuffleCurrentTab,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(
    List<dynamic> items,
    bool isLoading,
    String? error,
    bool isTv,
    ScrollController scrollController,
  ) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _shuffleCurrentTab,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return const _PremiumPulseGrid();
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('Nothing found.', style: TextStyle(color: Colors.white54)),
      );
    }

    return _buildGridView(items, isTv, scrollController);
  }

  Widget _buildGridView(List<dynamic> items, bool isTv, ScrollController scrollController) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['id'];
        final title = isTv ? item['name'] : item['title'];
        final posterPath = item['poster_path'];

        return GestureDetector(
          onTap: () {
            if (id == null) return;

            if (isTv) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => ShowDetailsCubit(
                      tmdbClient: context.read<TmdbClient>(),
                    ),
                    child: ShowDetailsPage(
                      mediaId: id as int,
                      mediaType: 'tv',
                      title: title ?? '',
                    ),
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MovieDetailsPage(movieId: id as int),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: posterPath != null && posterPath.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: 'https://image.tmdb.org/t/p/w342$posterPath',
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: const Color(0xFF2C2C2E)),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image, color: Colors.white24),
                  )
                : const Icon(Icons.movie, color: Colors.white24, size: 40),
          ),
        );
      },
    );
  }
}

class _PremiumPulseGrid extends StatefulWidget {
  const _PremiumPulseGrid();

  @override
  _PremiumPulseGridState createState() => _PremiumPulseGridState();
}

class _PremiumPulseGridState extends State<_PremiumPulseGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Create a diagonal wave effect based on row and column index
            final int row = index ~/ 3;
            final int col = index % 3;
            
            // Offset defines the wave pattern. Diagonal wave uses (row + col)
            final double offset = (row + col) * 0.4;
            
            // Sine wave formula: sin(2 * pi * progress - offset)
            final double wave = sin((_controller.value * 2 * pi) - offset);
            
            // Map the sine wave (-1.0 to 1.0) to an opacity range (0.2 to 0.7)
            final double opacity = 0.2 + ((wave + 1) / 2) * 0.5;
            // Map the sine wave to a scale range (0.97 to 1.03) so it pops out but doesn't touch
            final double scale = 0.97 + ((wave + 1) / 2) * 0.06;

            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3C), // Sleek metallic grey
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
