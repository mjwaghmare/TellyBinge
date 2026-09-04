import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FeedbackStorageService {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB per image
  static const int maxFileCount = 5;
  static const Set<String> allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  final Dio _dio;
  final FirebaseAuth _auth;

  FeedbackStorageService({Dio? dio, FirebaseAuth? auth})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ),
        _auth = auth ?? FirebaseAuth.instance;

  /// Uploads media files for a specific feedback ID to Cloudinary.
  /// Uses an unsigned upload preset so no secret keys are exposed on the client.
  /// Validates authentication, file count, allowed formats, and size limits before upload.
  /// Returns a list of secure HTTPS download URLs.
  Future<List<String>> uploadMedia({
    required String feedbackId,
    required List<String> localFilePaths,
  }) async {
    if (localFilePaths.isEmpty) return [];

    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      throw Exception('Authentication required to upload media.');
    }

    if (localFilePaths.length > maxFileCount) {
      throw Exception('Maximum of $maxFileCount images allowed per feedback submission.');
    }

    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim() ?? '';
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.trim() ?? '';

    if (cloudName.isEmpty || uploadPreset.isEmpty) {
      throw Exception(
        'Cloudinary configuration missing. Please set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UPLOAD_PRESET in your .env file.',
      );
    }

    final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

    final uploadFutures = localFilePaths.map((path) async {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('FeedbackStorageService: File does not exist at $path');
        return null;
      }

      final ext = path.contains('.') ? '.${path.split('.').last.toLowerCase()}' : '';
      if (!allowedExtensions.contains(ext)) {
        throw Exception(
          'Unsupported file format "$ext". Allowed formats are JPG, JPEG, PNG, and WEBP.',
        );
      }

      final fileSize = await file.length();
      if (fileSize > maxFileSizeBytes) {
        throw Exception('File exceeds maximum size limit of 10 MB.');
      }

      final fileName = path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: fileName),
        'upload_preset': uploadPreset,
        'folder': 'popverse_feedbacks/$feedbackId',
      });

      try {
        final response = await _dio.post<Map<String, dynamic>>(
          uploadUrl,
          data: formData,
        );

        if (response.statusCode == 200 && response.data != null) {
          final secureUrl = response.data!['secure_url'] as String?;
          if (secureUrl != null && secureUrl.isNotEmpty) {
            return secureUrl;
          }
        }
        throw Exception(
          'Cloudinary upload returned unexpected response: ${response.statusCode}',
        );
      } on DioException catch (e) {
        final errorMsg = e.response?.data?['error']?['message'] ?? e.message;
        debugPrint(
          'FeedbackStorageService: Cloudinary upload failed for $path: $errorMsg',
        );
        throw Exception('Failed to upload image: $errorMsg');
      } catch (e) {
        debugPrint('FeedbackStorageService: Upload failed for $path: $e');
        rethrow;
      }
    });

    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  /// Deletes feedback media folder if needed.
  Future<void> deleteFeedbackMedia(String feedbackId) async {
    // Note: Cloudinary requires a signed Admin API call with API Secret to delete assets,
    // which cannot be safely performed on the client. Assets can be managed via the Cloudinary dashboard.
    debugPrint(
      'FeedbackStorageService: deleteFeedbackMedia called for $feedbackId',
    );
  }
}
