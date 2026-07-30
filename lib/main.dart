import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app/shell_navigation_page.dart';
import 'core/network/tmdb_client.dart';
import 'core/services/widget_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_sync_service.dart';
import 'features/show_details/presentation/cubit/show_details_cubit.dart';
import 'features/show_details/presentation/pages/show_details_page.dart';
import 'core/storage/settings_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/profile/presentation/cubit/settings_cubit.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/auth/presentation/cubit/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/search/presentation/cubit/search_cubit.dart';
import 'features/movies/presentation/cubit/movie_watchlist_cubit.dart';
import 'features/movies/domain/repositories/movie_watchlist_repository.dart';
import 'features/movies/data/repositories/movie_watchlist_repository_impl.dart';
import 'features/dashboard/presentation/cubit/tv_show_watchlist_cubit.dart';
import 'features/dashboard/domain/repositories/tv_watchlist_repository.dart';
import 'features/dashboard/data/repositories/tv_watchlist_repository_impl.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global uncaught error handling for production stability
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Global Flutter Error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Global Platform Error: $error\n$stack');
    return true;
  };

  // Initialize Firebase first — the WidgetService background interactivity callback
  // fires in a headless isolate that requires Firebase to already be ready.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await WidgetService.initialize();

  // Initialize notification and background services
  await NotificationService().initialize();
  await BackgroundSyncService().initialize();
  await BackgroundSyncService().registerPeriodicSync();

  // Initialize Google Sign-In
  try {
    await GoogleSignIn.instance.initialize();
  } catch (e) {
    debugPrint('Warning: Could not initialize Google Sign-In: $e');
  }

  // Load environment variables (TMDb key)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // Load settings for OLED theme
  final settingsStorage = SettingsStorage();
  final settings = await settingsStorage.readSettings();
  final isDarkInitial = settings['dark_mode'] as bool? ?? true;
  final isOledInitial = settings['oled_dark_mode'] as bool? ?? false;

  final prefs = await SharedPreferences.getInstance();

  runApp(MyApp(
    settingsStorage: settingsStorage,
    isDarkInitial: isDarkInitial,
    isOledInitial: isOledInitial,
    prefs: prefs,
  ));
}

class MyApp extends StatefulWidget {
  final SettingsStorage settingsStorage;
  final bool isDarkInitial;
  final bool isOledInitial;
  final SharedPreferences prefs;

  const MyApp({
    super.key,
    required this.settingsStorage,
    required this.isDarkInitial,
    required this.isOledInitial,
    required this.prefs,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSubscription;
  // Single TmdbClient instance for widget-driven navigation.
  // Initialised here (outside the RepositoryProvider tree) to avoid creating
  // a fresh HTTP client on every widget tap.
  late final TmdbClient _tmdbClient;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tmdbClient = TmdbClient();
    HomeWidget.setAppGroupId(WidgetService.iOSGroupId);

    // Handle cold launch: app was opened by tapping a widget Link while terminated.
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) _handleWidgetUri(uri);
    });

    // Handle warm launch: app is already running, user taps a widget row.
    // Also reset the AuthGate sync throttle so re-entering the app after a
    // background mark-as-watched always triggers a fresh widget data pull.
    _widgetClickSubscription = HomeWidget.widgetClicked.listen((uri) {
      _AuthGateState.invalidateSyncThrottle();
      if (uri != null) _handleWidgetUri(uri);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final location = routeInformation.uri.toString();
    if (location.startsWith('tvtimeapp://') || location == '/' || location == '') {
      return true; // Intercepted: prevents Flutter Engine from pushing duplicate routes
    }
    return super.didPushRouteInformation(routeInformation);
  }

  /// Routes incoming widget URLs to the correct page.
  /// Currently handles: tvtimeapp://show/{showId}
  void _handleWidgetUri(Uri uri) {
    if (uri.scheme != 'tvtimeapp') return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (uri.host == 'mark_watched') {
      interactiveWidgetCallback(uri);
      return;
    }
    if (uri.host == 'show') {
      final showIdStr = uri.pathSegments.firstOrNull;
      final showId = int.tryParse(showIdStr ?? '');
      if (showId != null && showId > 0) {
        // Use a post-frame callback so we don't navigate before the widget tree is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = navigatorKey.currentState;
          if (nav == null) return;

          bool alreadyOnShow = false;
          nav.popUntil((route) {
            if (route.settings.name == '/show/$showId') {
              alreadyOnShow = true;
              return true; // Stay on existing show details page
            }
            return route.isFirst; // Pop sub-routes down to root
          });

          if (!alreadyOnShow) {
            nav.push(
              MaterialPageRoute(
                settings: RouteSettings(name: '/show/$showId'),
                builder: (context) => BlocProvider<ShowDetailsCubit>(
                  create: (_) => ShowDetailsCubit(tmdbClient: _tmdbClient),
                  child: ShowDetailsPage(
                    mediaId: showId,
                    mediaType: 'tv',
                    title: 'Show Details',
                    initialTabIndex: 1,
                  ),
                ),
              ),
            );
          }
        });
      }
    }
    // tvtimeapp:// (root) — just open the app, no navigation needed.
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>.value(value: widget.prefs),
        RepositoryProvider<SettingsStorage>.value(value: widget.settingsStorage),
        RepositoryProvider<AuthRepository>(create: (context) => AuthRepositoryImpl()),
        RepositoryProvider<TmdbClient>(create: (context) => TmdbClient()),
        RepositoryProvider<MovieWatchlistRepository>(
          create: (context) => MovieWatchlistRepositoryImpl(),
        ),
        RepositoryProvider<TvWatchlistRepository>(
          create: (context) => TvWatchlistRepositoryImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>(
            create: (context) => SettingsCubit(
              prefs: context.read<SharedPreferences>(),
              tmdbClient: context.read<TmdbClient>(),
            ),
          ),
          BlocProvider<ThemeCubit>(
            create: (context) => ThemeCubit(
              storage: context.read<SettingsStorage>(),
              isDarkInitial: widget.isDarkInitial,
              isOledInitial: widget.isOledInitial,
            ),
          ),
          BlocProvider<AuthCubit>(create: (context) => AuthCubit(authRepository: context.read<AuthRepository>())),
          BlocProvider<SearchCubit>(create: (context) => SearchCubit(tmdbClient: context.read<TmdbClient>())),
          BlocProvider<MovieWatchlistCubit>(
            create: (context) => MovieWatchlistCubit(
              movieWatchlistRepository: context.read<MovieWatchlistRepository>(),
              tmdbClient: context.read<TmdbClient>(),
            ),
          ),
          BlocProvider<TvShowWatchlistCubit>(
            create: (context) => TvShowWatchlistCubit(
              tvWatchlistRepository: context.read<TvWatchlistRepository>(),
            ),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              title: 'TellyBinge',
              themeMode: themeState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              darkTheme: AppTheme.darkTheme(),
              theme: AppTheme.lightTheme(),
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: scaffoldMessengerKey,
              // Force dark theme like original TV Time
              debugShowCheckedModeBanner: false,
              scrollBehavior: const BouncingScrollBehavior(),
              home: const AuthGate(),
              onGenerateRoute: (settings) {
                final path = settings.name;
                if (path != null && path.length > 1) {
                  final parts = path.split('/');
                  final showIdStr = parts.lastWhere((e) => e.isNotEmpty, orElse: () => '');
                  final showId = int.tryParse(showIdStr);
                  if (showId != null) {
                    return MaterialPageRoute(
                      settings: settings,
                      builder: (context) => BlocProvider<ShowDetailsCubit>(
                        create: (context) => ShowDetailsCubit(tmdbClient: context.read<TmdbClient>()),
                        child: ShowDetailsPage(
                          mediaId: showId,
                          mediaType: 'tv',
                          title: 'Show Details',
                          initialTabIndex: 1,
                        ),
                      ),
                    );
                  }
                }
                return null;
              },
              onUnknownRoute: (settings) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const Scaffold(
                    backgroundColor: Colors.black,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Time-based throttle: prevent hammering Firestore on rapid AuthCubit emissions.
  // Static so _MyAppState can reset it from outside the widget tree when a
  // widget click is received (signals the user returned after a background
  // mark-as-watched, meaning we must force a fresh sync regardless of elapsed time).
  static DateTime? _lastSyncTime;
  static const _syncThrottle = Duration(seconds: 30);

  /// Called by _MyAppState when HomeWidget.widgetClicked fires, ensuring the
  /// very next _syncWidget call bypasses the throttle.
  static void invalidateSyncThrottle() => _lastSyncTime = null;

  Future<void> _syncWidget(String uid) async {
    final now = DateTime.now();
    if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncThrottle) {
      return;
    }
    _lastSyncTime = now;
    try {
      await HomeWidget.saveWidgetData<String>('current_uid', uid);
      await WidgetService.syncWatchlistToWidget(uid);
    } catch (e) {
      debugPrint('AuthGate: Failed to sync widget data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listenWhen: (previous, current) => current is Authenticated,
      listener: (context, state) {
        if (state is Authenticated) {
          _syncWidget(state.user.uid);
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return const ShellNavigationPage();
        } else if (state is Unauthenticated || state is AuthLoginLoading) {
          return const LoginPage();
        } else if (state is AuthError) {
          // If error occurs, fall back to login page
          return const LoginPage();
        } else {
          // Loading states: keep showing the splash screen UI seamlessly
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D0D),
                image: DecorationImage(
                  image: AssetImage('assets/splash_background.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Hero(tag: 'app_logo', child: Image.asset('assets/images/logo.png', width: 160, height: 160)),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

class BouncingScrollBehavior extends ScrollBehavior {
  const BouncingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
