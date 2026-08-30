import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FeedbackStorageService {
  final FirebaseStorage _storage;

  FeedbackStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads media files for a specific feedback ID to Firebase Storage.
  /// Storage hierarchy: `feedbacks/{feedbackId}/{fileName}`
  /// Returns a list of public download URLs.
  Future<List<String>> uploadMedia({
    required String feedbackId,
    required List<String> localFilePaths,
  }) async {
    if (localFilePaths.isEmpty) return [];

    final uploadFutures = localFilePaths.asMap().entries.map((entry) async {
      final i = entry.key;
      final path = entry.value;
      final file = File(path);

      if (!await file.exists()) {
        debugPrint('FeedbackStorageService: File does not exist at $path');
        return null;
      }

      final ext = path.toLowerCase().endsWith('.png')
          ? 'png'
          : (path.toLowerCase().endsWith('.webp') ? 'webp' : 'jpg');
      final mimeType = 'image/$ext';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_media_$i.$ext';
      final storagePath = 'feedbacks/$feedbackId/$fileName';
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: mimeType,
          customMetadata: {'feedbackId': feedbackId},
        ),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    });

    final results = await Future.wait(uploadFutures);
    return results.whereType<String>().toList();
  }

  /// Deletes all media under `feedbacks/{feedbackId}`
  Future<void> deleteFeedbackMedia(String feedbackId) async {
    try {
      final listResult = await _storage.ref('feedbacks/$feedbackId').listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint('FeedbackStorageService: Failed to delete media folder: $e');
    }
  }
}
