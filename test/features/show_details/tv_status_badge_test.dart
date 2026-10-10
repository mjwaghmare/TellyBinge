import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/show_details/presentation/widgets/tv_status_badge.dart';

void main() {
  group('TvStatusBadge Parsing & Labels', () {
    test('correctly parses and labels Returning Series', () {
      expect(
        TvStatusBadge.parseStatus('Returning Series'),
        TvShowStatusType.returning,
      );
      expect(
        TvStatusBadge.getLabel(
          'Returning Series',
          TvShowStatusType.returning,
        ),
        'RETURNING SERIES',
      );
    });

    test('correctly parses and labels Ended', () {
      expect(
        TvStatusBadge.parseStatus('Ended'),
        TvShowStatusType.ended,
      );
      expect(
        TvStatusBadge.getLabel('Ended', TvShowStatusType.ended),
        'ENDED',
      );
    });

    test('correctly parses and labels Canceled / Cancelled', () {
      expect(
        TvStatusBadge.parseStatus('Canceled'),
        TvShowStatusType.cancelled,
      );
      expect(
        TvStatusBadge.parseStatus('Cancelled'),
        TvShowStatusType.cancelled,
      );
      expect(
        TvStatusBadge.getLabel('Canceled', TvShowStatusType.cancelled),
        'CANCELLED',
      );
    });

    test('correctly parses and labels In Production and Planned', () {
      expect(
        TvStatusBadge.parseStatus('In Production'),
        TvShowStatusType.upcoming,
      );
      expect(
        TvStatusBadge.getLabel('In Production', TvShowStatusType.upcoming),
        'IN PRODUCTION',
      );
      expect(
        TvStatusBadge.parseStatus('Planned'),
        TvShowStatusType.upcoming,
      );
      expect(
        TvStatusBadge.getLabel('Planned', TvShowStatusType.upcoming),
        'PLANNED',
      );
    });

    test('labels upcoming show as UPCOMING when first air date is in future', () {
      final futureDate = DateTime.now().add(const Duration(days: 30)).toIso8601String();
      expect(
        TvStatusBadge.parseStatus(
          'Returning Series',
          numberOfSeasons: 1,
          firstAirDate: futureDate,
        ),
        TvShowStatusType.upcoming,
      );
      expect(
        TvStatusBadge.getLabel('Returning Series', TvShowStatusType.upcoming),
        'UPCOMING',
      );
    });

    test('labels 1-season show as NEW SERIES instead of RETURNING SERIES', () {
      expect(
        TvStatusBadge.parseStatus(
          'Returning Series',
          numberOfSeasons: 1,
          firstAirDate: '2024-01-01',
        ),
        TvShowStatusType.newSeries,
      );
      expect(
        TvStatusBadge.getLabel('Returning Series', TvShowStatusType.newSeries),
        'NEW SERIES',
      );
    });

    test('labels zero or absent season counts as RETURNING SERIES', () {
      expect(
        TvStatusBadge.parseStatus(
          'Returning Series',
          numberOfSeasons: 0,
          firstAirDate: '2022-01-01',
        ),
        TvShowStatusType.returning,
      );
      expect(
        TvStatusBadge.parseStatus(
          'Returning Series',
          firstAirDate: '2022-01-01',
        ),
        TvShowStatusType.returning,
      );
    });
  });

  group('TvStatusBadge Widget Rendering', () {
    testWidgets('renders RETURNING SERIES badge with indicator dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvStatusBadge(status: 'Returning Series', isHero: true),
          ),
        ),
      );

      expect(find.text('RETURNING SERIES'), findsOneWidget);
    });

    testWidgets('renders ENDED badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvStatusBadge(status: 'Ended', isHero: false),
          ),
        ),
      );

      expect(find.text('ENDED'), findsOneWidget);
    });

    testWidgets('renders CANCELLED badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvStatusBadge(status: 'Canceled', isHero: true),
          ),
        ),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
    });

    testWidgets('renders nothing when status is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvStatusBadge(status: '   ', isHero: true),
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
    });
  });
}
