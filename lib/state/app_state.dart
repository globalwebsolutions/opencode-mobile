/// App-level state: paired servers, connection lifecycle, and the SSE hub.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/connection_store.dart';
import '../core/notification_center.dart';
import '../core/opencode_client.dart';
import '../core/watcher_config.dart';

enum AppPhase { boot, unpaired, connecting, ready, pairFailed }

/// Owns the paired servers, the active connection to the OpenCode server,
/// and fans out live events.
class AppState extends ChangeNotifier {
  final ConnectionStore _store = ConnectionStore();

  /// All paired servers.
  List<StoredConnection> connections = [];
  String? activeId;

  OpenCodeClient? _client;
  ServerInfo? serverInfo;
  AppPhase phase = AppPhase.boot;
  String? error;
  SseStatus sseStatus = SseStatus.disconnected;
  bool get connected => sseStatus == SseStatus.connected;

  final _eventsController = StreamController<OcEvent>.broadcast();

  /// Live event feed; emits while the app is paired and connected.
  Stream<OcEvent> get events => _eventsController.stream;

  OpenCodeClient? get client => _client;
  bool get isPaired => _client != null;
  StoredConnection? get activeConnection {
    for (final c in connections) {
      if (c.id == activeId) return c;
    }
    return connections.isEmpty ? null : connections.first;
  }

  /// Loads the stored servers, connects to the active one, and starts the
  /// event stream.
  Future<void> bootstrap() async {
    try {
      final stored = await _store.readAll();
      connections = stored.connections;
      final active = stored.active;
      if (active == null) {
        phase = AppPhase.unpaired;
        notifyListeners();
        return;
      }
      activeId = active.id;
      await _connect(active.baseUrl, active.token);
    } catch (e) {
      error = friendlyErrorText(e);
      phase = AppPhase.pairFailed;
      notifyListeners();
    }
  }

  /// Pairs using a one-time link printed by `opencode pair`, saves the
  /// resulting token, and connects.
  Future<void> pairWithLink(String link) async {
    error = null;
    notifyListeners();
    final baseUrl = OpenCodeClient.baseUrlFromLink(link);
    final token = await OpenCodeClient.redeemPairingLink(link);
    await _addOrReplace(baseUrl, token);
    await _connect(baseUrl, token);
  }

  /// Switches the active server. On failure lands on the welcome screen
  /// with the error so the user can pick another server.
  Future<void> switchServer(String id) async {
    StoredConnection? target;
    for (final c in connections) {
      if (c.id == id) target = c;
    }
    if (target == null || id == activeId) return;
    error = null;
    activeId = id;
    await _persist();
    await _stopEvents();
    _client?.close();
    _client = null;
    serverInfo = null;
    notifyListeners();
    try {
      await _connect(target.baseUrl, target.token);
    } catch (e) {
      error = friendlyErrorText(e);
      phase = AppPhase.pairFailed;
      notifyListeners();
    }
  }

  /// Renames a saved server.
  Future<void> renameServer(String id, String name) async {
    final idx = connections.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    connections[idx] = connections[idx].copyWith(name: name);
    await _persist();
    notifyListeners();
  }

  /// Enables the background watcher so the user gets notifications for
  /// permission requests and execution outcomes on the active server.
  /// Returns true on success.
  Future<bool> enableNotifications() async {
    final c = activeConnection;
    if (c == null) return false;
    try {
      await WatcherConfig.write(
        WatcherConfig(
          baseUrl: c.baseUrl,
          token: c.token,
          serverName: c.label,
        ),
      );
      await startForegroundService('${c.label} — متواصل');
      error = null;
      notifyListeners();
      return true;
    } catch (e) {
      // Roll back the config so the watcher doesn't start on next launch.
      await WatcherConfig.clear();
      error = friendlyErrorText(e);
      notifyListeners();
      return false;
    }
  }

  /// Disables the background watcher.
  Future<void> disableNotifications() async {
    await WatcherConfig.clear();
    await stopForegroundService();
    notifyListeners();
  }

  /// Whether the foreground service is currently running.
  Future<bool> get isNotificationsEnabled => isForegroundServiceRunning;

  /// Removes a saved server. If it was active, connects to the next one or
  /// falls back to the welcome screen.
  Future<void> removeServer(String id) async {
    final wasActive = id == activeId;
    connections = [
      for (final c in connections)
        if (c.id != id) c,
    ];
    if (connections.isEmpty) {
      await _stopEvents();
      _client?.close();
      _client = null;
      serverInfo = null;
      activeId = null;
      phase = AppPhase.unpaired;
      sseStatus = SseStatus.disconnected;
      error = null;
      await _persist();
      notifyListeners();
      return;
    }
    if (wasActive) {
      final next = connections.first;
      activeId = next.id;
      await _persist();
      await _stopEvents();
      _client?.close();
      _client = null;
      serverInfo = null;
      notifyListeners();
      try {
        await _connect(next.baseUrl, next.token);
      } catch (e) {
        error = friendlyErrorText(e);
        phase = AppPhase.pairFailed;
        notifyListeners();
      }
    } else {
      await _persist();
      notifyListeners();
    }
  }

  /// Test seam: attaches an already-configured client without pairing,
  /// starts the event stream, and notifies like a real successful connect.
  @visibleForTesting
  void attachForTest(OpenCodeClient client, {ServerInfo? info}) {
    _client = client;
    serverInfo = info;
    phase = AppPhase.ready;
    _startEvents();
    notifyListeners();
  }

  /// Test seam: injects an event as if it arrived over the SSE connection.
  @visibleForTesting
  void emitEventForTest(OcEvent event) => _eventsController.add(event);

  // ---------------------------------------------------------------------------

  Future<void> _addOrReplace(String baseUrl, String token) async {
    final idx = connections.indexWhere((c) => c.baseUrl == baseUrl);
    if (idx >= 0) {
      // Same server paired again: refresh the token.
      final old = connections[idx];
      connections[idx] = StoredConnection(
        id: old.id,
        baseUrl: baseUrl,
        token: token,
        name: old.name,
      );
      activeId = old.id;
    } else {
      final fresh = StoredConnection(id: newServerId(), baseUrl: baseUrl, token: token);
      connections = [...connections, fresh];
      activeId = fresh.id;
    }
    await _persist();
  }

  Future<void> _persist() => _store.writeAll(
        StoredServers(connections: connections, activeId: activeId),
      );

  Future<void> _connect(String baseUrl, String token) async {
    phase = AppPhase.connecting;
    notifyListeners();
    final client = OpenCodeClient(baseUrl: baseUrl, token: token);
    final info = await client.getInfo();
    _client = client;
    serverInfo = info;
    phase = AppPhase.ready;
    notifyListeners();
    _startEvents();
  }

  void _startEvents() {
    _stopEvents();
    final client = _client;
    if (client == null) return;
    _eventSub = client.events(onStatus: _onSseStatus).listen(
          _eventsController.add,
          onError: (Object e) {
            debugPrint('event stream error: $e');
          },
        );
  }

  StreamSubscription<OcEvent>? _eventSub;

  Future<void> _stopEvents() async {
    await _eventSub?.cancel();
    _eventSub = null;
  }

  void _onSseStatus(SseStatus status) {
    sseStatus = status;
    notifyListeners();
  }

  String friendlyErrorText(Object e) {
    if (e is OpenCodeApiException) {
      if (e.unauthorized) {
        return 'الـ token مش صالح — اعمل pairing جديد من على الكمبيوتر';
      }
      return 'خطأ من السيرفر (${e.statusCode}): ${e.message}';
    }
    if (e is FormatException) return e.message;
    if (e is TimeoutException) {
      return 'السيرفر مش بيرد — تأكد إن الجهازين على نفس الشبكة و OpenCode شغال';
    }
    if (e is SocketException) {
      return 'تعذر الوصول للسيرفر — تأكد إن الجهازين على نفس الشبكة و OpenCode شغال '
          'وإن hostname مضبوط (opencode service set hostname 0.0.0.0)';
    }
    return 'تعذر الاتصال: $e';
  }

  @override
  void dispose() {
    _stopEvents();
    _eventsController.close();
    super.dispose();
  }
}
