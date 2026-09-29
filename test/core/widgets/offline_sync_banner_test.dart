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

  Widget buildTestWidget({ThemeMode themeMode = ThemeMode.dark}) {
    return BlocProvider<SyncStatusCubit>.value(
      value: syncStatusCubit,
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: OfflineSyncBanner(),
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
      expect(find.text('Offline · will sync'), findsOneWidget);
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

    testWidgets('renders cleanly in light mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.light));

      syncStatusCubit.updatePending('movies', offline(1));
      await tester.pumpAndSettle();

      expect(find.text('Offline · 1 change waiting'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });
}
