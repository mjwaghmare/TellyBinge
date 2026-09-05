import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service responsible for dispatching email notifications to the admin
/// when a new feedback or bug report is submitted.
class FeedbackNotificationService {
  final Dio _dio;
  final String? _configuredAccessKey;

  FeedbackNotificationService({
    Dio? dio,
    String? accessKey,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            ),
        _configuredAccessKey = accessKey;

  String? get _accessKey {
    final key = _configuredAccessKey ??
        dotenv.env['WEB3FORMS_ACCESS_KEY']?.trim() ??
        dotenv.env['WEB3FORM']?.trim();
    return (key != null && key.isNotEmpty) ? key : null;
  }

  /// Sends an email notification to the admin with feedback details.
  /// This runs non-blocking and will safely catch and log any errors.
  Future<bool> notifyAdmin({
    required String feedbackId,
    required String title,
    required String description,
    required String category,
    required String? severity,
    required String userName,
    required String? userEmail,
    required String userId,
    required String appVersion,
    required List<String> mediaUrls,
  }) async {
    final accessKey = _accessKey;
    if (accessKey == null) {
      debugPrint(
        'FeedbackNotificationService: No Web3Forms access key found. Skipping email notification.',
      );
      return false;
    }

    final formattedCategory = category.isNotEmpty
        ? '${category[0].toUpperCase()}${category.substring(1)}'
        : 'Feedback';

    // Sanitize title to prevent header injection (CRLF) in subject lines
    final sanitizedTitle = title.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    final truncatedTitle = sanitizedTitle.length > 80
        ? '${sanitizedTitle.substring(0, 80)}...'
        : sanitizedTitle;

    final subject = severity != null && severity.isNotEmpty
        ? '[PopVerse $formattedCategory - ${severity.toUpperCase()}] $truncatedTitle'
        : '[PopVerse $formattedCategory] $truncatedTitle';

    // Validate email format to prevent Web3Forms 400 Bad Request rejection
    final trimmedEmail = userEmail?.trim();
    final isValidEmail = trimmedEmail != null &&
        RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$')
            .hasMatch(trimmedEmail);

    final payload = <String, dynamic>{
      'access_key': accessKey,
      'subject': subject,
      'from_name': 'PopVerse Feedback Bot',
      'name': userName.isNotEmpty ? userName : 'PopVerse Fan',
      if (isValidEmail) 'email': trimmedEmail,
      'botcheck': '', // Web3Forms honeypot field to pass spam filtering
      'Title': sanitizedTitle,
      'Category': formattedCategory,
      if (severity != null && severity.isNotEmpty) 'Severity': severity,
      'Platform': defaultTargetPlatform.name.toUpperCase(),
      'App Version': appVersion,
      'User ID': userId.isNotEmpty ? userId : 'Anonymous',
      'Feedback ID': feedbackId,
      'Description': description.trim(),
      if (mediaUrls.isNotEmpty)
        'Screenshots': mediaUrls
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n'),
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'https://api.web3forms.com/submit',
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data?['success'] == true) {
        debugPrint(
          'FeedbackNotificationService: Admin notification email sent successfully.',
        );
        return true;
      } else {
        debugPrint(
          'FeedbackNotificationService: Web3Forms returned unexpected response: ${response.statusCode} - ${response.data}',
        );
        return false;
      }
    } catch (e) {
      debugPrint(
        'FeedbackNotificationService: Failed to send admin notification: $e',
      );
      return false;
    }
  }
}
