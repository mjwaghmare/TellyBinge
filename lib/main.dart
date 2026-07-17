import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app/shell_navigation_page.dart';
import 'core/network/tmdb_client.dart';
import 'core/storage/settings_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/cubit/theme_cubit.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  final isOledInitial = settings['oled_dark_mode'] as bool? ?? false;

  runApp(MyApp(
    settingsStorage: settingsStorage,
    isOledInitial: isOledInitial,
  ));
}

class MyApp extends StatelessWidget {
  final SettingsStorage settingsStorage;
  final bool isOledInitial;

  const MyApp({
    super.key,
    required this.settingsStorage,
    required this.isOledInitial,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SettingsStorage>.value(value: settingsStorage),
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
          BlocProvider<ThemeCubit>(
            create: (context) => ThemeCubit(
              storage: context.read<SettingsStorage>(),
              isOledInitial: isOledInitial,
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
              themeMode: ThemeMode.dark,
              darkTheme: AppTheme.darkTheme(themeState.isOledDarkMode),
              theme: AppTheme.darkTheme(themeState.isOledDarkMode),
              // Force dark theme like original TV Time
              debugShowCheckedModeBanner: false,
              scrollBehavior: const BouncingScrollBehavior(),
              home: const AuthGate(),
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFC107), // Amber 500
                    Color(0xFFFFEB3B), // Yellow 500
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Hero(tag: 'app_logo', child: Image.asset('assets/images/logo.png', width: 160, height: 160)),
                  ),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 30.0),
                      child: Text(
                        'Made with ❤️ by MWStudio',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w700,
                          // fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
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
