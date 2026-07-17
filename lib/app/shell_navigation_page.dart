import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/theme/app_colors.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/cubit/auth_state.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../features/movies/presentation/pages/movies_page.dart';
import '../features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';

import '../features/profile/presentation/cubit/profile_heatmap_cubit.dart';

class ShellNavigationPage extends StatefulWidget {
  const ShellNavigationPage({super.key});

  @override
  State<ShellNavigationPage> createState() => _ShellNavigationPageState();
}

class _ShellNavigationPageState extends State<ShellNavigationPage> {
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _exploreSubTabNotifier = ValueNotifier<int>(0);
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Start listening to the user's movie watchlist updates
    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      context.read<MovieWatchlistCubit>().watchWatchlist(authState.user.uid);
      context.read<TvShowWatchlistCubit>().watchWatchlist(authState.user.uid);
    }

    _pages = [
      DashboardPage(
        onNavigateToExplore: () {
          setState(() {
            _tabNotifier.value =
                2; // Switch bottom navigation to Explore (SearchPage)
          });
          _exploreSubTabNotifier.value =
              0; // Select the TV SHOWS sub-tab inside Explore (0 for TV, 1 for Movies)
        },
      ),
      MoviesPage(
        onNavigateToExplore: () {
          setState(() {
            _tabNotifier.value =
                2; // Switch bottom navigation to Explore (SearchPage)
          });
          _exploreSubTabNotifier.value =
              1; // Select the MOVIES sub-tab inside Explore
        },
      ),
      SearchPage(
        subTabNotifier: _exploreSubTabNotifier,
        mainTabNotifier: _tabNotifier,
      ),
      BlocProvider<ProfileHeatmapCubit>(
        create: (context) => ProfileHeatmapCubit(),
        child: ProfilePage(tabNotifier: _tabNotifier),
      ),
    ];
  }

  @override
  void dispose() {
    _tabNotifier.dispose();
    _exploreSubTabNotifier.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_tabNotifier.value != index) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _tabNotifier.value = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabNotifier.value, children: _pages),
      bottomNavigationBar: _CustomGlowBottomBar(
        currentIndex: _tabNotifier.value,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _CustomGlowBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomGlowBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: SizedBox(
          height: 65,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),

              Row(
                children: [
                  _buildNavItem(0, 'Shows', Icons.tv_outlined, Icons.tv),
                  _buildNavItem(
                    1,
                    'Movies',
                    Icons.movie_filter_outlined,
                    Icons.movie_filter,
                  ),
                  _buildNavItem(
                    2,
                    'Explore',
                    Icons.search_outlined,
                    Icons.search,
                  ),
                  _buildNavItem(
                    3,
                    'Profile',
                    Icons.person_outline_rounded,
                    Icons.person,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    IconData icon,
    IconData activeIcon,
  ) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                scale: isSelected ? 1.0 : 0.0,
                alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isSelected ? 1.0 : 0.0,
                  child: Container(
                    width: 150,
                    height: 75,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        radius: 1,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
