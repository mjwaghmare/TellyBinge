import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/theme/app_colors.dart';
import 'package:popverse/features/profile/domain/models/cinema_passport.dart';
import 'package:popverse/features/profile/domain/services/cinema_passport_service.dart';
import 'package:popverse/features/profile/presentation/widgets/cinema_passport_modal.dart';
import 'package:popverse/features/profile/presentation/widgets/passport_stamp_widget.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('CinemaPassportService', () {
    test('returns empty summary when no movies or shows are logged', () {
      final data = CinemaPassportService.evaluate(
        movies: [],
        shows: [],
      );

      expect(data.totalCountries, 0);
      expect(data.totalTitles, 0);
      expect(data.countries, isEmpty);
      expect(data.unlockedStampsCount, 0);
      expect(data.totalStampsCount, 8);
    });

    test('correctly evaluates movies and resolves origin country and language', () {
      final movies = [
        {
          'title': 'Parasite',
          'isWatched': true,
          'origin_country': 'KR',
          'original_language': 'ko',
          'watchedAt': '2024-05-10T12:00:00Z',
        },
        {
          'title': 'Oldboy',
          'isWatched': true,
          'origin_country': 'KR',
          'original_language': 'ko',
        },
        {
          'title': 'Spirited Away',
          'isWatched': true,
          'origin_country': 'JP',
          'original_language': 'ja',
        },
        {
          'title': 'Inception',
          'isWatched': true,
          'origin_country': 'US',
          'original_language': 'en',
        },
        {
          'title': 'Unwatched Movie',
          'isWatched': false,
          'origin_country': 'FR',
        },
      ];

      final shows = [
        {
          'name': 'Squid Game',
          'category': 'FINISHED',
          'origin_country': 'KR',
          'watchedEpisodes': [1, 2, 3],
        },
        {
          'name': 'Dark',
          'category': 'UP_TO_DATE',
          'origin_country': 'DE',
          'watchedEpisodes': [1],
        },
      ];

      final data = CinemaPassportService.evaluate(
        movies: movies,
        shows: shows,
      );

      expect(data.totalTitles, 6); // 4 watched movies + 2 watched shows = 6
      expect(data.totalCountries, 4); // KR, JP, US, DE

      final krVisit = data.countries.firstWhere((c) => c.code == 'KR');
      expect(krVisit.movieCount, 2);
      expect(krVisit.showCount, 1);
      expect(krVisit.totalTitles, 3);
      expect(krVisit.flagEmoji, '🇰🇷');
    });

    test('includes finished show even when watchedEpisodes is empty', () {
      final shows = [
        {
          'name': 'Crash Landing on You',
          'category': 'FINISHED',
          'origin_country': 'KR',
          'watchedEpisodes': <int>[],
        },
      ];

      final data = CinemaPassportService.evaluate(
        movies: [],
        shows: shows,
      );

      expect(data.totalTitles, 1);
      expect(data.totalCountries, 1);
      final kr = data.countries.first;
      expect(kr.code, 'KR');
      expect(kr.showCount, 1);
    });

    test('unlocks Seoul Cinephile when user reaches 5 Korean titles', () {
      final movies = List.generate(
        5,
        (i) => {
          'title': 'K-Movie $i',
          'isWatched': true,
          'origin_country': 'KR',
          'watchedAt': '2024-06-01T10:00:00Z',
        },
      );

      final data = CinemaPassportService.evaluate(
        movies: movies,
        shows: [],
      );

      final stamp = data.stamps.firstWhere((s) => s.id == 'seoul_cinephile');
      expect(stamp.isUnlocked, isTrue);
      expect(stamp.currentCount, 5);
      expect(stamp.unlockedDate, contains('JUN 2024'));
      expect(stamp.shape, PassportStampShape.circular);
      expect(stamp.entryCode, 'ICN-082');
    });

    test('unlocks Euro Pass when watching from 3 European nations', () {
      final movies = [
        {'title': 'Amelie', 'isWatched': true, 'origin_country': 'FR'},
        {'title': 'Life is Beautiful', 'isWatched': true, 'origin_country': 'IT'},
        {'title': 'Another Round', 'isWatched': true, 'origin_country': 'DK'},
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      final euroStamp = data.stamps.firstWhere((s) => s.id == 'euro_explorer');

      expect(euroStamp.isUnlocked, isTrue);
      expect(euroStamp.currentCount, 3);
      expect(euroStamp.shape, PassportStampShape.roundedRectangle);
      expect(euroStamp.entryCode, 'SCHENGEN-ZONE');
    });

    test('skips titles with unresolvable country and does not default to US', () {
      final movies = [
        {
          'title': 'Unknown Mystery Title',
          'isWatched': true,
          'origin_country': null,
          'original_language': null,
        },
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      expect(data.totalTitles, 0);
      expect(data.totalCountries, 0);
      expect(data.countries, isEmpty);
    });

    test('recognizes valid 2-letter ISO countries outside _countryInfo', () {
      final movies = [
        {
          'title': 'Lamb',
          'isWatched': true,
          'origin_country': 'IS',
        },
        {
          'title': 'Cold War',
          'isWatched': true,
          'origin_country': 'PL',
        },
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      expect(data.totalTitles, 2);
      expect(data.totalCountries, 2);
      expect(data.countries.map((c) => c.code), containsAll(['IS', 'PL']));
    });

    test('sets unlockedDate to null when a stamp is locked or qualifying titles lack dates', () {
      final movies = [
        {'title': 'Amelie', 'isWatched': true, 'origin_country': 'FR'},
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      final frStamp = data.stamps.firstWhere((s) => s.id == 'cannes_vibes');
      expect(frStamp.isUnlocked, isFalse);
      expect(frStamp.unlockedDate, isNull);
    });

    test('prefers watchedAt over addedAt for shows and falls back when watchedAt is absent', () {
      final shows = [
        {
          'name': 'Show 1',
          'category': 'FINISHED',
          'origin_country': 'KR',
          'watchedAt': '2024-03-15T12:00:00Z',
          'addedAt': '2024-01-01T12:00:00Z',
        },
        {
          'name': 'Show 2',
          'category': 'FINISHED',
          'origin_country': 'KR',
          'watchedAt': null,
          'addedAt': '2024-02-10T12:00:00Z',
        },
      ];

      final data = CinemaPassportService.evaluate(movies: [], shows: shows);
      expect(data.totalTitles, 2);
      expect(data.totalCountries, 1);
    });

    test('sets stamp date to null when any qualifying title lacks usable date instead of picking later dated title', () {
      final movies = [
        {'title': 'K1', 'isWatched': true, 'origin_country': 'KR', 'watchedAt': '2024-01-01T10:00:00Z'},
        {'title': 'K2', 'isWatched': true, 'origin_country': 'KR', 'watchedAt': '2024-02-01T10:00:00Z'},
        {'title': 'K3', 'isWatched': true, 'origin_country': 'KR', 'watchedAt': null, 'addedAt': null},
        {'title': 'K4', 'isWatched': true, 'origin_country': 'KR', 'watchedAt': '2024-04-01T10:00:00Z'},
        {'title': 'K5', 'isWatched': true, 'origin_country': 'KR', 'watchedAt': '2024-05-01T10:00:00Z'},
        {'title': 'K6', 'isWatched': true, 'origin_country': 'KR', 'watchedAt': '2024-06-01T10:00:00Z'},
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      final stamp = data.stamps.firstWhere((s) => s.id == 'seoul_cinephile');
      expect(stamp.isUnlocked, isTrue);
      // Because one qualifying title lacks a usable date, unlock date must be null
      expect(stamp.unlockedDate, isNull);
    });

    test('sets Euro Pass unlock date to null when a qualifying European country has title lacking date', () {
      final movies = [
        {'title': 'Amelie', 'isWatched': true, 'origin_country': 'FR', 'watchedAt': '2024-01-01T10:00:00Z'},
        {'title': 'Life is Beautiful', 'isWatched': true, 'origin_country': 'IT', 'watchedAt': null, 'addedAt': null},
        {'title': 'Another Round', 'isWatched': true, 'origin_country': 'DK', 'watchedAt': '2024-03-01T10:00:00Z'},
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      final euroStamp = data.stamps.firstWhere((s) => s.id == 'euro_explorer');
      expect(euroStamp.isUnlocked, isTrue);
      expect(euroStamp.unlockedDate, isNull);
    });

    test('sets Globe Trotter unlock date to null when any visited country has title lacking date', () {
      final movies = [
        {'title': 'M1', 'isWatched': true, 'origin_country': 'US', 'watchedAt': '2024-01-01T10:00:00Z'},
        {'title': 'M2', 'isWatched': true, 'origin_country': 'GB', 'watchedAt': '2024-02-01T10:00:00Z'},
        {'title': 'M3', 'isWatched': true, 'origin_country': 'FR', 'watchedAt': '2024-03-01T10:00:00Z'},
        {'title': 'M4', 'isWatched': true, 'origin_country': 'IT', 'watchedAt': '2024-04-01T10:00:00Z'},
        {'title': 'M5', 'isWatched': true, 'origin_country': 'JP', 'watchedAt': null, 'addedAt': null},
      ];

      final data = CinemaPassportService.evaluate(movies: movies, shows: []);
      final globeStamp = data.stamps.firstWhere((s) => s.id == 'globe_trotter');
      expect(globeStamp.isUnlocked, isTrue);
      expect(globeStamp.unlockedDate, isNull);
    });
  });

  group('PassportStampWidget', () {
    testWidgets('renders locked stamp with lock icon and progress count', (
      tester,
    ) async {
      const stamp = PassportStamp(
        id: 'tokyo_dreams',
        title: 'TOKYO DREAMS',
        subtitle: 'NARITA IMMIGRATION',
        countryCode: 'JP',
        flagEmoji: '🇯🇵',
        inkColor: AppColors.error,
        rotationAngle: 0.06,
        requiredCount: 5,
        currentCount: 2,
        isUnlocked: false,
        description: 'Watch 5+ Japanese films',
        shape: PassportStampShape.hexagonal,
        entryCode: 'NRT-PERMIT',
      );

      await tester.pumpWidget(
        buildApp(
          const PassportStampWidget(stamp: stamp),
        ),
      );

      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.text('TOKYO DREAMS'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('renders locked stamp with lightTextTertiary colors in light theme', (
      tester,
    ) async {
      const stamp = PassportStamp(
        id: 'tokyo_dreams',
        title: 'TOKYO DREAMS',
        subtitle: 'NARITA IMMIGRATION',
        countryCode: 'JP',
        flagEmoji: '🇯🇵',
        inkColor: AppColors.error,
        rotationAngle: 0.06,
        requiredCount: 5,
        currentCount: 2,
        isUnlocked: false,
        description: 'Watch 5+ Japanese films',
        shape: PassportStampShape.hexagonal,
        entryCode: 'NRT-PERMIT',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: Center(
              child: PassportStampWidget(stamp: stamp),
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.lock_outline_rounded));
      expect(icon.color, AppColors.lightTextTertiary);

      final title = tester.widget<Text>(find.text('TOKYO DREAMS'));
      expect(title.style?.color, AppColors.lightTextTertiary);

      final progress = tester.widget<Text>(find.text('2 / 5'));
      expect(progress.style?.color, AppColors.lightTextTertiary);
    });

    testWidgets('renders unlocked stamp with authentic border control text, date, and entryCode', (
      tester,
    ) async {
      bool tapped = false;
      const stamp = PassportStamp(
        id: 'hollywood_calling',
        title: 'HOLLYWOOD CALLING',
        subtitle: 'LOS ANGELES • CBP ENTRY',
        countryCode: 'US',
        flagEmoji: '🇺🇸',
        inkColor: AppColors.accentBlue,
        rotationAngle: -0.05,
        requiredCount: 15,
        currentCount: 15,
        isUnlocked: true,
        unlockedDate: '12 OCT 2024',
        description: 'Watch 15+ American films',
        shape: PassportStampShape.oval,
        entryCode: 'LAX-CLASS-A',
      );

      await tester.pumpWidget(
        buildApp(
          PassportStampWidget(
            stamp: stamp,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('HOLLYWOOD CALLING'), findsOneWidget);
      expect(find.text('LAX-CLASS-A'), findsOneWidget);
      expect(find.text('12 OCT 2024'), findsOneWidget);
      expect(find.text('LOS ANGELES • CBP ENTRY'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(2));

      await tester.tap(find.byType(PassportStampWidget));
      expect(tapped, isTrue);
    });

    testWidgets('renders all 4 shapes without error', (tester) async {
      final shapes = [
        PassportStampShape.circular,
        PassportStampShape.roundedRectangle,
        PassportStampShape.oval,
        PassportStampShape.hexagonal,
      ];

      for (final shape in shapes) {
        final stamp = PassportStamp(
          id: 'test_${shape.name}',
          title: 'TEST STAMP',
          subtitle: 'SUBTITLE',
          countryCode: 'US',
          flagEmoji: '🇺🇸',
          inkColor: Colors.blue,
          rotationAngle: 0.05,
          requiredCount: 1,
          currentCount: 1,
          isUnlocked: true,
          unlockedDate: 'ENTRY PERMITTED',
          description: 'Description',
          shape: shape,
          entryCode: 'PASS',
        );

        await tester.pumpWidget(
          buildApp(PassportStampWidget(stamp: stamp)),
        );

        expect(find.text('TEST STAMP'), findsOneWidget);
      }
    });
  });

  group('CinemaPassportModal', () {
    testWidgets('renders modal and switches between STAMPS and DESTINATIONS tabs cleanly', (
      tester,
    ) async {
      const passportData = CinemaPassportData(
        totalCountries: 2,
        totalTitles: 5,
        countries: [
          CountryVisit(
            code: 'KR',
            name: 'South Korea',
            flagEmoji: '🇰🇷',
            movieCount: 3,
            showCount: 1,
          ),
          CountryVisit(
            code: 'US',
            name: 'United States',
            flagEmoji: '🇺🇸',
            movieCount: 1,
            showCount: 0,
          ),
        ],
        stamps: [
          PassportStamp(
            id: 'seoul_cinephile',
            title: 'SEOUL CINEPHILE',
            subtitle: 'K-DRAMA DIVISION',
            countryCode: 'KR',
            flagEmoji: '🇰🇷',
            inkColor: Colors.cyan,
            rotationAngle: -0.07,
            requiredCount: 5,
            currentCount: 4,
            isUnlocked: false,
            description: 'Watch 5+ Korean films',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CinemaPassportModal(
              data: passportData,
              username: 'cinephile',
              rankTitle: 'Film Buff',
            ),
          ),
        ),
      );

      // Verify header card and profile elements
      expect(find.text('WORLD CINEMA PASSPORT'), findsOneWidget);
      expect(find.text('@cinephile'), findsOneWidget);
      expect(find.text('Film Buff'), findsOneWidget);

      // Tab 1 (STAMPS) shows Seoul Cinephile
      expect(find.text('SEOUL CINEPHILE'), findsOneWidget);

      // Switch to Tab 2 (DESTINATIONS)
      await tester.tap(find.textContaining('DESTINATIONS'));
      await tester.pumpAndSettle();

      // Verify country list is displayed without multi-controller attachment error
      expect(find.text('South Korea'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets('CinemaPassportModal.show accepts precomputed CinemaPassportData', (
      tester,
    ) async {
      const passportData = CinemaPassportData(
        totalCountries: 1,
        totalTitles: 1,
        countries: [],
        stamps: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CinemaPassportModal.show(
                context,
                data: passportData,
                username: 'cinephile',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('WORLD CINEMA PASSPORT'), findsOneWidget);
    });
  });
}

