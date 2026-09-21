import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/domain/models/genre_stat.dart';
import 'package:popverse/features/profile/presentation/widgets/genre_breakdown_card.dart';

void main() {
  const sampleStats = [
    GenreStat(genre: 'Action', count: 12, percentage: 40.0),
    GenreStat(genre: 'Sci-Fi', count: 9, percentage: 30.0),
    GenreStat(genre: 'Drama', count: 6, percentage: 20.0),
    GenreStat(genre: 'Other', count: 3, percentage: 10.0),
  ];

  Widget buildTestWidget({
    List<GenreStat> stats = sampleStats,
    ThemeMode themeMode = ThemeMode.dark,
  }) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: GenreBreakdownCard(stats: stats),
        ),
      ),
    );
  }

  testWidgets('GenreBreakdownCard renders empty state when stats are empty',
      (tester) async {
    await tester.pumpWidget(buildTestWidget(stats: []));

    expect(find.text('No TV Show Genre Data'), findsOneWidget);
    expect(
      find.text('Mark episodes as watched to uncover your TV Genre DNA.'),
      findsOneWidget,
    );
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('GenreBreakdownCard renders chart and legend with stats',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());

    expect(find.byType(PieChart), findsOneWidget);

    // Legend entries
    expect(find.text('Action'), findsWidgets);
    expect(find.text('Sci-Fi'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    // Percentage text
    expect(find.text('40%'), findsWidgets);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);

    // Default center indicator shows #1 top genre
    expect(find.text('Top Genre'), findsOneWidget);
  });

  testWidgets('Tapping legend item updates center summary and selection',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Initially Top Genre is visible in the center
    expect(find.text('Top Genre'), findsOneWidget);

    // Tap 'Sci-Fi' in the legend
    await tester.tap(find.text('Sci-Fi'));
    await tester.pumpAndSettle();

    // Center summary should now show Sci-Fi count
    expect(find.text('9 titles'), findsOneWidget);
    expect(find.text('Top Genre'), findsNothing);

    // Tap 'Sci-Fi' again to deselect (using .last since it appears in center summary too)
    await tester.tap(find.text('Sci-Fi').last);
    await tester.pumpAndSettle();

    // Should return to Top Genre
    expect(find.text('Top Genre'), findsOneWidget);
  });

  testWidgets('Genre legend is scrollable when entries exceed visible height',
      (tester) async {
    const extendedStats = [
      GenreStat(genre: 'Action', count: 12, percentage: 30.0),
      GenreStat(genre: 'Sci-Fi', count: 9, percentage: 22.5),
      GenreStat(genre: 'Drama', count: 6, percentage: 15.0),
      GenreStat(genre: 'Comedy', count: 5, percentage: 12.5),
      GenreStat(genre: 'Horror', count: 4, percentage: 10.0),
      GenreStat(genre: 'Animation', count: 2, percentage: 5.0),
      GenreStat(genre: 'Other', count: 2, percentage: 5.0),
    ];

    await tester.pumpWidget(buildTestWidget(stats: extendedStats));

    final listViewFinder = find.byType(ListView);
    expect(listViewFinder, findsOneWidget);

    // Scroll down to reveal the last item if needed
    await tester.drag(listViewFinder, const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(find.text('Other'), findsOneWidget);
  });
}
