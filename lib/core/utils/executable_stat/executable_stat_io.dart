import 'dart:io';

/// Native (IO) implementation for retrieving executable modification timestamp.
int? getExecutableModifiedTimestamp() {
  try {
    final executableFile = File(Platform.resolvedExecutable);
    if (executableFile.existsSync()) {
      final modified = executableFile
          .statSync()
          .modified
          .millisecondsSinceEpoch;
      if (modified > 0) return modified;
    }
  } catch (_) {}
  return null;
}
