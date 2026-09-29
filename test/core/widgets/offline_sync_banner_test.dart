import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/sync/pending_writes.dart';
import 'package:popverse/core/sync/sync_status_cubit.dart';
import 'package:popverse/core/widgets/offline_sync_banner.dart';
import '../sync/sync_status_cubit_test.dart';

void main() {
  late FakeMovieWatchlistRepository movieRepo;
  late FakeTvWatchlistRepository tvRepo;
  late FakeCustomListsRepository listsRepo;
  late SyncStatusCubit syncStatusCubit;

  setUp(() {
    movieRepo = FakeMovieWatchlistRepository();
    tvRepo = FakeTvWatchlistRepository();
    listsRepo = FakeCustomListsRepository();
    syncStatusCubit = SyncStatusCubit(
      movieWatchlistRepository: movieRepo,
      tvWatchlistRepository: tvRepo,
      customListsRepository: listsRepo,
      pendingDebounceDuration: Duration.zero,
      settleDuration: Duration.zero,
    );
  });

  tearDown(() async {
    await syncStatusCubit.close();
    movieRepo.dispose();
    tvRepo.dispose();
    listsRepo.dispose();
  });

  Widget buildTestWidget({ThemeMode themeMode = ThemeMode.dark, double topInset = 0}) {
    return BlocProvider<SyncStatusCubit>.value(
      value: syncStatusCubit,
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: EdgeInsets.only(top: topInset)),
          child: child!,
        ),
        // Mirrors ShellNavigationPage: pinned to the top with unbounded height.
        home: const Scaffold(
          body: Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, child: OfflineSyncBanner()),
            ],
          ),
        ),
      ),
    );
  }

  group('OfflineSyncBanner', () {
    testWidgets('is hidden (opacity 0.0) by default when no writes are pending', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, equals(0.0));
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('displays the queued change count with cloud icon when offline', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      syncStatusCubit.updatePending('movies', offline(1));
      await tester.pumpAndSettle();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, equals(1.0));
      expect(find.text('Offline · 1 change waiting'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('displays "All changes synced" with checkmark icon when just synced', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // First set to pending
      syncStatusCubit.updatePending('movies', offline(1));
      await tester.pumpAndSettle();

      // Now resolve pending to trigger justSynced
      syncStatusCubit.updatePending('movies', PendingWrites.none);
      await tester.pumpAndSettle();

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, equals(1.0));
      expect(find.text('All changes synced'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Elapse the 3-second auto-dismiss timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('shows an animated percentage at the end while syncing', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      syncStatusCubit.updatePending('movies', offline(4));
      syncStatusCubit.updatePending('movies', online(4));
      await tester.pump();
      expect(find.text('Syncing'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
      expect(find.text(' · 1%'), findsOneWidget);

      syncStatusCubit.updatePending('movies', online(2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(' · 50%'), findsNothing); // still counting up
      await tester.pumpAndSettle();
      expect(find.text(' · 50%'), findsOneWidget);
    });

    testWidgets('hides the percentage while offline', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      syncStatusCubit.updatePending('movies', offline(3));
      await tester.pumpAndSettle();

      expect(find.text('Offline · 3 changes waiting'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    group('Dynamic Island detection', () {
      MediaQueryData withTop(double top) => MediaQueryData(padding: EdgeInsets.only(top: top));

      test('Island iPhones (59pt+ inset) are detected on iOS only', () {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(OfflineSyncBanner.hasDynamicIsland(withTop(59)), isTrue);
        expect(OfflineSyncBanner.hasDynamicIsland(withTop(62)), isTrue);
        expect(OfflineSyncBanner.hasDynamicIsland(withTop(47)), isFalse);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        expect(OfflineSyncBanner.hasDynamicIsland(withTop(59)), isFalse);
      });
    });

    testWidgets('on Island iPhones the text sits below the Island', (tester) async {
      await tester.pumpWidget(buildTestWidget(topInset: 59));
      syncStatusCubit.updatePending('movies', offline(1));
      await tester.pumpAndSettle();

      final textTop = tester.getTopLeft(find.text('Offline · 1 change waiting')).dy;
      expect(
        textTop,
        greaterThanOrEqualTo(OfflineSyncBanner.islandTop + OfflineSyncBanner.islandSize.height),
      );
      // Nothing wider than the Island may cover the status bar beside it.
      final pillTop = tester
          .getRect(find.ancestor(of: find.text('Offline · 1 change waiting'), matching: find.byType(AnimatedContainer)))
          .top;
      expect(
        pillTop,
        greaterThanOrEqualTo(OfflineSyncBanner.islandTop + OfflineSyncBanner.islandSize.height - 12),
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('elsewhere the pill sits just below the status bar', (tester) async {
      await tester.pumpWidget(buildTestWidget(topInset: 24));
      syncStatusCubit.updatePending('movies', offline(1));
      await tester.pumpAndSettle();

      final textTop = tester.getTopLeft(find.text('Offline · 1 change waiting')).dy;
      expect(textTop, inInclusiveRange(24, 24 + 40));
    });

    testWidgets('renders cleanly in light mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.light));

      syncStatusCubit.updatePending('movies', offline(1));
      await tester.pumpAndSettle();

      expect(find.text('Offline · 1 change waiting'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });
}
