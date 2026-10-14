/// Persists paired servers (URL + auth token), with an active selection.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// A paired OpenCode server connection.
class StoredConnection {
  final String id;
  final String baseUrl;
  final String token;
  final String? name;

  const StoredConnection({
    required this.id,
    required this.baseUrl,
    required this.token,
    this.name,
  });

  /// Human label: the custom name, or host:port from the URL.
  String get label {
    if (name != null && name!.trim().isNotEmpty) return name!.trim();
    try {
      final uri = Uri.parse(baseUrl);
      final port = uri.hasPort && uri.port != 80 && uri.port != 443
          ? ':${uri.port}'
          : '';
      return '${uri.host}$port';
    } catch (_) {
      return baseUrl;
    }
  }

  StoredConnection copyWith({String? name}) => StoredConnection(
        id: id,
        baseUrl: baseUrl,
        token: token,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'baseUrl': baseUrl,
        'token': token,
        if (name != null) 'name': name,
      };

  factory StoredConnection.fromJson(Map<String, dynamic> json) =>
      StoredConnection(
        id: json['id'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        token: json['token'] as String? ?? '',
        name: json['name'] as String?,
      );
}

/// The persisted server list plus the active server id.
class StoredServers {
  final List<StoredConnection> connections;
  final String? activeId;

  const StoredServers({this.connections = const [], this.activeId});

  StoredConnection? get active {
    for (final c in connections) {
      if (c.id == activeId) return c;
    }
    return connections.isEmpty ? null : connections.first;
  }
}

/// Saves and loads paired servers. Uses the platform secure storage
/// (Keychain / Keystore) and falls back to an app-private file if secure
/// storage is unavailable (e.g. missing desktop entitlements during dev).
class ConnectionStore {
  static const _key = 'opencode_servers_v2';
  // Legacy single-connection key from the first release.
  static const _legacyKey = 'opencode_connection_v1';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  /// Loads all servers, migrating the legacy single-connection record if
  /// present.
  Future<StoredServers> readAll() async {
    final raw = await _readRaw(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final list = decoded['connections'];
          return StoredServers(
            connections: [
              if (list is List)
                for (final c in list)
                  if (c is Map)
                    StoredConnection.fromJson(Map<String, dynamic>.from(c)),
            ],
            activeId: decoded['activeId'] as String?,
          );
        }
      } catch (_) {}
    }

    // Migrate the legacy record once.
    final legacy = await _readRaw(_legacyKey);
    if (legacy != null) {
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is Map &&
            decoded['baseUrl'] is String &&
            decoded['token'] is String) {
          final migrated = StoredConnection(
            id: _newId(),
            baseUrl: decoded['baseUrl'] as String,
            token: decoded['token'] as String,
          );
          final servers = StoredServers(
            connections: [migrated],
            activeId: migrated.id,
          );
          await writeAll(servers);
          return servers;
        }
      } catch (_) {}
    }
    return const StoredServers();
  }

  Future<void> writeAll(StoredServers servers) => _writeRaw(
        _key,
        jsonEncode({
          'connections': [for (final c in servers.connections) c.toJson()],
          if (servers.activeId != null) 'activeId': servers.activeId,
        }),
      );

  /// Clears everything (used by "remove all").
  Future<void> clearAll() async {
    await _writeRaw(_key, null);
    await _writeRaw(_legacyKey, null);
  }

  // ---------------------------------------------------------------------------
  // Demo mode
  // ---------------------------------------------------------------------------

  // Kept out of the config map so SettingsState's language/theme writes can
  // never clobber it.
  static const _demoKey = 'opencode_demo_mode_v1';

  /// True when the app was left in the built-in demo (no server needed).
  Future<bool> readDemoMode() async => (await _readRaw(_demoKey)) == 'true';

  Future<void> writeDemoMode(bool enabled) =>
      _writeRaw(_demoKey, enabled ? 'true' : null);

  // ---------------------------------------------------------------------------
  // App config (language & theme preferences)
  // ---------------------------------------------------------------------------

  static const _configKey = 'opencode_config_v1';

  /// Reads the app config map; returns an empty map when absent/corrupt.
  Future<Map<String, dynamic>> readConfig() async {
    final raw = await _readRaw(_configKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> writeConfig(Map<String, dynamic> config) =>
      _writeRaw(_configKey, jsonEncode(config));

  static String _newId() =>
      'srv_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  Future<String?> _readRaw(String key) async {
    try {
      final value = await _secure.read(key: key);
      if (value != null) return value;
    } catch (e) {
      debugPrint('secure storage read failed: $e');
    }
    try {
      final file = await _fallbackFile(key);
      if (await file.exists()) return await file.readAsString();
    } catch (_) {}
    return null;
  }

  Future<void> _writeRaw(String key, String? value) async {
    var saved = false;
    try {
      if (value == null) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
      saved = true;
    } catch (e) {
      debugPrint('secure storage write failed: $e');
    }
    // Best-effort fallback so the pairing survives restarts even without
    // secure storage support on the current platform.
    try {
      final file = await _fallbackFile(key);
      if (value == null) {
        if (await file.exists()) await file.delete();
      } else if (!saved) {
        await file.writeAsString(value, flush: true);
      }
    } catch (_) {}
  }

  Future<File> _fallbackFile(String key) async {
    final dir = await getApplicationSupportDirectory();
    final safe = key.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    return File('${dir.path}/$safe.json');
  }
}

/// Generates a new server id (used by the pairing flow).
String newServerId() => ConnectionStore._newId();
