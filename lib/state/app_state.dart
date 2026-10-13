/// App-level state: pairing, connection lifecycle, and the SSE event hub.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/connection_store.dart';
import '../core/opencode_client.dart';

enum AppPhase { boot, unpaired, connecting, ready, pairFailed }

/// Owns the connection to the OpenCode server and fans out live events.
class AppState extends ChangeNotifier {
  final ConnectionStore _store = ConnectionStore();

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

  /// Loads the stored connection, verifies it, and starts the event stream.
  Future<void> bootstrap() async {
    try {
      final stored = await _store.read();
      if (stored == null) {
        phase = AppPhase.unpaired;
        notifyListeners();
        return;
      }
      await _connect(stored.baseUrl, stored.token);
    } catch (e) {
      error = _friendlyError(e);
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
    await _store.write(StoredConnection(baseUrl: baseUrl, token: token));
    await _connect(baseUrl, token);
  }

  /// Forgets the paired server.
  Future<void> unpair() async {
    await _stopEvents();
    _client?.close();
    _client = null;
    serverInfo = null;
    phase = AppPhase.unpaired;
    sseStatus = SseStatus.disconnected;
    error = null;
    await _store.clear();
    notifyListeners();
  }

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
    final wasDisconnected = sseStatus == SseStatus.disconnected;
    sseStatus = status;
    notifyListeners();
    // The event stream is live-only: after a reconnect, listeners refresh
    // their state to fill the gap. AppState listeners can watch
    // [sseStatus] transitions for that.
    if (status == SseStatus.connected && wasDisconnected) {
      // Nothing to do here directly; states observe the transition.
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

  String _friendlyError(Object e) => friendlyErrorText(e);

  @override
  void dispose() {
    _stopEvents();
    _eventsController.close();
    super.dispose();
  }
}
