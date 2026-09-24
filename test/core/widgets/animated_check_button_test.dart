import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/theme/app_colors.dart';
import 'package:popverse/core/widgets/animated_check_button.dart';

void main() {
  Widget buildTestWidget({
    required bool isWatched,
    bool isLoading = false,
    bool isFinale = false,
    bool isMovie = false,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: AnimatedCheckButton(
            isWatched: isWatched,
            isLoading: isLoading,
            isFinale: isFinale,
            isMovie: isMovie,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  group('AnimatedCheckButton', () {
    testWidgets('renders inactive checkmark when isWatched is false', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(isWatched: false),
      );

      expect(find.byType(AnimatedCheckButton), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tapping invokes onTap and immediately pops checkmark optimistically', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: false,
          isFinale: true,
          onTap: () {
            tapped = true;
          },
        ),
      );

      await tester.tap(find.byType(AnimatedCheckButton));
      await tester.pump();

      expect(tapped, isTrue);

      // Verify particle CustomPaint is active during burst
      expect(find.byType(CustomPaint), findsWidgets);

      // Settle animations
      await tester.pumpAndSettle();
    });

    testWidgets('shows loading indicator when isLoading is true initially', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: false,
          isLoading: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('active state renders success color and checkmark', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: true,
        ),
      );

      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.success);
    });

    testWidgets('reverts optimistic state on next frame if parent does not confirm loading or watched', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: false,
          onTap: () {
            // Parent does not confirm loading or watched state
          },
        ),
      );

      await tester.tap(find.byType(AnimatedCheckButton));
      // Pump initial tap frame
      await tester.pump();

      // Pump post-frame callback
      await tester.pump();
      await tester.pumpAndSettle();

      final containerFinder = find.byType(AnimatedContainer);
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      // Should have reverted to inactive background
      expect(decoration.color != AppColors.success, isTrue);
    });

    testWidgets('restores checkmark when unwatch loading finishes without isWatched changing', (tester) async {
      // 1. Initial watched state
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: true,
          isLoading: false,
        ),
      );

      // 2. Unwatch loading in progress
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: true,
          isLoading: true,
        ),
      );

      // 3. Unwatch failed / cancelled: loading becomes false, isWatched is still true
      await tester.pumpWidget(
        buildTestWidget(
          isWatched: true,
          isLoading: false,
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byType(AnimatedContainer);
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.success);
    });
  });
}
