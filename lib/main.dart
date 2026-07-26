import 'package:firebase_core/firebase_core.dart';
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

  await WidgetService.initialize();

  // Initialize notification and background services
  await NotificationService().initialize();
  await BackgroundSyncService().initialize();
  await BackgroundSyncService().registerPeriodicSync();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    HomeWidget.setAppGroupId(WidgetService.iOSGroupId);
  }

  @override
  void dispose() {
    super.dispose();
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          HomeWidget.saveWidgetData<String>('current_uid', state.user.uid);
          WidgetService.syncWatchlistToWidget(state.user.uid);
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
