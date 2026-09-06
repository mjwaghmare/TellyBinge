import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shake/shake.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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

  /// Earliest release/air date Surprise Me will pull from, for every language.
  /// Matches the oldest option the Explore year picker offers, so a surprise
  /// can't land on something the user could never have filtered to.
  static const String _earliestDate = '1990-01-01';

  List<dynamic> _tvShows = [];
  List<dynamic> _movies = [];

  bool _isLoadingTv = true;
  bool _isLoadingMovies = true;

  String? _tvError;
  String? _movieError;

  String? _language;

  final ScrollController _tvScrollController = ScrollController();
  final ScrollController _movieScrollController = ScrollController();
  ShakeDetector? _shakeDetector;
  bool _isShakeProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: (_) {
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (!mounted ||
            !isCurrentRoute ||
            _isCurrentTabLoading ||
            _isShakeProcessing) {
          return;
        }
        _isShakeProcessing = true;
        HapticFeedback.heavyImpact();
        _shuffleCurrentTab();
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _isShakeProcessing = false;
          }
        });
      },
      minimumShakeCount: 1,
      shakeSlopTimeMS: 400,
      shakeCountResetTime: 2500,
      shakeThresholdGravity: 2.0,
    );

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
      _tvScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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

      int maxPage = 250;
      try {
        final initial = await tmdbClient.discoverTvShowsWithFiltersPaginated(
          page: 1,
          sortBy: 'popularity.desc',
          firstAirDateGte: _earliestDate,
          language: _language,
        );
        final totalPages = (initial['total_pages'] as num?)?.toInt() ?? 250;
        maxPage = totalPages.clamp(1, 500);
      } catch (e) {
        maxPage = 250;
      }

      while (validResults.length < 15 && retryCount < 10) {
        if (_seenTvPages.length >= maxPage) {
          _seenTvPages.clear();
        }

        int page;
        do {
          page = _random.nextInt(maxPage) + 1;
        } while (_seenTvPages.contains(page));

        _seenTvPages.add(page);
        if (_seenTvPages.length > _maxHistory) {
          _seenTvPages.removeAt(0);
        }

        final results = await tmdbClient.discoverTvShowsWithFilters(
          page: page,
          sortBy: 'popularity.desc',
          firstAirDateGte: _earliestDate,
          language: _language,
        );

        if (!mounted) return;

        results.shuffle(_random);
        results.removeWhere((item) => addedIds.contains(item['id']));

        for (var item in results) {
          if (validResults.length < 15 &&
              !validResults.any((e) => e['id'] == item['id'])) {
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
      _movieScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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

      int maxPage = 250;
      try {
        final initial = await tmdbClient.discoverMoviesWithFiltersPaginated(
          page: 1,
          sortBy: 'popularity.desc',
          primaryReleaseDateGte: _earliestDate,
          language: _language,
        );
        final totalPages = (initial['total_pages'] as num?)?.toInt() ?? 250;
        maxPage = totalPages.clamp(1, 500);
      } catch (e) {
        maxPage = 250;
      }

      while (validResults.length < 15 && retryCount < 10) {
        if (_seenMoviePages.length >= maxPage) {
          _seenMoviePages.clear();
        }

        int page;
        do {
          page = _random.nextInt(maxPage) + 1;
        } while (_seenMoviePages.contains(page));

        _seenMoviePages.add(page);
        if (_seenMoviePages.length > _maxHistory) {
          _seenMoviePages.removeAt(0);
        }

        final results = await tmdbClient.discoverMoviesWithFilters(
          page: page,
          sortBy: 'popularity.desc',
          primaryReleaseDateGte: _earliestDate,
          language: _language,
        );

        if (!mounted) return;

        results.shuffle(_random);
        results.removeWhere((item) => addedIds.contains(item['id']));

        for (var item in results) {
          if (validResults.length < 15 &&
              !validResults.any((e) => e['id'] == item['id'])) {
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
    _shakeDetector?.stopListening();
    _tabController.dispose();
    _tvScrollController.dispose();
    _movieScrollController.dispose();
    super.dispose();
  }

  void _applyLanguage(String language) {
    final langVal = language == 'all' ? null : language;
    if (_language != langVal) {
      setState(() {
        _language = langVal;
        _seenTvPages.clear();
        _seenMoviePages.clear();
        _tvShows.clear();
        _movies.clear();
      });
      _loadTvShows();
      _loadMovies();
    }
  }

  void _showLanguageBottomSheet() {
    String currentLanguage = _language ?? 'all';
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          (Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : AppColors.surfaceDarkAlt),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.gapH16,
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Language',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AppSpacing.gapH16,
                  _buildLanguageTile('All', 'all', currentLanguage, (val) {
                    setModalState(() => currentLanguage = val.toString());
                  }),
                  _buildLanguageTile('Hindi', 'hi', currentLanguage, (val) {
                    setModalState(() => currentLanguage = val.toString());
                  }),
                  _buildLanguageTile('Marathi', 'mr', currentLanguage, (val) {
                    setModalState(() => currentLanguage = val.toString());
                  }),
                  AppSpacing.gapH16,
                  Divider(color: Theme.of(context).dividerColor, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyLanguage('all');
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.black54
                                    : Colors.white54,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.xl,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.black87
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyLanguage(currentLanguage);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.xl,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'APPLY',
                              style: TextStyle(
                                color: AppColors.textOnPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageTile(
    String title,
    String value,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    final isSelected = value == groupValue;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: isSelected
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            )
          : Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black38
                      : Colors.white38,
                  width: 1.5,
                ),
              ),
            ),
      onTap: () => onChanged(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.grey.shade100
              : AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Surprise Me 🎲',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.gapW8,
                      IconButton(
                        onPressed: _showLanguageBottomSheet,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text(
                                '🇮🇳',
                                style: TextStyle(fontSize: 22),
                              ),
                            ),
                            if (_language != null)
                              Positioned(
                                top: 6,
                                right: 2,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade100
                                          : AppColors.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white70,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor:
                  Theme.of(context).brightness == Brightness.light
                  ? Colors.black54
                  : Colors.white54,
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
                          return _buildGrid(
                            displayShows,
                            _isLoadingTv,
                            _tvError,
                            true,
                            _tvScrollController,
                          );
                        },
                      ),
                      BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
                        builder: (context, movieState) {
                          final addedIds = _getAddedMovieIds(movieState);
                          final displayMovies = _movies
                              .where((item) => !addedIds.contains(item['id']))
                              .toList();
                          return _buildGrid(
                            displayMovies,
                            _isLoadingMovies,
                            _movieError,
                            false,
                            _movieScrollController,
                          );
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
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white54,
              ),
            ),
            AppSpacing.gapH16,
            ElevatedButton(
              onPressed: _shuffleCurrentTab,
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return const _PremiumPulseGrid();
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing found.',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black54
                : Colors.white54,
          ),
        ),
      );
    }

    return _buildGridView(items, isTv, scrollController);
  }

  Widget _buildGridView(
    List<dynamic> items,
    bool isTv,
    ScrollController scrollController,
  ) {
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final id = item['id'];
        final title = isTv ? item['name'] : item['title'];
        final posterPath = item['poster_path'];
        final voteAverage = (item['vote_average'] as num?)?.toDouble() ?? 0.0;
        final date = isTv ? item['first_air_date'] : item['release_date'];
        final year = (date != null && date.toString().length >= 4)
            ? date.toString().substring(0, 4)
            : '';

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
                  builder: (context) => MovieDetailsPage(
                    movieId: id as int,
                    title: title,
                    posterPath: posterPath as String?,
                    backdropPath: item['backdrop_path'] as String?,
                  ),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade200
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: posterPath != null && posterPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl:
                              AppConstants.tmdbImageUrl(posterPath, size: 'w342'),
                          fit: BoxFit.cover,
                          memCacheWidth: 342,
                          placeholder: (context, url) => Container(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? Colors.grey.shade200
                                : AppColors.surfaceElevated,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.broken_image,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? Colors.black26
                                : Colors.white24,
                          ),
                        )
                      : Icon(
                          Icons.movie,
                          color:
                              Theme.of(context).brightness == Brightness.light
                              ? Colors.black26
                              : Colors.white24,
                          size: 40,
                        ),
                ),
              ),
              AppSpacing.gapH4,
              Text(
                title ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    voteAverage.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  if (year.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      year,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
            ],
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
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade300
                        : AppColors.surfaceElevated, // Sleek metallic grey
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
