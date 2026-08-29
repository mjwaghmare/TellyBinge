import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/tmdb_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../show_details/presentation/cubit/show_details_cubit.dart';
import '../../../show_details/presentation/pages/show_details_page.dart';
import '../../../explore/presentation/pages/movie_details_page.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../cubit/tv_status_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../../../movies/presentation/cubit/movie_watchlist_state.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../../../dashboard/presentation/cubit/tv_show_watchlist_state.dart';

class SearchPage extends StatefulWidget {
  final ValueNotifier<int>? subTabNotifier;
  final ValueNotifier<int>? mainTabNotifier;
  const SearchPage({super.key, this.subTabNotifier, this.mainTabNotifier});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _showsSearchController = TextEditingController();
  final TextEditingController _moviesSearchController = TextEditingController();
  final ScrollController _showsScrollController = ScrollController();
  final ScrollController _moviesScrollController = ScrollController();
  late TabController _tabController;

  static final Map<String, String> _gridFormattedDateCache = {};

  static String _formatGridDateCached(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    return _gridFormattedDateCache.putIfAbsent(dateStr, () {
      try {
        final dt = DateTime.parse(dateStr);
        const months = [
          'JAN',
          'FEB',
          'MAR',
          'APR',
          'MAY',
          'JUN',
          'JUL',
          'AUG',
          'SEP',
          'OCT',
          'NOV',
          'DEC',
        ];
        return '${months[dt.month - 1]}, ${dt.year}';
      } catch (_) {
        return dateStr.length >= 4 ? dateStr.substring(0, 4) : '';
      }
    });
  }

  // Filter state for TV shows
  String _selectedSortBy = SearchCubit.tvLatestSort;
  String? _tvLanguage;
  String? _selectedYear;
  bool _hasActiveFilters = false;
  bool _isFetchingTvFilters = false;

  // Filter state - Movies
  String _selectedMovieSortBy = SearchCubit.movieLatestSort;
  String? _movieLanguage;
  String? _selectedMovieYear;
  bool _hasActiveMovieFilters = false;
  bool _isFetchingMovieFilters = false;

  int _previousTabIndex = 0;

  final _FilteredGrid _showsGrid = _FilteredGrid();
  final _FilteredGrid _moviesGrid = _FilteredGrid();

  /// TV search results get the same treatment as trending: a memoized index map
  /// plus change detection, so status lookups are queued once per new page
  /// rather than on every rebuild. No exclusions apply here.
  final _FilteredGrid _showsSearchGrid = _FilteredGrid();

  /// Queues status lookups after the frame, so a build never triggers a fetch.
  void _queueTvStatuses(Iterable<int> ids) {
    final pending = ids.toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TvStatusCubit>().resolveAll(pending);
    });
  }

  void _handleSubTabChange() {
    if (widget.subTabNotifier != null &&
        _tabController.index != widget.subTabNotifier!.value) {
      _tabController.animateTo(widget.subTabNotifier!.value);
    }
  }

  void _resetAllFiltersAndSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    bool needsRefresh = false;

    if (_hasActiveFilters ||
        _hasActiveMovieFilters ||
        _showsSearchController.text.isNotEmpty ||
        _moviesSearchController.text.isNotEmpty ||
        _tvLanguage != null ||
        _movieLanguage != null ||
        _selectedYear != null ||
        _selectedMovieYear != null) {
      needsRefresh = true;
    }

    if (_showsScrollController.hasClients) {
      _showsScrollController.jumpTo(0);
    }
    if (_moviesScrollController.hasClients) {
      _moviesScrollController.jumpTo(0);
    }

    if (needsRefresh) {
      setState(() {
        // TV
        _selectedSortBy = SearchCubit.tvLatestSort;
        _tvLanguage = null;
        _selectedYear = null;
        _hasActiveFilters = false;
        _showsSearchController.clear();

        // Movies
        _selectedMovieSortBy = SearchCubit.movieLatestSort;
        _movieLanguage = null;
        _selectedMovieYear = null;
        _hasActiveMovieFilters = false;
        _moviesSearchController.clear();
      });

      if (mounted) {
        context.read<SearchCubit>().clearTvFilters();
        context.read<SearchCubit>().clearMovieFilters();
        context.read<SearchCubit>().resetTvTrending();
        context.read<SearchCubit>().resetMoviesTrending();
      }
    }
  }

  void _handleMainTabChange() {
    if (widget.mainTabNotifier != null && widget.mainTabNotifier!.value != 2) {
      _resetAllFiltersAndSearch();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.mainTabNotifier != null) {
      widget.mainTabNotifier!.addListener(_handleMainTabChange);
    }
    _tabController = TabController(length: 2, vsync: this);
    if (widget.subTabNotifier != null) {
      _tabController.index = widget.subTabNotifier!.value;
      widget.subTabNotifier!.addListener(_handleSubTabChange);
    }
    _previousTabIndex = _tabController.index;

    _tabController.addListener(() {
      if (_tabController.index != _previousTabIndex) {
        _previousTabIndex = _tabController.index;

        // 1. Unfocus keyboard when switching subtabs
        FocusManager.instance.primaryFocus?.unfocus();

        // 2. Adjust search state if necessary without wiping controller text
        final isTv = _tabController.index == 0;
        final activeController =
            isTv ? _showsSearchController : _moviesSearchController;
        final trimmedQuery = activeController.text.trim();

        if (trimmedQuery.length >= 3) {
          final currentState = context.read<SearchCubit>().state;
          bool shouldSearch = true;
          if (currentState is SearchResultsSuccess &&
              currentState.isTv == isTv &&
              currentState.query == trimmedQuery) {
            shouldSearch = false;
          }
          if (shouldSearch) {
            context.read<SearchCubit>().executeSearch(trimmedQuery, isTv: isTv);
          }
        } else {
          final currentState = context.read<SearchCubit>().state;
          if (currentState is SearchResultsSuccess &&
              currentState.isTv != isTv) {
            _loadTrendingWithFilters(isTv: isTv);
          }
        }
      }
    });

    // Ensure trending is fetched on initial load if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrendingWithFilters(isTv: _tabController.index == 0);
    });

    _showsScrollController.addListener(() => _onScroll(true));
    _moviesScrollController.addListener(() => _onScroll(false));
  }

  void _loadTrendingWithFilters({bool isTv = true}) {
    if (isTv) {
      final hasActiveExtra = _tvLanguage != null || _selectedYear != null;
      if (_hasActiveFilters || hasActiveExtra) {
        _applyFiltersToTrending();
      } else {
        context.read<SearchCubit>().loadTrending();
      }
    } else {
      final hasActiveMovieExtra =
          _movieLanguage != null || _selectedMovieYear != null;
      if (_hasActiveMovieFilters || hasActiveMovieExtra) {
        _applyMovieFiltersToTrending();
      } else {
        context.read<SearchCubit>().loadTrending();
      }
    }
  }

  Future<void> _applyFiltersToTrending() async {
    setState(() {
      _isFetchingTvFilters = true;
    });

    if (_showsScrollController.hasClients) {
      _showsScrollController.jumpTo(0);
    }

    final hasActiveExtra = _tvLanguage != null || _selectedYear != null;
    final hasActive = _hasActiveFilters || hasActiveExtra;

    if (!hasActive) {
      if (!mounted) return;
      context.read<SearchCubit>().resetTvTrending();
      setState(() {
        _isFetchingTvFilters = false;
      });
      return;
    }

    // Immediately clear previous TV results so skeleton loader shows fresh state
    context.read<SearchCubit>().clearTrendingTvResults();

    try {
      final tmdbClient = context.read<TmdbClient>();
      List<dynamic> filteredShows = [];

      if (_selectedSortBy == 'airing_today' && !hasActiveExtra) {
        filteredShows = await tmdbClient.getAiringTodayTvShows();
      } else if (_selectedSortBy == 'upcoming' && !hasActiveExtra) {
        filteredShows = await tmdbClient.getUpcomingTvShows();
      } else {
        final effectiveSortBy =
            (_selectedSortBy == 'trending' ||
                _selectedSortBy == 'popularity.desc')
            ? 'popularity.desc'
            : (_selectedSortBy == 'airing_today' ||
                      _selectedSortBy == 'upcoming'
                  ? 'first_air_date.desc'
                  : _selectedSortBy);
        filteredShows = await tmdbClient.discoverTvShowsWithFilters(
          sortBy: effectiveSortBy,
          language: _tvLanguage,
          year: _selectedYear,
        );
      }

      if (!mounted) return;
      // Update the search cubit with filtered results
      context.read<SearchCubit>().updateTrendingTv(filteredShows);
    } catch (e) {
      debugPrint('Error applying TV filters: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingTvFilters = false;
        });
      }
    }
  }

  Future<void> _applyMovieFiltersToTrending() async {
    setState(() {
      _isFetchingMovieFilters = true;
    });

    if (_moviesScrollController.hasClients) {
      _moviesScrollController.jumpTo(0);
    }

    final hasActiveMovieExtra =
        _movieLanguage != null || _selectedMovieYear != null;
    final hasActive = _hasActiveMovieFilters || hasActiveMovieExtra;

    if (!hasActive) {
      if (!mounted) return;
      context.read<SearchCubit>().resetMoviesTrending();
      setState(() {
        _isFetchingMovieFilters = false;
      });
      return;
    }

    // Immediately clear previous Movie results so skeleton loader shows fresh state
    context.read<SearchCubit>().clearTrendingMovieResults();

    try {
      final tmdbClient = context.read<TmdbClient>();
      List<dynamic> filteredMovies = [];

      if (_selectedMovieSortBy == 'now_playing' && !hasActiveMovieExtra) {
        filteredMovies = await tmdbClient.getNowPlayingMovies();
      } else if (_selectedMovieSortBy == 'upcoming' && !hasActiveMovieExtra) {
        filteredMovies = await tmdbClient.getUpcomingMovies();
      } else {
        final effectiveSortBy =
            (_selectedMovieSortBy == 'trending' ||
                _selectedMovieSortBy == 'popularity.desc')
            ? 'popularity.desc'
            : (_selectedMovieSortBy == 'now_playing' ||
                      _selectedMovieSortBy == 'upcoming'
                  ? 'primary_release_date.desc'
                  : _selectedMovieSortBy);
        filteredMovies = await tmdbClient.discoverMoviesWithFilters(
          sortBy: effectiveSortBy,
          language: _movieLanguage,
          year: _selectedMovieYear,
        );
      }

      if (!mounted) return;
      // Update the search cubit with filtered results
      context.read<SearchCubit>().updateTrendingMovies(filteredMovies);
    } catch (e) {
      debugPrint('Error applying Movie filters: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingMovieFilters = false;
        });
      }
    }
  }



  void _onScroll(bool isTv) {
    final controller = isTv ? _showsScrollController : _moviesScrollController;
    if (!controller.hasClients) return;

    final currentState = context.read<SearchCubit>().state;
    if (currentState is SearchTrendingSuccess) {
      if (currentState.isLoadingMore) return;
      final hasReachedMax = isTv
          ? currentState.tvHasReachedMax
          : currentState.moviesHasReachedMax;
      if (hasReachedMax) return;
    } else if (currentState is SearchResultsSuccess) {
      if (currentState.isLoadingMore || currentState.hasReachedMax) return;
    }

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 400) {
      context.read<SearchCubit>().loadMore(isTv);
    }
  }

  @override
  void dispose() {
    widget.subTabNotifier?.removeListener(_handleSubTabChange);
    widget.mainTabNotifier?.removeListener(_handleMainTabChange);
    _showsSearchController.dispose();
    _moviesSearchController.dispose();
    _showsScrollController.dispose();
    _moviesScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getImageUrl(String? path, {String size = 'w185'}) {
    if (path == null || path.isEmpty) return '';
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight:
            0, // Hide main toolbar for clean view, matching dashboard
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SHOWS'),
            Tab(text: 'MOVIES'),
          ],
        ),
      ),
      // Each tab owns its BlocBuilders rather than sharing one set above the
      // TabBarView. Nesting them above meant every emit from any of the three
      // cubits eagerly re-ran both tabs' filtering and index-map work, even for
      // the tab that is off screen. Scoped this way, a watchlist change only
      // touches its own tab, and the off-screen tab's work is deferred until
      // that tab is actually built.
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAliveTab(
            key: const PageStorageKey('explore_shows_tab'),
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                  builder: (context, tvState) => _buildShowsTab(state, tvState),
                );
              },
            ),
          ),
          _KeepAliveTab(
            key: const PageStorageKey('explore_movies_tab'),
            child: BlocBuilder<SearchCubit, SearchState>(
              builder: (context, state) {
                return BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
                  builder: (context, movieState) =>
                      _buildMoviesTab(state, movieState),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowsTab(SearchState state, TvShowWatchlistState tvState) {
    return Column(
      children: [
        _buildSearchBar(_showsSearchController, isTv: true),
        Expanded(
          child: RefreshIndicator.adaptive(
            color: AppColors.primary,
            backgroundColor: Theme.of(context).cardColor,
            onRefresh: () async {
              final trimmedQuery = _showsSearchController.text.trim();
              if (trimmedQuery.length >= 3) {
                await context.read<SearchCubit>().executeSearch(
                  trimmedQuery,
                  isTv: true,
                );
              } else if (_hasActiveFilters ||
                  _tvLanguage != null ||
                  _selectedYear != null) {
                await _applyFiltersToTrending();
              } else {
                await context.read<SearchCubit>().refreshFeed(isTv: true);
              }
            },
            child: _buildShowsContent(state, tvState),
          ),
        ),
      ],
    );
  }

  Widget _buildMoviesTab(SearchState state, MovieWatchlistState movieState) {
    return Column(
      children: [
        _buildSearchBar(_moviesSearchController, isTv: false),
        Expanded(
          child: RefreshIndicator.adaptive(
            color: AppColors.primary,
            backgroundColor: Theme.of(context).cardColor,
            onRefresh: () async {
              final trimmedQuery = _moviesSearchController.text.trim();
              if (trimmedQuery.length >= 3) {
                await context.read<SearchCubit>().executeSearch(
                  trimmedQuery,
                  isTv: false,
                );
              } else if (_hasActiveMovieFilters ||
                  _movieLanguage != null ||
                  _selectedMovieYear != null) {
                await _applyMovieFiltersToTrending();
              } else {
                await context.read<SearchCubit>().refreshFeed(isTv: false);
              }
            },
            child: _buildMoviesContent(state, movieState),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    TextEditingController controller, {
    required bool isTv,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (val) {
                context.read<SearchCubit>().onSearchTextChanged(
                  val,
                  isTv: isTv,
                );
              },
              decoration: InputDecoration(
                hintText: isTv ? 'Search shows...' : 'Search movies...',
                prefixIcon: Icon(
                  Icons.search,
                  color: context.adaptiveColor(
                    light: Colors.grey[500]!,
                    dark: AppColors.textTertiary,
                  ),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (value.text.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.clear,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey[500]
                                  : AppColors.textTertiary,
                            ),
                            onPressed: () {
                              controller.clear();
                              context.read<SearchCubit>().onSearchTextChanged(
                                '',
                                isTv: isTv,
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: () => _showLanguageBottomSheet(isTv, controller.text),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text('🇮🇳', style: TextStyle(fontSize: 22)),
                ),
                if (isTv ? _tvLanguage != null : _movieLanguage != null)
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
                          color: Theme.of(context).scaffoldBackgroundColor,
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
    );
  }

  void _showLanguageBottomSheet(bool isTv, String searchText) {
    String currentLanguage = (isTv ? _tvLanguage : _movieLanguage) ?? 'all';
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Text(
                    'Language',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildLanguageTile('All', 'all', currentLanguage, (val) {
                  setModalState(() => currentLanguage = val.toString());
                }),
                _buildLanguageTile('Hindi', 'hi', currentLanguage, (val) {
                  setModalState(() => currentLanguage = val.toString());
                }),
                _buildLanguageTile('Marathi', 'mr', currentLanguage, (val) {
                  setModalState(() => currentLanguage = val.toString());
                }),
                const SizedBox(height: AppSpacing.md),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _applyLanguage(isTv, 'all', searchText);
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
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _applyLanguage(isTv, currentLanguage, searchText);
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
      ),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 0,
      ),
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

  void _applyLanguage(bool isTv, String language, String searchText) {
    final langVal = language == 'all' ? null : language;
    setState(() {
      if (isTv) {
        _tvLanguage = langVal;
      } else {
        _movieLanguage = langVal;
      }
    });

    if (isTv) {
      context.read<SearchCubit>().setTvFilters(
        sortBy: _selectedSortBy,
        language: _tvLanguage,
        year: _selectedYear,
      );
      if (searchText.trim().isNotEmpty) {
        context.read<SearchCubit>().onSearchTextChanged(searchText, isTv: true);
      } else {
        _applyFiltersToTrending();
      }
    } else {
      context.read<SearchCubit>().setMovieFilters(
        sortBy: _selectedMovieSortBy,
        language: _movieLanguage,
        year: _selectedMovieYear,
      );
      if (searchText.trim().isNotEmpty) {
        context.read<SearchCubit>().onSearchTextChanged(
          searchText,
          isTv: false,
        );
      } else {
        _applyMovieFiltersToTrending();
      }
    }
  }

  Widget _buildShowsContent(SearchState state, TvShowWatchlistState tvState) {
    // Get watchlisted TV show IDs
    final Set<int> watchlistedIds = {};
    if (tvState is TvShowWatchlistSuccess) {
      for (final show in tvState.shows) {
        final rawId = show['id'];
        int? id;
        if (rawId is num) {
          id = rawId.toInt();
        } else if (rawId is String) {
          id = int.tryParse(rawId);
        }
        if (id != null) {
          watchlistedIds.add(id);
        }
      }
    }

    if (state is SearchLoading || _isFetchingTvFilters) {
      return Skeletonizer(
        enabled: true,
        child: _buildGrid(
          List.generate(
            9,
            (index) => {
              'name': 'Loading Show Title',
              'vote_average': 9.9,
              'id': index,
            },
          ),
          'tv',
          physics: const NeverScrollableScrollPhysics(),
        ),
      );
    } else if (state is SearchError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading data: ${state.message}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => context.read<SearchCubit>().loadTrending(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                ),
                child: Text(
                  'RETRY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (state is SearchTrendingSuccess) {
      // Filter out watchlisted shows from trending
      _showsGrid.update(state.trendingTv, watchlistedIds);
      final filteredTrending = _showsGrid.items;
      if (_showsGrid.didChange) {
        _queueTvStatuses(_showsGrid.indexById.keys);
      }

      if (filteredTrending.length < 12 &&
          !state.isLoadingMore &&
          !state.tvHasReachedMax &&
          state.tvPage < 500) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<SearchCubit>().loadMore(true);
          }
        });
      }

      return _buildGrid(
        filteredTrending,
        'tv',
        controller: _showsScrollController,
        isLoadingMore: state.isLoadingMore,
        hasLoadMoreError: state.tvLoadMoreError,
        onRetry: () => context.read<SearchCubit>().loadMore(true),
        hasReachedMax: state.tvHasReachedMax,
        indexById: _showsGrid.indexById,
      );
    } else if (state is SearchResultsSuccess) {
      if (state.isTv) {
        _showsSearchGrid.update(state.results, const <int>{});
        if (_showsSearchGrid.didChange) {
          _queueTvStatuses(_showsSearchGrid.indexById.keys);
        }
        return _buildGrid(
          _showsSearchGrid.items,
          'tv',
          controller: _showsScrollController,
          isLoadingMore: state.isLoadingMore,
          hasLoadMoreError: state.hasLoadMoreError,
          onRetry: () => context.read<SearchCubit>().loadMore(true),
          hasReachedMax: state.hasReachedMax,
          indexById: _showsSearchGrid.indexById,
        );
      } else {
        // State holds movie search results; shows tab should render shimmer skeleton
        return Skeletonizer(
          enabled: true,
          child: _buildGrid(
            List.generate(
              9,
              (index) => {
                'name': 'Loading Show Title',
                'vote_average': 9.9,
                'id': index,
              },
            ),
            'tv',
            physics: const NeverScrollableScrollPhysics(),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildMoviesContent(
    SearchState state,
    MovieWatchlistState movieState,
  ) {
    // Get watchlisted movie IDs
    final Set<int> watchlistedIds = {};
    if (movieState is MovieWatchlistSuccess) {
      for (final movie in movieState.movies) {
        final rawId = movie['id'];
        int? id;
        if (rawId is num) {
          id = rawId.toInt();
        } else if (rawId is String) {
          id = int.tryParse(rawId);
        }
        if (id != null) {
          watchlistedIds.add(id);
        }
      }
    }

    if (state is SearchLoading || _isFetchingMovieFilters) {
      return Skeletonizer(
        enabled: true,
        child: _buildGrid(
          List.generate(
            9,
            (index) => {
              'title': 'Loading Movie Title',
              'vote_average': 9.9,
              'id': index,
            },
          ),
          'movie',
          physics: const NeverScrollableScrollPhysics(),
        ),
      );
    } else if (state is SearchError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Error loading data: ${state.message}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => context.read<SearchCubit>().loadTrending(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.xl),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.sm,
                  ),
                ),
                child: Text(
                  'RETRY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (state is SearchTrendingSuccess) {
      // Filter out watchlisted movies from trending
      _moviesGrid.update(state.trendingMovies, watchlistedIds);
      final filteredTrending = _moviesGrid.items;

      if (filteredTrending.length < 12 &&
          !state.isLoadingMore &&
          !state.moviesHasReachedMax &&
          state.moviesPage < 500) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<SearchCubit>().loadMore(false);
          }
        });
      }

      return _buildGrid(
        filteredTrending,
        'movie',
        controller: _moviesScrollController,
        isLoadingMore: state.isLoadingMore,
        hasLoadMoreError: state.moviesLoadMoreError,
        onRetry: () => context.read<SearchCubit>().loadMore(false),
        hasReachedMax: state.moviesHasReachedMax,
        indexById: _moviesGrid.indexById,
      );
    } else if (state is SearchResultsSuccess) {
      if (!state.isTv) {
        return _buildGrid(
          state.results,
          'movie',
          controller: _moviesScrollController,
          isLoadingMore: state.isLoadingMore,
          hasLoadMoreError: state.hasLoadMoreError,
          onRetry: () => context.read<SearchCubit>().loadMore(false),
          hasReachedMax: state.hasReachedMax,
        );
      } else {
        // State holds tv search results; movies tab should render shimmer skeleton
        return Skeletonizer(
          enabled: true,
          child: _buildGrid(
            List.generate(
              9,
              (index) => {
                'title': 'Loading Movie Title',
                'vote_average': 9.9,
                'id': index,
              },
            ),
            'movie',
            physics: const NeverScrollableScrollPhysics(),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildGrid(
    List<dynamic> items,
    String defaultType, {
    ScrollPhysics? physics,
    ScrollController? controller,
    bool isLoadingMore = false,
    bool hasLoadMoreError = false,
    VoidCallback? onRetry,
    bool hasReachedMax = false,
    Map<int, int>? indexById,
  }) {
    if (items.isEmpty) {
      return CustomScrollView(
        controller: controller,
        physics: physics ?? const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.bottomTabPadding,
                ),
                child: Text(
                  'No results found.\nTry searching for something else.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[500]
                        : AppColors.textTertiary,
                    fontSize: 16.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final bool hasFooter =
        isLoadingMore ||
        (hasLoadMoreError && onRetry != null) ||
        (hasReachedMax && items.isNotEmpty);

    final itemIndexMap = indexById ?? _FilteredGrid.indexOf(items);

    return CustomScrollView(
      controller: controller,
      physics: physics ?? const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            12.0,
            12.0,
            12.0,
            hasFooter ? 12.0 : AppSpacing.bottomTabPadding,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                final String title = item['name'] ?? item['title'] ?? 'Unknown';
                final String? posterPath = item['poster_path'];
                final double voteAverage =
                    (item['vote_average'] as num?)?.toDouble() ?? 0.0;
                final int id = item['id'];
                final String mediaType = item['media_type'] ?? defaultType;
                final String? dateStr =
                    item['release_date'] ?? item['first_air_date'];
                final String formattedDate = _formatGridDateCached(dateStr);

                return RepaintBoundary(
                  key: ValueKey('${defaultType}_$id'),
                  child: GestureDetector(
                    onTap: () => _openDetails(
                      id,
                      mediaType,
                      title,
                      posterPath: posterPath,
                      backdropPath: item['backdrop_path'] as String?,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster Image
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey[200]
                                      : AppColors.surfaceLight,
                                  width: double.infinity,
                                  height: double.infinity,
                                  child:
                                      posterPath != null &&
                                          posterPath.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: _getImageUrl(posterPath),
                                          fit: BoxFit.cover,
                                          memCacheWidth: 250,
                                          placeholder: (context, url) =>
                                              const SizedBox.shrink(),
                                          errorWidget: (context, url, error) =>
                                              Skeleton.ignore(
                                                child: Icon(
                                                  Icons.movie_creation_outlined,
                                                  size: 32,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.light
                                                      ? Colors.grey[500]
                                                      : AppColors.textTertiary,
                                                ),
                                              ),
                                        )
                                      : Skeleton.ignore(
                                          child: Icon(
                                            Icons.movie_creation_outlined,
                                            size: 32,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? Colors.grey[500]
                                                : AppColors.textTertiary,
                                          ),
                                        ),
                                ),
                                if (mediaType == 'tv' &&
                                    Skeletonizer.maybeOf(context)?.enabled !=
                                        true)
                                  _TvStatusPill(tvId: id),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Rating & Release Date row
                        Row(
                          children: [
                            if (voteAverage >= 1.0) ...[
                              Icon(
                                Icons.star,
                                color: AppColors.primary,
                                size: 10.0,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                voteAverage.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 10.0,
                                  color:
                                      Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color ??
                                      AppColors.textSecondary,
                                ),
                              ),
                              if (formattedDate.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 10.0,
                                    color:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color ??
                                        AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    formattedDate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.0,
                                      color:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color ??
                                          AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ] else if (formattedDate.isNotEmpty) ...[
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.0,
                                    color:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color ??
                                        AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: items.length,
              findChildIndexCallback: (Key key) {
                if (key is ValueKey<String>) {
                  final keyStr = key.value;
                  final prefix = '${defaultType}_';
                  if (keyStr.startsWith(prefix)) {
                    final id = int.tryParse(keyStr.substring(prefix.length));
                    if (id != null) return itemIndexMap[id];
                  }
                }
                return null;
              },
            ),
          ),
        ),
        if (isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: 16.0,
                bottom: AppSpacing.bottomTabPadding,
              ),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        if (hasLoadMoreError && onRetry != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 16.0,
                bottom: AppSpacing.bottomTabPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load more data.',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey[500]
                          : AppColors.textTertiary,
                      fontSize: 14.0,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasReachedMax && items.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 16.0,
                bottom: AppSpacing.bottomTabPadding,
              ),
              child: Center(
                child: Text(
                  defaultType == 'tv'
                      ? 'No more shows to load'
                      : 'No more movies to load',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[500]
                        : AppColors.textTertiary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openDetails(
    int mediaId,
    String mediaType,
    String title, {
    String? posterPath,
    String? backdropPath,
  }) {
    if (mediaType == 'movie') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsPage(
            movieId: mediaId,
            title: title,
            posterPath: posterPath,
            backdropPath: backdropPath,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BlocProvider<ShowDetailsCubit>(
            create: (context) =>
                ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
            child: ShowDetailsPage(
              mediaId: mediaId,
              mediaType: mediaType,
              title: title,
            ),
          ),
        ),
      );
    }
  }
}

/// Status pill over a TV poster.
///
/// A pure lookup — it never fetches. [TvStatusCubit] resolves statuses in the
/// background when a page arrives, and the selector narrows the rebuild to this
/// one show, so a batch of resolutions only repaints the tiles it actually
/// answered rather than the whole grid.
class _TvStatusPill extends StatelessWidget {
  const _TvStatusPill({required this.tvId});

  final int tvId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      TvStatusCubit,
      Map<int, TvStatusLabel?>,
      TvStatusLabel?
    >(
      selector: (statuses) => statuses[tvId],
      builder: (context, label) {
        if (label == null) {
          // Kept positioned so the Stack's children stay uniformly positioned.
          return const Positioned(top: 6, right: 6, child: SizedBox.shrink());
        }
        final (String text, Color color) = switch (label) {
          TvStatusLabel.ended => ('ENDED', AppColors.error),
          TvStatusLabel.cancelled => ('CANCELLED', AppColors.error),
          TvStatusLabel.upcoming => ('UPCOMING', AppColors.airing),
        };
        return Positioned(
          top: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 9.0,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Caches the watchlist-filtered list and its id -> index map for one grid.
///
/// Both are O(n) over a trending list that grows with every page fetched, and
/// they were being recomputed on every rebuild — including the two emits that
/// each `loadMore` produces while you are mid-fling. Recomputing allocates a
/// fresh List and HashMap each time, so the cost showed up as GC pressure as
/// much as raw CPU. Keyed on source identity, so it recomputes only when the
/// cubit actually hands over a new list or the watchlist changes.
class _FilteredGrid {
  List<dynamic>? _sourceItems;
  Set<int>? _excludedIds;

  List<dynamic>? _items;
  Map<int, int>? _indexById;

  List<dynamic> get items => _items!;
  Map<int, int> get indexById => _indexById!;

  /// True when the most recent [update] actually recomputed. Lets the caller
  /// react to a genuinely new list — queueing status lookups, say — without
  /// firing on every rebuild.
  bool didChange = false;

  static int? _idOf(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  /// Builds the id -> index map for an arbitrary list (skeleton placeholders and
  /// raw search results, which are short enough not to need caching).
  static Map<int, int> indexOf(List<dynamic> items) {
    final map = <int, int>{};
    for (int i = 0; i < items.length; i++) {
      final id = _idOf(items[i]['id']);
      if (id != null) map[id] = i;
    }
    return map;
  }

  void update(List<dynamic> sourceItems, Set<int> excludedIds) {
    final unchanged =
        _items != null &&
        identical(_sourceItems, sourceItems) &&
        _excludedIds!.length == excludedIds.length &&
        _excludedIds!.containsAll(excludedIds);
    didChange = !unchanged;
    if (unchanged) return;

    final filtered = <dynamic>[];
    final index = <int, int>{};
    for (final item in sourceItems) {
      final id = _idOf(item['id']);
      if (id == null || excludedIds.contains(id)) continue;
      index[id] = filtered.length;
      filtered.add(item);
    }

    _sourceItems = sourceItems;
    _excludedIds = excludedIds;
    _items = filtered;
    _indexById = index;
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({super.key, required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
