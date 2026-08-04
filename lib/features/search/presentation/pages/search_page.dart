import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
  bool _isTabChanging = false;
  Timer? _tabTransitionTimer;

  // Filter state for TV shows
  String _selectedSortBy = 'trending';
  String? _tvLanguage;
  String? _selectedYear;
  bool _hasActiveFilters = false;
  bool _isFetchingTvFilters = false;

  // Filter state - Movies
  String _selectedMovieSortBy = 'trending';
  String? _movieLanguage;
  String? _selectedMovieYear;
  bool _hasActiveMovieFilters = false;
  bool _isFetchingMovieFilters = false;

  int _previousTabIndex = 0;

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
        _selectedSortBy = 'trending';
        _tvLanguage = null;
        _selectedYear = null;
        _hasActiveFilters = false;
        _showsSearchController.clear();

        // Movies
        _selectedMovieSortBy = 'trending';
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
      // 1. Immediately activate shimmer at the start of transition/swipe
      if (_tabController.indexIsChanging) {
        _tabTransitionTimer?.cancel();
        setState(() {
          _isTabChanging = true;
        });
      }

      // Check if sub-tab index actually changed
      if (_tabController.index != _previousTabIndex) {
        _previousTabIndex = _tabController.index;

        // 1. Close keyboard if opened
        FocusManager.instance.primaryFocus?.unfocus();

        // 2. Clear search queries
        _showsSearchController.clear();
        _moviesSearchController.clear();

        // 3. Reset pagination & scroll position
        if (_showsScrollController.hasClients) {
          _showsScrollController.jumpTo(0);
        }
        if (_moviesScrollController.hasClients) {
          _moviesScrollController.jumpTo(0);
        }
        context.read<SearchCubit>().resetTvTrending();
        context.read<SearchCubit>().resetMoviesTrending();

        // 4. Load clean trending data for newly selected tab
        _loadTrendingWithFilters();
      } else if (!_tabController.indexIsChanging) {
        final isTv = _tabController.index == 0;
        final activeController = isTv
            ? _showsSearchController
            : _moviesSearchController;

        final trimmedQuery = activeController.text.trim();
        if (trimmedQuery.length >= 3) {
          final currentState = context.read<SearchCubit>().state;
          bool shouldSearch = true;
          if (currentState is SearchResultsSuccess) {
            if (currentState.isTv == isTv &&
                currentState.query == trimmedQuery) {
              shouldSearch = false;
            }
          }
          if (shouldSearch) {
            context.read<SearchCubit>().executeSearch(trimmedQuery, isTv: isTv);
          } else {
            setState(() {
              _isTabChanging = false;
            });
            return;
          }
        } else {
          _loadTrendingWithFilters();
        }
      }

      _tabTransitionTimer?.cancel();
      _tabTransitionTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _isTabChanging = false;
        });
      });
    });

    // Ensure trending is fetched on initial load if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrendingWithFilters();
    });

    _showsScrollController.addListener(() => _onScroll(true));
    _moviesScrollController.addListener(() => _onScroll(false));
  }

  void _loadTrendingWithFilters() {
    if (_hasActiveFilters) {
      // Apply filters when trending is loaded
      _applyFiltersToTrending();
    } else {
      context.read<SearchCubit>().loadTrending();
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

  void _showFilterBottomSheet(bool isTv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        isTv: isTv,
        selectedSortBy: isTv ? _selectedSortBy : _selectedMovieSortBy,
        selectedYear: isTv ? _selectedYear : _selectedMovieYear,
        onApply: (sortBy, year) {
          setState(() {
            if (isTv) {
              _selectedSortBy = sortBy;
              _selectedYear = year;
              _hasActiveFilters =
                  _selectedSortBy != 'trending' || _selectedYear != null;
            } else {
              _selectedMovieSortBy = sortBy;
              _selectedMovieYear = year;
              _hasActiveMovieFilters =
                  _selectedMovieSortBy != 'trending' ||
                  _selectedMovieYear != null;
            }
          });

          if (isTv) {
            // Update cubit with TV filter state for pagination
            context.read<SearchCubit>().setTvFilters(
              sortBy: sortBy,
              language: _tvLanguage,
              year: year,
            );
            _applyFiltersToTrending();
          } else {
            // Update cubit with movie filter state for pagination
            context.read<SearchCubit>().setMovieFilters(
              sortBy: sortBy,
              language: _movieLanguage,
              year: year,
            );
            _applyMovieFiltersToTrending();
          }
        },
      ),
    );
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
    _tabTransitionTimer?.cancel();
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
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          return BlocBuilder<MovieWatchlistCubit, MovieWatchlistState>(
            builder: (context, movieState) {
              return BlocBuilder<TvShowWatchlistCubit, TvShowWatchlistState>(
                builder: (context, tvState) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildShowsTab(state, tvState),
                      _buildMoviesTab(state, movieState),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShowsTab(SearchState state, TvShowWatchlistState tvState) {
    return Column(
      children: [
        _buildSearchBar(_showsSearchController, isTv: true),
        Expanded(child: _buildShowsContent(state, tvState)),
      ],
    );
  }

  Widget _buildMoviesTab(SearchState state, MovieWatchlistState movieState) {
    return Column(
      children: [
        _buildSearchBar(_moviesSearchController, isTv: false),
        Expanded(child: _buildMoviesContent(state, movieState)),
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
                        IconButton(
                          icon: Icon(
                            Icons.tune,
                            color:
                                (isTv
                                    ? _hasActiveFilters
                                    : _hasActiveMovieFilters)
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                          onPressed: () => _showFilterBottomSheet(isTv),
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
                              color: Colors.black,
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
              child: Icon(Icons.check, size: 16, color: Colors.black),
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

    if (_isTabChanging || state is SearchLoading || _isFetchingTvFilters) {
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
                  foregroundColor: Colors.black,
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
      final filteredTrending = state.trendingTv.where((item) {
        final rawId = item['id'];
        int? id;
        if (rawId is num) {
          id = rawId.toInt();
        } else if (rawId is String) {
          id = int.tryParse(rawId);
        }
        if (id == null) return false;
        return !watchlistedIds.contains(id);
      }).toList();

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
      );
    } else if (state is SearchResultsSuccess) {
      if (state.isTv) {
        return _buildGrid(
          state.results,
          'tv',
          controller: _showsScrollController,
          isLoadingMore: state.isLoadingMore,
          hasLoadMoreError: state.hasLoadMoreError,
          onRetry: () => context.read<SearchCubit>().loadMore(true),
          hasReachedMax: state.hasReachedMax,
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

    if (_isTabChanging || state is SearchLoading || _isFetchingMovieFilters) {
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
                  foregroundColor: Colors.black,
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
      final filteredTrending = state.trendingMovies.where((item) {
        final rawId = item['id'];
        int? id;
        if (rawId is num) {
          id = rawId.toInt();
        } else if (rawId is String) {
          id = int.tryParse(rawId);
        }
        if (id == null) return false;
        return !watchlistedIds.contains(id);
      }).toList();

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
  }) {
    if (items.isEmpty) {
      return Center(
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
      );
    }

    final bool hasFooter =
        isLoadingMore ||
        (hasLoadMoreError && onRetry != null) ||
        (hasReachedMax && items.isNotEmpty);

    final itemIndexMap = <int, int>{};
    for (int i = 0; i < items.length; i++) {
      final rawId = items[i]['id'];
      if (rawId is int) {
        itemIndexMap[rawId] = i;
      } else if (rawId is num) {
        itemIndexMap[rawId.toInt()] = i;
      } else if (rawId != null) {
        final parsed = int.tryParse(rawId.toString());
        if (parsed != null) itemIndexMap[parsed] = i;
      }
    }

    return CustomScrollView(
      controller: controller,
      physics: physics,
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
                String formattedDate = '';
                if (dateStr != null && dateStr.isNotEmpty) {
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
                    formattedDate = '${months[dt.month - 1]}, ${dt.year}';
                  } catch (_) {
                    if (dateStr.length >= 4) {
                      formattedDate = dateStr.substring(0, 4);
                    }
                  }
                }

                return RepaintBoundary(
                  key: ValueKey('${defaultType}_$id'),
                  child: GestureDetector(
                    onTap: () => _openDetails(id, mediaType, title),
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
                                  child: posterPath != null && posterPath.isNotEmpty
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
                                    Skeletonizer.maybeOf(context)?.enabled != true)
                                  TvShowStatusOverlay(tvId: id, index: index),
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
                            if (voteAverage > 0.0) ...[
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

  void _openDetails(int mediaId, String mediaType, String title) {
    if (mediaType == 'movie') {
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => MovieDetailsPage(movieId: mediaId),
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

class TvShowStatusOverlay extends StatefulWidget {
  final int tvId;
  final int index;

  const TvShowStatusOverlay({
    super.key,
    required this.tvId,
    required this.index,
  });

  @override
  State<TvShowStatusOverlay> createState() => _TvShowStatusOverlayState();
}

class _TvShowStatusOverlayState extends State<TvShowStatusOverlay> {
  static final Map<int, String?> _tvStatusCache = {};

  bool _showPill = false;
  bool _loaded = false;
  String _pillText = 'ENDED';
  Color _pillColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    if (_tvStatusCache.containsKey(widget.tvId)) {
      _applyStatusString(_tvStatusCache[widget.tvId] ?? '');
      _loaded = true;
    } else {
      _checkStatus();
    }
  }

  void _applyStatusString(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'ended') {
      _showPill = true;
      _pillText = 'ENDED';
      _pillColor = AppColors.error;
    } else if (normalized == 'canceled' || normalized == 'cancelled') {
      _showPill = true;
      _pillText = 'CANCELLED';
      _pillColor = AppColors.error;
    } else if (normalized == 'planned' ||
        normalized == 'in production' ||
        normalized == 'post production') {
      _showPill = true;
      _pillText = 'UPCOMING';
      _pillColor = AppColors.airing;
    } else {
      _showPill = false;
    }
  }

  Future<void> _checkStatus() async {
    try {
      final tmdbClient = context.read<TmdbClient>();
      final details = await tmdbClient.getTvShowDetails(widget.tvId);
      final String status = details['status'] ?? '';
      _tvStatusCache[widget.tvId] = status;
      if (!mounted) return;
      setState(() {
        _applyStatusString(status);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_showPill) return const SizedBox.shrink();

    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _pillColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          _pillText,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 9.0,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final bool isTv;
  final String selectedSortBy;
  final String? selectedYear;
  final Function(String sortBy, String? year) onApply;

  const _FilterBottomSheet({
    required this.isTv,
    required this.selectedSortBy,
    this.selectedYear,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _currentSortBy;
  late Map<String, String> _sortOptions;

  /// Matches the oldest decade the picker previously offered, and the floor
  /// Surprise Me uses.
  static const int _minYear = 1990;

  /// Derived from the clock, never hardcoded — the old chip list had to be
  /// hand-edited every January to stay current.
  ///
  /// Floored above [_minYear] because RangeSlider asserts on `max <= min` and
  /// on zero divisions; a device whose clock is set before 1991 would otherwise
  /// crash the filter sheet outright.
  static int get _maxYear {
    final year = DateTime.now().year;
    return year > _minYear ? year : _minYear + 1;
  }

  static RangeValues get _fullRange =>
      RangeValues(_minYear.toDouble(), _maxYear.toDouble());

  late RangeValues _yearRange;

  /// The filter value handed back to the caller. A full-span selection means
  /// "no year filter": returning null keeps the query free of date bounds, so
  /// pre-1990 titles stay reachable exactly as they were under "Any Year", and
  /// `hasSpecificFilters` in TmdbClient stays false rather than silently
  /// dropping vote_count.gte to 0 on every request.
  String? get _currentYear {
    final start = _yearRange.start.round();
    final end = _yearRange.end.round();
    if (start <= _minYear && end >= _maxYear) return null;
    return '$start-$end';
  }

  /// Inverse of [_currentYear], tolerant of the decade ("2020s") and single-year
  /// ("2026") forms the chip list used to produce.
  static RangeValues _rangeFromFilter(String? value) {
    if (value == null || value.isEmpty) return _fullRange;

    int? start;
    int? end;
    if (value.contains('-')) {
      final parts = value.split('-');
      if (parts.length == 2) {
        start = int.tryParse(parts[0].trim());
        end = int.tryParse(parts[1].trim());
      }
    } else if (value.endsWith('s')) {
      start = int.tryParse(value.substring(0, value.length - 1));
      if (start != null) end = start + 9;
    } else {
      start = int.tryParse(value);
      end = start;
    }

    if (start == null || end == null) return _fullRange;
    if (start > end) {
      final swap = start;
      start = end;
      end = swap;
    }
    return RangeValues(
      start.clamp(_minYear, _maxYear).toDouble(),
      end.clamp(_minYear, _maxYear).toDouble(),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentSortBy = widget.selectedSortBy;
    _yearRange = _rangeFromFilter(widget.selectedYear);

    _sortOptions = widget.isTv
        ? {
            'Trending': 'trending',
            'Latest': 'first_air_date.desc',
            'Popular': 'popularity.desc',
            'Airing Today': 'airing_today',
            'Upcoming': 'upcoming',
          }
        : {
            'Trending': 'trending',
            'Latest': 'primary_release_date.desc',
            'Popular': 'popularity.desc',
            'In Theaters': 'now_playing',
            'Upcoming': 'upcoming',
          };
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        8.0,
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Two-thumb year picker. Snaps per year rather than per decade so a single
  /// year stays selectable (the chip list's 2022–2026 entries), while the tick
  /// row underneath keeps the decade framing. A single continuous range can't
  /// overlap itself, which the old year/decade chips could.
  Widget _buildYearRangeSlider(bool isDark) {
    final start = _yearRange.start.round();
    final end = _yearRange.end.round();
    final isFullRange = _currentYear == null;

    // Decade marks, plus the current year so the right end of the track is
    // labelled. Dropped when a decade boundary already sits near it, which
    // happens on turn-of-decade years.
    final decades = <int>[
      for (var y = _minYear; y <= _maxYear; y += 10)
        if (_maxYear - y >= 4) y,
      _maxYear,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isFullRange
                    ? 'Any Year'
                    : (start == end ? '$start' : '$start – $end'),
                style: TextStyle(
                  color: isFullRange
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!isFullRange)
                GestureDetector(
                  onTap: () => setState(() => _yearRange = _fullRange),
                  child: Text(
                    'Any Year',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          RangeSlider(
            values: _yearRange,
            min: _minYear.toDouble(),
            max: _maxYear.toDouble(),
            divisions: _maxYear - _minYear,
            labels: RangeLabels('$start', '$end'),
            activeColor: AppColors.primary,
            inactiveColor: isDark ? Colors.white24 : Colors.black26,
            onChanged: (values) => setState(() => _yearRange = values),
          ),
          // Positioned proportionally rather than evenly spaced: the final
          // stretch is a partial decade (2020→2026 today), so an even Row would
          // put each label somewhere the track doesn't actually sit.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final span = (_maxYear - _minYear).toDouble();
                return SizedBox(
                  height: 14,
                  child: Stack(
                    children: [
                      for (final tick in decades)
                        Positioned(
                          left:
                              (((tick - _minYear) / span) *
                                          constraints.maxWidth -
                                      14)
                                  .clamp(0.0, constraints.maxWidth - 28),
                          child: SizedBox(
                            width: 28,
                            child: Text(
                              '$tick',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilter =
        _currentSortBy != 'trending' || _currentYear != null;

    return Material(
      color:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          (isDark ? AppColors.surface : Colors.white),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header & Reset Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter & Sort',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasActiveFilter)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentSortBy = 'trending';
                            _yearRange = _fullRange;
                          });
                          widget.onApply('trending', null);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AppSpacing.gapH12,
              Divider(color: Theme.of(context).dividerColor, height: 1),

              AppSpacing.gapH8,
              // Sort by Section
              _buildSectionHeader('Sort by'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _sortOptions.entries.map((entry) {
                    final label = entry.key;
                    final value = entry.value;
                    final isSelected = _currentSortBy == value;

                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          _currentSortBy = value;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 9.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.surfaceLight
                                    : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white12 : Colors.black12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : (isDark ? Colors.white : Colors.black87),
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              AppSpacing.gapH16,
              // Release Year Section
              _buildSectionHeader('Release Year'),
              _buildYearRangeSlider(isDark),

              const SizedBox(height: 24),
              // Apply Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_currentSortBy, _currentYear);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.xl),
                      ),
                    ),
                    child: const Text(
                      'APPLY FILTERS',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              AppSpacing.gapH8,
            ],
          ),
        ),
      ),
    );
  }
}
