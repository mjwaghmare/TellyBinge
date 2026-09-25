import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/services/app_haptics.dart';
import '../core/constants/app_assets.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/widgets/app_snackbar.dart';
import '../core/widgets/offline_sync_banner.dart';
import '../core/sync/sync_status_cubit.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/cubit/auth_state.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import '../features/dashboard/presentation/cubit/tv_show_watchlist_state.dart';
import '../features/movies/presentation/pages/movies_page.dart';
import '../features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import '../features/movies/presentation/cubit/movie_watchlist_state.dart';
import '../features/search/presentation/pages/search_page.dart';
import '../features/search/presentation/widgets/surprise_me_sheet.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/profile/presentation/cubit/achievements_cubit.dart';
import '../features/custom_lists/presentation/cubit/custom_lists_cubit.dart';

import '../core/services/app_update_service.dart';
import '../features/profile/presentation/cubit/profile_heatmap_cubit.dart';
import '../features/auth/presentation/widgets/auth_required_view.dart';
import 'package:lottie/lottie.dart';

import '../core/services/quick_actions_service.dart';

/// Global controller to allow deep links and quick actions to switch tabs
/// or display the Surprise Me modal sheet from outside the shell widget tree.
class ShellNavigationController {
  ShellNavigationController._();

  static void Function(int tab, {int? subTab})? onSwitchTab;
  static void Function()? onShowSurpriseMe;

  static bool get isReady => onSwitchTab != null;

  static void switchToTab(int tab, {int? subTab}) {
    onSwitchTab?.call(tab, subTab: subTab);
  }

  static void showSurpriseMe() {
    onShowSurpriseMe?.call();
  }
}

class ShellNavigationPage extends StatefulWidget {
  final int initialIndex;

  const ShellNavigationPage({super.key, this.initialIndex = 0});

  @override
  State<ShellNavigationPage> createState() => _ShellNavigationPageState();
}

class _ShellNavigationPageState extends State<ShellNavigationPage> {
  late final ValueNotifier<int> _tabNotifier;
  final ValueNotifier<int> _exploreSubTabNotifier = ValueNotifier<int>(0);
  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();
  final GlobalKey<MoviesPageState> _moviesKey = GlobalKey<MoviesPageState>();
  bool _hasStartedWatchers = false;
  StreamSubscription? _movieFailureSub;
  StreamSubscription? _tvFailureSub;
  StreamSubscription? _customListsFailureSub;

  @override
  void initState() {
    super.initState();
    _tabNotifier = ValueNotifier<int>(widget.initialIndex);

    _movieFailureSub = context.read<MovieWatchlistCubit>().failureStream.listen((failure) {
      if (mounted) {
        AppSnackbar.showError(context, failure.message);
      }
    });

    _tvFailureSub = context.read<TvShowWatchlistCubit>().failureStream.listen((failure) {
      if (mounted) {
        AppSnackbar.showError(context, failure.message);
      }
    });

    _customListsFailureSub = context.read<CustomListsCubit>().failureStream.listen((failure) {
      if (mounted) {
        AppSnackbar.showError(context, failure.message);
      }
    });

    ShellNavigationController.onSwitchTab = (int tab, {int? subTab}) {
      if (mounted) {
        setState(() {
          _tabNotifier.value = tab;
          if (subTab != null) {
            _exploreSubTabNotifier.value = subTab;
          }
        });
      }
    };

    ShellNavigationController.onShowSurpriseMe = () {
      if (mounted) {
        _showSurpriseMeSheet();
      }
    };

    final authState = context.read<AuthCubit>().state;
    if (authState is Authenticated) {
      _startWatchers(authState.user.uid);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        QuickActionsService.instance.consumePendingAction();
        AppUpdateService.instance.checkAndShowUpdate(context);
      }
    });
  }

  void _startWatchers(String uid) {
    if (_hasStartedWatchers) return;
    _hasStartedWatchers = true;
    context.read<MovieWatchlistCubit>().watchWatchlist(uid);
    context.read<TvShowWatchlistCubit>().watchWatchlist(uid);
    context.read<CustomListsCubit>().watchCustomLists(uid);
    context.read<SyncStatusCubit>().startMonitoring(uid);
  }

  void _evaluateAchievements() {
    AchievementsCubit.evaluateFromContext(context, notify: true);
  }

  @override
  void dispose() {
    _movieFailureSub?.cancel();
    _tvFailureSub?.cancel();
    _customListsFailureSub?.cancel();
    ShellNavigationController.onSwitchTab = null;
    ShellNavigationController.onShowSurpriseMe = null;
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
      AppHaptics.lightImpact();
      setState(() {
        _tabNotifier.value = index;
      });
    }
  }

  void _showSurpriseMeSheet() {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      AuthRequiredBottomSheet.show(
        context,
        title: 'Sign in for Surprise Me',
        subtitle:
            'Sign in to roll the dice and get personalized random movie and TV show recommendations.',
        icon: Icons.casino_rounded,
      );
      return;
    }

    AppHaptics.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SurpriseMeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listener: (context, authState) {
            if (authState is Authenticated) {
              _startWatchers(authState.user.uid);
            } else {
              _hasStartedWatchers = false;
              context.read<MovieWatchlistCubit>().clearWatchlist();
              context.read<TvShowWatchlistCubit>().clearWatchlist();
              context.read<CustomListsCubit>().clearLists();
              context.read<SyncStatusCubit>().stopMonitoring();
            }
          },
        ),
        BlocListener<MovieWatchlistCubit, MovieWatchlistState>(
          listenWhen: (previous, current) => current is MovieWatchlistSuccess,
          listener: (context, state) => _evaluateAchievements(),
        ),
        BlocListener<TvShowWatchlistCubit, TvShowWatchlistState>(
          listenWhen: (previous, current) => current is TvShowWatchlistSuccess,
          listener: (context, state) => _evaluateAchievements(),
        ),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, authState) {
          final isAuthenticated = authState is Authenticated;

          final pages = [
            isAuthenticated
                ? DashboardPage(
                    key: _dashboardKey,
                    onNavigateToExplore: () {
                      setState(() {
                        _tabNotifier.value = 2;
                      });
                      _exploreSubTabNotifier.value = 0;
                    },
                  )
                : AuthRequiredView(
                    tabNotifier: _tabNotifier,
                    tabIndex: 0,
                    title: 'Track TV Shows',
                    subtitle:
                        'Never miss an episode. Track what you watch, get countdowns, and stay up to date.',
                    features: const [
                      'Up Next episode tracker with progress bars',
                      'Release dates & episode air countdowns',
                      'Smart notifications for upcoming episodes',
                    ],
                  ),
            isAuthenticated
                ? MoviesPage(
                    key: _moviesKey,
                    onNavigateToExplore: () {
                      setState(() {
                        _tabNotifier.value = 2;
                      });
                      _exploreSubTabNotifier.value = 1;
                    },
                  )
                : AuthRequiredView(
                    tabNotifier: _tabNotifier,
                    tabIndex: 1,
                    title: 'Movie Watchlist',
                    subtitle:
                        'Keep track of movies you want to see and manage the ones you have watched.',
                    features: const [
                      'Build your custom movie watchlist',
                      'Release calendar & premiere alerts',
                      'Mark movies watched and save favorites',
                    ],
                  ),
            SearchPage(
              subTabNotifier: _exploreSubTabNotifier,
              mainTabNotifier: _tabNotifier,
            ),
            isAuthenticated
                ? BlocProvider<ProfileHeatmapCubit>(
                    create: (context) => ProfileHeatmapCubit(),
                    child: ProfilePage(
                      tabNotifier: _tabNotifier,
                      onNavigateToShowsExplore: () {
                        setState(() {
                          _tabNotifier.value = 2;
                        });
                        _exploreSubTabNotifier.value = 0;
                      },
                      onNavigateToMoviesExplore: () {
                        setState(() {
                          _tabNotifier.value = 2;
                        });
                        _exploreSubTabNotifier.value = 1;
                      },
                    ),
                  )
                : AuthRequiredView(
                    tabNotifier: _tabNotifier,
                    tabIndex: 3,
                    title: 'Your Profile & Stats',
                    subtitle:
                        'Sign in to see your watching habits, total watch time, and unlock achievements.',
                    features: const [
                      'Total watch time stats for shows & movies',
                      'Daily watch activity heatmap & history',
                      'Unlock badges, milestones & streaks',
                    ],
                  ),
          ];

          return Scaffold(
            extendBody: true,
            resizeToAvoidBottomInset: false,
            body: Stack(
              children: [
                IndexedStack(index: _tabNotifier.value, children: pages),
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: OfflineSyncBanner(),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _showSurpriseMeSheet,
              backgroundColor: Colors.transparent,
              elevation: 0,
              highlightElevation: 0,
              tooltip: 'Surprise Me',
              child: Transform.scale(
                scale: 1.7,
                child: Lottie.asset(
                  AppAssets.diceLottie,
                  fit: BoxFit.contain,
                  animate: false,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.casino, color: Colors.black, size: 32),
                ),
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: _CustomGlowBottomBar(
              currentIndex: _tabNotifier.value,
              onTap: _onItemTapped,
            ),
          );
        },
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
    final isLight = context.isLight;
    final selectedColor = isLight ? AppColors.lightPrimary : AppColors.primary;
    final unselectedColor = isLight
        ? AppColors.lightTextTertiary
        : context.textTertiary;

    return Container(
      color: isLight
          ? AppColors.lightSurface
          : Theme.of(context).scaffoldBackgroundColor,
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
                  color: isLight
                      ? AppColors.borderLight
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),

              Row(
                children: [
                  _buildNavItem(
                    context,
                    0,
                    'Shows',
                    Icons.tv_outlined,
                    Icons.tv,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    isLight: isLight,
                  ),
                  _buildNavItem(
                    context,
                    1,
                    'Movies',
                    Icons.movie_filter_outlined,
                    Icons.movie_filter,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    isLight: isLight,
                  ),
                  const SizedBox(width: 60), // Space for central FAB
                  _buildNavItem(
                    context,
                    2,
                    'Explore',
                    Icons.search_outlined,
                    Icons.search,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    isLight: isLight,
                  ),
                  _buildNavItem(
                    context,
                    3,
                    'Profile',
                    Icons.person_outline_rounded,
                    Icons.person,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    isLight: isLight,
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
    BuildContext context,
    int index,
    String label,
    IconData icon,
    IconData activeIcon, {
    required Color selectedColor,
    required Color unselectedColor,
    required bool isLight,
    VoidCallback? onLongPress,
  }) {
    final isSelected = currentIndex == index;
    final isReduced = AppMotion.isReducedMotion(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label tab',
        child: _LongPressHapticButton(
          onTap: () => onTap(index),
          onLongPress: onLongPress,
          child: Stack(
          alignment: Alignment.center,
          children: [
            if (!isLight)
              Align(
                alignment: Alignment.topCenter,
                child: AnimatedScale(
                  duration: isReduced ? AppMotion.instant : const Duration(milliseconds: 400),
                  curve: isReduced ? Curves.linear : Curves.easeOutBack,
                  scale: isSelected ? 1.0 : 0.0,
                  alignment: Alignment.topCenter,
                  child: AnimatedOpacity(
                    duration: AppMotion.fadeDuration(
                      context,
                      normalDuration: const Duration(milliseconds: 300),
                    ),
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
                  color: isSelected ? selectedColor : unselectedColor,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? selectedColor : unselectedColor,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
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
        AppHaptics.lightImpact();
      }
      if (_controller.value >= 0.66 && !_passed66) {
        _passed66 = true;
        AppHaptics.lightImpact();
      }
      if (_controller.value >= 1.0 && !_hasTriggered) {
        _hasTriggered = true;
        AppHaptics.heavyImpact();
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
