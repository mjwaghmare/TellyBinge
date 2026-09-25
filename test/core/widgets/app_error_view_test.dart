import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/core/errors/failures.dart';
import 'package:popverse/core/widgets/app_error_view.dart';

void main() {
  Widget buildTestWidget({
    required Failure failure,
    VoidCallback? onRetry,
    String? title,
    String? retryLabel,
    Widget? image,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AppErrorView(
          failure: failure,
          onRetry: onRetry,
          title: title,
          retryLabel: retryLabel,
          image: image ?? const SizedBox(key: Key('placeholder_image')),
        ),
      ),
    );
  }

  group('AppErrorView', () {
    testWidgets('displays Connection Error title and message for NetworkFailure', (tester) async {
      const failure = NetworkFailure('Check your internet connection.');
      await tester.pumpWidget(buildTestWidget(failure: failure));

      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.text('Check your internet connection.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('displays Item Not Found title for ServerFailure 404', (tester) async {
      const failure = ServerFailure('Movie not found', code: '404');
      await tester.pumpWidget(buildTestWidget(failure: failure));

      expect(find.text('Item Not Found'), findsOneWidget);
      expect(find.text('Movie not found'), findsOneWidget);
    });

    testWidgets('displays custom title when provided', (tester) async {
      const failure = UnexpectedFailure('Unexpected error occurred');
      await tester.pumpWidget(
        buildTestWidget(
          failure: failure,
          title: 'Custom Error Title',
        ),
      );

      expect(find.text('Custom Error Title'), findsOneWidget);
      expect(find.text('Unexpected error occurred'), findsOneWidget);
    });

    testWidgets('renders RETRY button and triggers callback on tap', (tester) async {
      bool retryPressed = false;
      const failure = NetworkFailure('Failed to connect');

      await tester.pumpWidget(
        buildTestWidget(
          failure: failure,
          onRetry: () => retryPressed = true,
        ),
      );

      final retryButton = find.text('RETRY');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      expect(retryPressed, isTrue);
    });

    testWidgets('renders custom retryLabel when provided', (tester) async {
      const failure = NetworkFailure('Failed to connect');

      await tester.pumpWidget(
        buildTestWidget(
          failure: failure,
          onRetry: () {},
          retryLabel: 'TRY AGAIN',
        ),
      );

      expect(find.text('TRY AGAIN'), findsOneWidget);
      expect(find.text('RETRY'), findsNothing);
    });

    testWidgets('renders custom image widget when provided', (tester) async {
      const failure = NetworkFailure('Failed to connect');
      const customKey = Key('custom_image_widget');

      await tester.pumpWidget(
        buildTestWidget(
          failure: failure,
          image: const Icon(Icons.wifi_off, key: customKey),
        ),
      );

      expect(find.byKey(customKey), findsOneWidget);
    });
  });
}
