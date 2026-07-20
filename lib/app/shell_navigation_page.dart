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
import '../features/search/presentation/widgets/surprise_me_sheet.dart';
import '../features/profile/presentation/pages/profile_page.dart';

import '../features/profile/presentation/cubit/profile_heatmap_cubit.dart';
import 'package:lottie/lottie.dart';

class ShellNavigationPage extends StatefulWidget {
  const ShellNavigationPage({super.key});

  @override
  State<ShellNavigationPage> createState() => _ShellNavigationPageState();
}

class _ShellNavigationPageState extends State<ShellNavigationPage> {
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _exploreSubTabNotifier = ValueNotifier<int>(0);
  final GlobalKey<DashboardPageState> _dashboardKey = GlobalKey<DashboardPageState>();
  final GlobalKey<MoviesPageState> _moviesKey = GlobalKey<MoviesPageState>();
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
        key: _dashboardKey,
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
        key: _moviesKey,
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
    if (_tabNotifier.value == index) {
      if (index == 0) {
        _dashboardKey.currentState?.scrollToTop();
      } else if (index == 1) {
        _moviesKey.currentState?.scrollToTop();
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _tabNotifier.value = index;
      });
    }
  }

  void _showSurpriseMeSheet() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SurpriseMeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tabNotifier.value, children: _pages),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: FloatingActionButton(
          onPressed: _showSurpriseMeSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          tooltip: 'Surprise Me',
          child: Transform.scale(
            scale: 1.7,
            child: Lottie.asset(
              'assets/lottie/dice.json',
              fit: BoxFit.contain,
              animate: false,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.casino, color: Colors.black, size: 32),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
                  const SizedBox(width: 60), // Space for central FAB
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
    IconData activeIcon, {
    VoidCallback? onLongPress,
  }) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: _LongPressHapticButton(
        onTap: () => onTap(index),
        onLongPress: onLongPress,
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

class _LongPressHapticButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _LongPressHapticButton({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<_LongPressHapticButton> createState() => _LongPressHapticButtonState();
}

class _LongPressHapticButtonState extends State<_LongPressHapticButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _hasTriggered = false;
  bool _passed33 = false;
  bool _passed66 = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _controller.addListener(() {
      if (_controller.value >= 0.33 && !_passed33) {
        _passed33 = true;
        HapticFeedback.lightImpact();
      }
      if (_controller.value >= 0.66 && !_passed66) {
        _passed66 = true;
        HapticFeedback.lightImpact();
      }
      if (_controller.value >= 1.0 && !_hasTriggered) {
        _hasTriggered = true;
        HapticFeedback.heavyImpact();
        if (widget.onLongPress != null) {
          widget.onLongPress!();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onLongPress == null) return;
    _hasTriggered = false;
    _passed33 = false;
    _passed66 = false;
    _controller.forward(from: 0);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_hasTriggered) {
      widget.onTap();
    }
    _controller.stop();
  }

  void _handleTapCancel() {
    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onLongPress != null ? _handleTapDown : null,
      onTapUp: widget.onLongPress != null ? _handleTapUp : null,
      onTapCancel: widget.onLongPress != null ? _handleTapCancel : null,
      onTap: widget.onLongPress == null ? widget.onTap : null,
      child: widget.child,
    );
  }
}
