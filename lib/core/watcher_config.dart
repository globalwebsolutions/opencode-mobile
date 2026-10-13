/// Persists the watcher's server config so the background isolate can read
/// it without platform channels. Plain file in the app's private support dir.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class WatcherConfig {
  final String baseUrl;
  final String token;
  final String serverName;

  const WatcherConfig({
    required this.baseUrl,
    required this.token,
    this.serverName = '',
  });

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'token': token,
        'serverName': serverName,
      };

  factory WatcherConfig.fromJson(Map<String, dynamic> json) => WatcherConfig(
        baseUrl: json['baseUrl'] as String? ?? '',
        token: json['token'] as String? ?? '',
        serverName: json['serverName'] as String? ?? '',
      );

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/opencode_watcher.json');
  }

  /// Reads the active config. Returns null when notifications are disabled.
  static Future<WatcherConfig?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WatcherConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('WatcherConfig.read failed: $e');
    }
    return null;
  }

  static Future<void> write(WatcherConfig config) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(config.toJson()), flush: true);
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
