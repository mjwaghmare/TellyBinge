import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/profile/domain/models/achievement.dart';
import 'package:popverse/features/profile/presentation/widgets/achievement_detail_bottom_sheet.dart';

void main() {
  const singleTierPending = Achievement(
    id: 'night_owl',
    title: 'Night Owl',
    description: 'Log an item between 1:00 AM and 4:30 AM',
    category: AchievementCategory.habits,
    icon: Icons.nightlight_rounded,
    assetPath: 'assets/awards/night_owl.jpg',
    currentValue: 0,
    targetValue: 1,
    isUnlocked: false,
  );

  const singleTierCompleted = Achievement(
    id: 'first_step',
    title: 'First Step',
    description: 'Log your very first Movie or TV Episode',
    category: AchievementCategory.volume,
    icon: Icons.rocket_launch_rounded,
    assetPath: 'assets/awards/first_step.jpg',
    currentValue: 1,
    targetValue: 1,
    isUnlocked: true,
  );

  const multiTierSilver = Achievement(
    id: 'movie_buff',
    title: 'Movie Buff',
    description: 'Watch movies to earn higher tiers',
    category: AchievementCategory.volume,
    icon: Icons.movie_creation_rounded,
    assetPath: 'assets/awards/movie_buff.jpg',
    tier: AchievementTier.silver,
    currentValue: 100,
    targetValue: 250,
    isUnlocked: true,
    tierTargets: {
      AchievementTier.bronze: 25,
      AchievementTier.silver: 100,
      AchievementTier.gold: 250,
      AchievementTier.diamond: 500,
    },
  );

  const multiTierDiamond = Achievement(
    id: 'movie_buff',
    title: 'Movie Buff',
    description: 'Watch movies to earn higher tiers',
    category: AchievementCategory.volume,
    icon: Icons.movie_creation_rounded,
    assetPath: 'assets/awards/movie_buff.jpg',
    tier: AchievementTier.diamond,
    currentValue: 500,
    targetValue: 500,
    isUnlocked: true,
    tierTargets: {
      AchievementTier.bronze: 25,
      AchievementTier.silver: 100,
      AchievementTier.gold: 250,
      AchievementTier.diamond: 500,
    },
  );

  Widget createTestWidget(Achievement achievement, {bool isCelebration = false}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AchievementDetailBottomSheet.show(
              context,
              achievement,
              isCelebration: isCelebration,
            ),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    );
  }

  testWidgets('single-tier pending achievement shows progress indicator and completed/remaining text', (tester) async {
    await tester.pumpWidget(createTestWidget(singleTierPending));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Night Owl'), findsOneWidget);
    expect(find.text('0 / 1 completed'), findsOneWidget);
    expect(find.text('1 remaining'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('single-tier completed achievement does NOT show progress indicator or completed/remaining text', (tester) async {
    await tester.pumpWidget(createTestWidget(singleTierCompleted));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('First Step'), findsOneWidget);
    expect(find.textContaining('completed'), findsNothing);
    expect(find.textContaining('remaining'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('multi-tier achievement at Silver shows milestone stepper and next Gold goal', (tester) async {
    await tester.pumpWidget(createTestWidget(multiTierSilver));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Verify badge title and tier pill
    expect(find.text('Movie Buff'), findsOneWidget);
    expect(find.text('SILVER TIER'), findsOneWidget);

    // Verify milestone labels are present
    expect(find.text('Bronze'), findsOneWidget);
    expect(find.text('Silver'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Diamond'), findsOneWidget);

    // Verify next tier progress towards Gold
    expect(find.text('Next: Gold Tier (100 / 250)'), findsOneWidget);
    expect(find.text('150 remaining'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('multi-tier achievement at Diamond shows max tier completed state with no progress bar', (tester) async {
    await tester.pumpWidget(createTestWidget(multiTierDiamond));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Movie Buff'), findsOneWidget);
    expect(find.text('DIAMOND TIER (MAX)'), findsOneWidget);
    expect(find.text('ALL TIERS COMPLETED'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('celebration mode does NOT show progress indicator for multi-tier achievements', (tester) async {
    await tester.pumpWidget(createTestWidget(multiTierSilver, isCelebration: true));
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Movie Buff'), findsOneWidget);
    expect(find.text('SILVER TIER'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('remaining'), findsNothing);
  });

  testWidgets('badge emblem plays entrance animation and can be tapped to re-spin', (tester) async {
    await tester.pumpWidget(createTestWidget(singleTierCompleted));
    await tester.tap(find.text('Open Sheet'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);

    // Tap on badge to trigger interactive spin
    await tester.tap(find.byType(Image));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  });
}
