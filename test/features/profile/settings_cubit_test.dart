import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popverse/core/constants/app_storage_keys.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/core/services/app_haptics.dart';
import 'package:popverse/features/profile/presentation/cubit/settings_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late TmdbClient tmdbClient;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tmdbClient = TmdbClient();
    AppHaptics.isEnabled = true;
  });

  group('SettingsCubit - Haptic Feedback', () {
    test('defaults to hapticsEnabled = true when no value in prefs', () {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      expect(cubit.state.hapticsEnabled, isTrue);
      expect(AppHaptics.isEnabled, isTrue);
    });

    test('loads existing hapticsEnabled = false from prefs', () async {
      await prefs.setBool(AppStorageKeys.hapticsEnabled, false);
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      expect(cubit.state.hapticsEnabled, isFalse);
      expect(AppHaptics.isEnabled, isFalse);
    });

    test('toggleHaptics(false) persists setting and updates AppHaptics', () async {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);
      expect(cubit.state.hapticsEnabled, isTrue);

      await cubit.toggleHaptics(false);

      expect(cubit.state.hapticsEnabled, isFalse);
      expect(prefs.getBool(AppStorageKeys.hapticsEnabled), isFalse);
      expect(AppHaptics.isEnabled, isFalse);
    });

    test('toggleHaptics(true) re-enables setting and AppHaptics', () async {
      await prefs.setBool(AppStorageKeys.hapticsEnabled, false);
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);
      expect(cubit.state.hapticsEnabled, isFalse);

      await cubit.toggleHaptics(true);

      expect(cubit.state.hapticsEnabled, isTrue);
      expect(prefs.getBool(AppStorageKeys.hapticsEnabled), isTrue);
      expect(AppHaptics.isEnabled, isTrue);
    });
  });

  group('SettingsCubit - Notification Settings', () {
    test('SettingsState defaults notify1DayBefore to false', () {
      const state = SettingsState();
      expect(state.notify1DayBefore, isFalse);
    });

    test('defaults to notify1DayBefore = false when no value in prefs', () {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      expect(cubit.state.notify1DayBefore, isFalse);
    });

    test('loads existing notify1DayBefore = true from prefs', () async {
      await prefs.setBool(AppStorageKeys.notify1DayBefore, true);
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      expect(cubit.state.notify1DayBefore, isTrue);
    });
  });

  group('SettingsCubit - Preferred Genres', () {
    test('defaults to empty preferred genres when no value in prefs', () {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      expect(cubit.state.preferredGenres, const []);
    });

    test('loads existing preferredGenres from prefs', () async {
      await prefs.setStringList(
        AppStorageKeys.preferredGenres,
        ['Thriller', 'Horror'],
      );
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      expect(cubit.state.preferredGenres, ['Thriller', 'Horror']);
    });

    test('setPreferredGenres updates state and saves to prefs', () async {
      final cubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);

      await cubit.setPreferredGenres(['Anime', 'Romance']);

      expect(cubit.state.preferredGenres, ['Anime', 'Romance']);
      expect(
        prefs.getStringList(AppStorageKeys.preferredGenres),
        ['Anime', 'Romance'],
      );
    });
  });
}
