import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quick_actions/quick_actions.dart';

import '../../app/shell_navigation_page.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/widgets/auth_required_view.dart';
import '../../features/feedback/presentation/pages/feedback_board_page.dart';

/// Service managing Home Screen Quick Actions (iOS 3D/Haptic Touch & Android App Shortcuts).
class QuickActionsService {
  QuickActionsService._();
  static final QuickActionsService instance = QuickActionsService._();

  static const String actionSearch = 'action_search';
  static const String actionSurpriseMe = 'action_surprise_me';
  static const String actionFeedback = 'action_feedback';

  final QuickActions _quickActions = const QuickActions();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isInitialized = false;
  bool? _lastAuthenticatedState;
  String? _pendingAction;

  /// Initializes the quick actions listener and sets the navigator key for routing.
  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_isInitialized) return;
    _isInitialized = true;

    _quickActions.initialize((String shortcutType) {
      handleAction(shortcutType);
    });
  }

  /// Synchronizes quick actions based on the user's authentication state.
  ///
  /// - Default / Unauthenticated: Search
  /// - Authenticated: Search, Surprise Me, Feedback
  Future<void> syncShortcuts({required bool isAuthenticated}) async {
    if (_lastAuthenticatedState == isAuthenticated) return;

    try {
      if (isAuthenticated) {
        await _quickActions.setShortcutItems(<ShortcutItem>[
          const ShortcutItem(
            type: actionSearch,
            localizedTitle: 'Search',
            icon: 'ic_shortcut_search',
          ),
          const ShortcutItem(
            type: actionSurpriseMe,
            localizedTitle: 'Surprise Me',
            icon: 'ic_shortcut_surprise',
          ),
          const ShortcutItem(
            type: actionFeedback,
            localizedTitle: 'Feedback',
            icon: 'ic_shortcut_feedback',
          ),
        ]);
      } else {
        await _quickActions.setShortcutItems(<ShortcutItem>[
          const ShortcutItem(
            type: actionSearch,
            localizedTitle: 'Search',
            icon: 'ic_shortcut_search',
          ),
        ]);
      }
      _lastAuthenticatedState = isAuthenticated;
    } catch (e) {
      debugPrint('QuickActionsService: Failed to set shortcut items: $e');
    }
  }

  /// Dispatches the selected action.
  void handleAction(String actionType) {
    _pendingAction = actionType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executePendingAction();
    });
  }

  /// Called when [ShellNavigationPage] mounts to consume any action queued during cold launch.
  void consumePendingAction() {
    if (_pendingAction == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executePendingAction();
    });
  }

  void _executePendingAction() {
    final action = _pendingAction;
    if (action == null) return;

    final nav = _navigatorKey?.currentState;
    if (nav == null || !nav.mounted) {
      return;
    }

    final context = _navigatorKey?.currentContext;
    final isShellReady = ShellNavigationController.isReady;
    final hasActiveUser = FirebaseAuth.instance.currentUser != null;

    // If the action requires ShellNavigationPage (Search, Surprise Me) and an authenticated
    // user is still transitioning through AuthGate/SplashScreen, retain the action until the
    // shell mounts and calls consumePendingAction().
    if (!isShellReady && hasActiveUser && (action == actionSearch || action == actionSurpriseMe)) {
      return;
    }

    _pendingAction = null;

    switch (action) {
      case actionSearch:
        _handleSearch(nav, context);
        break;
      case actionSurpriseMe:
        _handleSurpriseMe(nav);
        break;
      case actionFeedback:
        if (hasActiveUser) {
          _handleFeedback(nav);
        } else if (context != null && context.mounted) {
          nav.popUntil((route) => route.isFirst);
          AuthRequiredBottomSheet.show(
            context,
            title: 'Sign in for Feedback',
            subtitle: 'Sign in to view, vote, and submit community feature requests.',
            icon: Icons.feedback_outlined,
          );
        }
        break;
      default:
        debugPrint('QuickActionsService: Unknown shortcut type: $action');
    }
  }

  void _handleSearch(NavigatorState nav, BuildContext? context) {
    bool poppedAny = false;
    nav.popUntil((route) {
      if (route.isFirst) return true;
      poppedAny = true;
      return false;
    });

    void triggerTabSwitch() {
      if (ShellNavigationController.onSwitchTab != null) {
        // Tab index 2 is SearchPage in ShellNavigationPage
        ShellNavigationController.switchToTab(2);
      } else if (context != null && context.mounted) {
        final authCubit = context.read<AuthCubit>();
        if (authCubit.state is! Authenticated) {
          authCubit.continueAsGuest();
        }
      }
    }

    if (poppedAny) {
      WidgetsBinding.instance.addPostFrameCallback((_) => triggerTabSwitch());
    } else {
      triggerTabSwitch();
    }
  }

  void _handleSurpriseMe(NavigatorState nav) {
    bool poppedAny = false;
    nav.popUntil((route) {
      if (route.isFirst) return true;
      poppedAny = true;
      return false;
    });

    void triggerSurpriseMe() {
      ShellNavigationController.showSurpriseMe();
    }

    if (poppedAny) {
      WidgetsBinding.instance.addPostFrameCallback((_) => triggerSurpriseMe());
    } else {
      triggerSurpriseMe();
    }
  }

  void _handleFeedback(NavigatorState nav) {
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/feedback'),
        builder: (_) => const FeedbackBoardPage(),
      ),
    );
  }
}
