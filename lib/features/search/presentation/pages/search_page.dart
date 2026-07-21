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
  List<int> _selectedGenreIds = [];
  String? _tvLanguage;
  bool _hasActiveFilters = false;
  bool _isFetchingTvFilters = false;

  static const List<Map<String, dynamic>> _tvGenres = [
    {'id': 10759, 'name': 'Action & Adventure'},
    {'id': 16, 'name': 'Animation'},
    {'id': 35, 'name': 'Comedy'},
    {'id': 80, 'name': 'Crime'},
    {'id': 99, 'name': 'Documentary'},
    {'id': 18, 'name': 'Drama'},
    {'id': 10751, 'name': 'Family'},
    {'id': 10762, 'name': 'Kids'},
    {'id': 9648, 'name': 'Mystery'},
    {'id': 10763, 'name': 'News'},
    {'id': 10764, 'name': 'Reality'},
    {'id': 10765, 'name': 'Sci-Fi & Fantasy'},
    {'id': 10766, 'name': 'Soap'},
    {'id': 10767, 'name': 'Talk'},
    {'id': 10768, 'name': 'War & Politics'},
    {'id': 37, 'name': 'Western'},
  ];

  // Filter state - Movies
  String _selectedMovieSortBy = 'trending';
  List<int> _selectedMovieGenreIds = [];
  String? _movieLanguage;
  bool _hasActiveMovieFilters = false;
  bool _isFetchingMovieFilters = false;

  static const List<Map<String, dynamic>> _movieGenres = [
    {'id': 28, 'name': 'Action'},
    {'id': 12, 'name': 'Adventure'},
    {'id': 16, 'name': 'Animation'},
    {'id': 35, 'name': 'Comedy'},
    {'id': 80, 'name': 'Crime'},
    {'id': 99, 'name': 'Documentary'},
    {'id': 18, 'name': 'Drama'},
    {'id': 10751, 'name': 'Family'},
    {'id': 14, 'name': 'Fantasy'},
    {'id': 36, 'name': 'History'},
    {'id': 27, 'name': 'Horror'},
    {'id': 10402, 'name': 'Music'},
    {'id': 9648, 'name': 'Mystery'},
    {'id': 10749, 'name': 'Romance'},
    {'id': 878, 'name': 'Science Fiction'},
    {'id': 10770, 'name': 'TV Movie'},
    {'id': 53, 'name': 'Thriller'},
    {'id': 10752, 'name': 'War'},
    {'id': 37, 'name': 'Western'},
  ];

  void _handleSubTabChange() {
    if (widget.subTabNotifier != null &&
        _tabController.index != widget.subTabNotifier!.value) {
      _tabController.animateTo(widget.subTabNotifier!.value);
    }
  }

  void _resetAllFiltersAndSearch() {
    bool needsRefresh = false;

    if (_hasActiveFilters ||
        _hasActiveMovieFilters ||
        _showsSearchController.text.isNotEmpty ||
        _moviesSearchController.text.isNotEmpty ||
        _tvLanguage != null ||
        _movieLanguage != null) {
      needsRefresh = true;
    }

    if (needsRefresh) {
      setState(() {
        // TV
        _selectedSortBy = 'trending';
        _selectedGenreIds = [];
        _tvLanguage = null;
        _hasActiveFilters = false;
        _showsSearchController.clear();

        // Movies
        _selectedMovieSortBy = 'trending';
        _selectedMovieGenreIds = [];
        _movieLanguage = null;
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
    _tabController.addListener(() {
      // 1. Immediately activate shimmer at the start of transition/swipe
      if (_tabController.indexIsChanging) {
        _tabTransitionTimer?.cancel();
        setState(() {
          _isTabChanging = true;
        });
        return;
      }

      // 2. Once transition commits/completes
      final isTv = _tabController.index == 0;
      final activeController = isTv
          ? _showsSearchController
          : _moviesSearchController;
      final currentState = context.read<SearchCubit>().state;

      // MODIFY: Ensure tab switching only triggers search when query has at least 3 characters
      final trimmedQuery = activeController.text.trim();
      if (trimmedQuery.length >= 3) {
        bool shouldSearch = true;
        if (currentState is SearchResultsSuccess) {
          if (currentState.isTv == isTv && currentState.query == trimmedQuery) {
            shouldSearch = false;
          }
        }

        if (shouldSearch) {
          context.read<SearchCubit>().executeSearch(trimmedQuery, isTv: isTv);
        } else {
          // Correct search results are already in memory, no need to refresh or shimmer
          setState(() {
            _isTabChanging = false;
          });
          return;
        }
      } else {
        // Wants trending data (either empty or less than 3 characters)
        if (currentState is SearchTrendingSuccess) {
          // Trending data is already loaded for both tabs, no need to refresh or shimmer
          setState(() {
            _isTabChanging = false;
          });
          return;
        } else {
          _loadTrendingWithFilters();
        }
      }

      // Hold shimmer for 300ms to let images load smoothly
      _tabTransitionTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isTabChanging = false;
          });
        }
      });
    });

    // Load trending shows & movies on startup
    _loadTrendingWithFilters();

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

    final hasActive = _hasActiveFilters || _tvLanguage != null;
    if (!hasActive) {
      if (!mounted) return;
      context.read<SearchCubit>().resetTvTrending();
      setState(() {
        _isFetchingTvFilters = false;
      });
      return;
    }

    try {
      final tmdbClient = context.read<TmdbClient>();
      final filteredShows = await tmdbClient.discoverTvShowsWithFilters(
        sortBy: _selectedSortBy == 'trending'
            ? 'first_air_date.desc'
            : _selectedSortBy,
        genreIds: _selectedGenreIds.isEmpty ? null : _selectedGenreIds,
        language: _tvLanguage,
      );

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

    final hasActive = _hasActiveMovieFilters || _movieLanguage != null;
    if (!hasActive) {
      if (!mounted) return;
      context.read<SearchCubit>().resetMoviesTrending();
      setState(() {
        _isFetchingMovieFilters = false;
      });
      return;
    }

    try {
      final tmdbClient = context.read<TmdbClient>();
      final filteredMovies = await tmdbClient.discoverMoviesWithFilters(
        sortBy: _selectedMovieSortBy == 'trending'
            ? 'primary_release_date.desc'
            : _selectedMovieSortBy,
        genreIds: _selectedMovieGenreIds.isEmpty
            ? null
            : _selectedMovieGenreIds,
        language: _movieLanguage,
      );

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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FilterBottomSheet(
        isTv: isTv,
        selectedSortBy: isTv ? _selectedSortBy : _selectedMovieSortBy,
        selectedGenreIds: isTv ? _selectedGenreIds : _selectedMovieGenreIds,
        genres: isTv ? _tvGenres : _movieGenres,
        onApply: (sortBy, genreIds) {
          setState(() {
            if (isTv) {
              _selectedSortBy = sortBy;
              _selectedGenreIds = genreIds;
              _hasActiveFilters = sortBy != 'trending' || genreIds.isNotEmpty;
            } else {
              _selectedMovieSortBy = sortBy;
              _selectedMovieGenreIds = genreIds;
              _hasActiveMovieFilters =
                  sortBy != 'trending' || genreIds.isNotEmpty;
            }
          });

          if (isTv) {
            // Update cubit with filter state for pagination
            context.read<SearchCubit>().setTvFilters(
              sortBy: sortBy,
              genreIds: genreIds.isEmpty ? null : genreIds,
              language: _tvLanguage,
            );
            _applyFiltersToTrending();
          } else {
            // Update cubit with movie filter state for pagination
            context.read<SearchCubit>().setMovieFilters(
              sortBy: sortBy,
              genreIds: genreIds.isEmpty ? null : genreIds,
              language: _movieLanguage,
            );
            _applyMovieFiltersToTrending();
          }
        },
      ),
    );
  }

  void _onScroll(bool isTv) {
    final controller = isTv ? _showsScrollController : _moviesScrollController;
    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 200) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
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
                  color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
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
                              color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
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
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor ?? (Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E)),
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
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                            side: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white70,
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
                              borderRadius: BorderRadius.circular(24),
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
                border: Border.all(color: Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38, width: 1.5),
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
        genreIds: _selectedGenreIds,
        language: _tvLanguage,
      );
      if (searchText.trim().isNotEmpty) {
        context.read<SearchCubit>().onSearchTextChanged(searchText, isTv: true);
      } else {
        _applyFiltersToTrending();
      }
    } else {
      context.read<SearchCubit>().setMovieFilters(
        sortBy: _selectedMovieSortBy,
        genreIds: _selectedMovieGenreIds,
        language: _movieLanguage,
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
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No results found.\nTry searching for something else.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary, fontSize: 16.0),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: controller,
            physics: physics,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio: 0.52,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final String title = item['name'] ?? item['title'] ?? 'Unknown';
              final String? posterPath = item['poster_path'];
              final double voteAverage =
                  (item['vote_average'] as num?)?.toDouble() ?? 0.0;
              final int id = item['id'];
              final String mediaType = item['media_type'] ?? defaultType;
              final String? dateStr =
                  item['release_date'] ?? item['first_air_date'];
              String year = '';
              if (dateStr != null && dateStr.isNotEmpty) {
                try {
                  year = DateTime.parse(dateStr).year.toString();
                } catch (_) {
                  if (dateStr.length >= 4) {
                    year = dateStr.substring(0, 4);
                  }
                }
              }

              return GestureDetector(
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
                              color: Theme.of(context).brightness == Brightness.light ? Colors.grey[200] : AppColors.surfaceLight,
                              width: double.infinity,
                              child: posterPath != null && posterPath.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _getImageUrl(posterPath),
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          Skeleton.ignore(
                                            child: Icon(
                                              Icons.movie_creation_outlined,
                                              size: 32,
                                              color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                                            ),
                                          ),
                                    )
                                  : Skeleton.ignore(
                                      child: Icon(
                                        Icons.movie_creation_outlined,
                                        size: 32,
                                        color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
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
                    // Rating & Year row
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
                              color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                            ),
                          ),
                          if (year.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 10.0,
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              year,
                              style: TextStyle(
                                fontSize: 10.0,
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ] else if (year.isNotEmpty) ...[
                          Text(
                            year,
                            style: TextStyle(
                              fontSize: 10.0,
                              color: Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: CupertinoActivityIndicator(
              color: AppColors.primary, // Yellow color
              radius: 12.0,
            ),
          ),
        if (hasLoadMoreError && onRetry != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to load more data.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
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
        if (hasReachedMax && items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              defaultType == 'tv'
                  ? 'No more shows to load'
                  : 'No more movies to load',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light ? Colors.grey[500] : AppColors.textTertiary,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
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
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MovieDetailsPage(movieId: mediaId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
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
  bool _showPill = false;
  bool _loaded = false;
  String _pillText = 'ENDED';
  Color _pillColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    // Wait for a staggered delay based on item index to prevent parallel network floods/connection resets
    await Future.delayed(Duration(milliseconds: widget.index * 120));
    if (!mounted) return;
    try {
      final tmdbClient = context.read<TmdbClient>();
      final details = await tmdbClient.getTvShowDetails(widget.tvId);
      final String status = details['status'] ?? '';
      if (!mounted) return;
      setState(() {
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
  final List<int> selectedGenreIds;
  final List<dynamic> genres;
  final Function(String sortBy, List<int> genreIds) onApply;

  const _FilterBottomSheet({
    required this.isTv,
    required this.selectedSortBy,
    required this.selectedGenreIds,
    required this.genres,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _currentSortBy;
  late List<int> _currentGenreIds;
  late Map<String, String> _sortOptions;

  @override
  void initState() {
    super.initState();
    _currentSortBy = widget.selectedSortBy;
    _currentGenreIds = List.from(widget.selectedGenreIds);
    _sortOptions = {
      'Trending': 'trending',
      'Latest': widget.isTv
          ? 'first_air_date.desc'
          : 'primary_release_date.desc',
      'Popular': 'popularity.desc',
    };
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.6,
      child: Material(
        color: Theme.of(context).bottomSheetTheme.backgroundColor ?? (Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E)), // Dark grey background matching the screenshot
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            // Sort by Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Sort by',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: _sortOptions.entries.map((entry) {
                  final label = entry.key;
                  final value = entry.value;
                  final isSelected = _currentSortBy == value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentSortBy = value;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (Theme.of(context).brightness == Brightness.light ? Colors.grey.shade300 : const Color(0xFFCCCCCC)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: Colors
                                .black, // Dark text for both yellow and grey
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: AppSpacing.md),

            // Genres Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'Genres',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Genres List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                itemCount: widget.genres.length,
                separatorBuilder: (context, index) => Divider(
                  color: Theme.of(context).dividerColor,
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
                itemBuilder: (context, index) {
                  final genre = widget.genres[index];
                  final optionId = genre['id'] as int;
                  final optionName = genre['name'] as String;
                  final isSelected = _currentGenreIds.contains(optionId);

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 0,
                    ),
                    title: Text(
                      optionName,
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
                            child: Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.black,
                            ),
                          )
                        : Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.light ? Colors.black38 : Colors.white38,
                                width: 1.5,
                              ),
                            ),
                          ),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _currentGenreIds.remove(optionId);
                        } else {
                          _currentGenreIds.add(optionId);
                        }
                      });
                    },
                  );
                },
              ),
            ),

            // Bottom Action Bar
            Divider(color: Theme.of(context).dividerColor, height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentSortBy = 'trending';
                            _currentGenreIds.clear();
                          });
                          widget.onApply('trending', []);
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Theme.of(context).brightness == Brightness.light ? Colors.black54 : Colors.white54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'RESET',
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.light ? Colors.black87 : Colors.white70,
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
                          widget.onApply(_currentSortBy, _currentGenreIds);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
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
            ),
          ],
        ),
      ),
    );
  }
}
