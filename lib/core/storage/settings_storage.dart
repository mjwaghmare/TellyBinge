import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SettingsStorage {
  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<Map<String, dynamic>> readSettings() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final contents = await file.readAsString();
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading settings: $e');
    }
    return {};
  }

  Future<void> writeSetting(String key, dynamic value) async {
    try {
      final file = await _file;
      final current = await readSettings();
      current[key] = value;
      await file.writeAsString(jsonEncode(current));
    } catch (e) {
      debugPrint('Error writing setting $key: $e');
    }
  }
}
