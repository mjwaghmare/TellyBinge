import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/constants/app_storage_keys.dart';
import 'package:popverse/core/network/tmdb_client.dart';
import 'package:popverse/features/profile/presentation/cubit/settings_cubit.dart';
import 'package:popverse/features/profile/presentation/widgets/preferred_genres_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late TmdbClient tmdbClient;
  late SettingsCubit settingsCubit;

  setUp(() async {
    await dotenv.load(mergeWith: {});
    SharedPreferences.setMockInitialValues({
      AppStorageKeys.preferredGenres: ['Action', 'Comedy'],
    });
    prefs = await SharedPreferences.getInstance();
    tmdbClient = TmdbClient();
    settingsCubit = SettingsCubit(prefs: prefs, tmdbClient: tmdbClient);
  });

  tearDown(() {
    settingsCubit.close();
  });

  Widget buildTestApp() {
    return RepositoryProvider<SharedPreferences>.value(
      value: prefs,
      child: BlocProvider<SettingsCubit>.value(
        value: settingsCubit,
        child: const MaterialApp(
          home: Scaffold(
            body: PreferredGenresBottomSheet(),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'PreferredGenresBottomSheet displays genres and toggles selection',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pump();

    // Verify Title & Subtitle
    expect(find.text('Preferred Genres'), findsOneWidget);
    expect(
      find.textContaining('personalize your "FOR YOU" feed recommendations'),
      findsOneWidget,
    );

    // Verify genre options are rendered
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('Comedy'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Sci-Fi'), findsOneWidget);

    // Tap 'Sci-Fi' to add it to selection
    await tester.tap(find.text('Sci-Fi'));
    await tester.pump();

    // Tap Save Preferences button
    await tester.tap(find.text('Save Preferences'));
    await tester.pumpAndSettle();

    // Verify that SettingsCubit and prefs have updated
    expect(settingsCubit.state.preferredGenres, contains('Sci-Fi'));
    expect(
      prefs.getStringList(AppStorageKeys.preferredGenres),
      contains('Sci-Fi'),
    );
  });
}
