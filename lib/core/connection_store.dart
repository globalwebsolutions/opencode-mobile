/// Persists the paired connection (server URL + token).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// A paired OpenCode server connection.
class StoredConnection {
  final String baseUrl;
  final String token;

  const StoredConnection({required this.baseUrl, required this.token});
}

/// Saves and loads the active connection. Uses the platform secure storage
/// (Keychain / Keystore) and falls back to an app-private file if secure
/// storage is unavailable (e.g. missing desktop entitlements during dev).
class ConnectionStore {
  static const _key = 'opencode_connection_v1';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<StoredConnection?> read() async {
    final raw = await _readRaw();
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map &&
          decoded['baseUrl'] is String &&
          decoded['token'] is String) {
        return StoredConnection(
          baseUrl: decoded['baseUrl'] as String,
          token: decoded['token'] as String,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> write(StoredConnection connection) async =>
      _writeRaw(jsonEncode({
        'baseUrl': connection.baseUrl,
        'token': connection.token,
      }));

  Future<void> clear() async => _writeRaw(null);

  Future<String?> _readRaw() async {
    try {
      final value = await _secure.read(key: _key);
      if (value != null) return value;
    } catch (e) {
      debugPrint('secure storage read failed: $e');
    }
    try {
      final file = await _fallbackFile();
      if (await file.exists()) return await file.readAsString();
    } catch (_) {}
    return null;
  }

  Future<void> _writeRaw(String? value) async {
    var saved = false;
    try {
      if (value == null) {
        await _secure.delete(key: _key);
      } else {
        await _secure.write(key: _key, value: value);
      }
      saved = true;
    } catch (e) {
      debugPrint('secure storage write failed: $e');
    }
    // Best-effort fallback so the session survives restarts even without
    // secure storage support on the current platform.
    try {
      final file = await _fallbackFile();
      if (value == null) {
        if (await file.exists()) await file.delete();
      } else if (!saved) {
        await file.writeAsString(value, flush: true);
      }
    } catch (_) {}
  }

  Future<File> _fallbackFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/opencode_connection.json');
  }
}
