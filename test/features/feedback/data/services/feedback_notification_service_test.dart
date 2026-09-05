import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popverse/features/feedback/data/services/feedback_notification_service.dart';

void main() {
  test('returns false when no access key is configured', () async {
    final service = FeedbackNotificationService(accessKey: '');

    final result = await service.notifyAdmin(
      feedbackId: 'fb-123',
      title: 'Bug title',
      description: 'Bug description',
      category: 'bug',
      severity: 'high',
      userName: 'Test User',
      userEmail: 'test@example.com',
      userId: 'user-1',
      appVersion: 'v1.0.0+1',
      mediaUrls: [],
    );

    expect(result, isFalse);
  });

  test('sends payload correctly when configured with an access key', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final data = options.data as Map<String, dynamic>;
          expect(data['access_key'], 'mock-key');
          expect(data['Title'], 'Player crash');
          expect(data['Category'], 'Bug');
          expect(data['Severity'], 'critical');
          expect(data['email'], 'user@example.com');
          expect(data['botcheck'], '');
          expect(data['Platform'], isNotNull);
          expect(data['Screenshots'], '1. https://cloudinary.com/image.png');
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'message': 'Email sent'},
            ),
          );
        },
      ),
    );

    final service = FeedbackNotificationService(
      dio: dio,
      accessKey: 'mock-key',
    );

    final result = await service.notifyAdmin(
      feedbackId: 'fb-456',
      title: 'Player crash',
      description: 'Player crashed on start',
      category: 'bug',
      severity: 'critical',
      userName: 'John',
      userEmail: 'user@example.com',
      userId: 'user-456',
      appVersion: 'v1.0.0+1',
      mediaUrls: ['https://cloudinary.com/image.png'],
    );

    expect(result, isTrue);
  });

  test('sanitizes CRLF in title and safely ignores malformed user email', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final data = options.data as Map<String, dynamic>;
          expect(data['subject'], contains('Title with new lines'));
          expect(data['subject'], isNot(contains('\n')));
          expect(data['Title'], 'Title with new lines');
          // Malformed email should not be sent
          expect(data.containsKey('email'), isFalse);
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true},
            ),
          );
        },
      ),
    );

    final service = FeedbackNotificationService(
      dio: dio,
      accessKey: 'mock-key',
    );

    final result = await service.notifyAdmin(
      feedbackId: 'fb-789',
      title: 'Title\r\nwith\nnew lines',
      description: 'Some description',
      category: 'feature',
      severity: null,
      userName: 'Bob',
      userEmail: 'not-an-email',
      userId: 'user-789',
      appVersion: 'v1.0.0',
      mediaUrls: [],
    );

    expect(result, isTrue);
  });
}
