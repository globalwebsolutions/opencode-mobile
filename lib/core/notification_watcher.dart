/// Background watcher task for OpenCode notifications.
///
/// Runs in a dedicated isolate started by [FlutterForegroundTask]. It keeps
/// a live SSE connection to the paired server, polls pending permission
/// requests, and forwards interesting events to the main isolate via
/// [FlutterForegroundTask.sendDataToMain], which then fires local alerts.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/core/opencode_client.dart';
import 'package:opencode_mobile/core/watcher_config.dart';

/// Entry point for the background isolate — must be top-level.
@pragma('vm:entry-point')
void startNotificationService() {
  FlutterForegroundTask.setTaskHandler(_WatcherTask());
}

class _WatcherTask extends TaskHandler {
  OpenCodeClient? _client;
  StreamSubscription<OcEvent>? _sub;
  final Set<String> _notifiedPermissionIds = {};
  final Map<String, String> _sessionTitles = {};
  Timer? _titlesRefresh;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final config = await WatcherConfig.read();
    if (config == null || config.baseUrl.isEmpty) {
      await FlutterForegroundTask.stopService();
      return;
    }
    L.lang =
        config.lang == 'english' ? AppLang.english : AppLang.arabic;
    _client = OpenCodeClient(baseUrl: config.baseUrl, token: config.token);
    _sub = _client!
        .events(onStatus: (_) {})
        .listen(_onEvent, onError: (Object e) => debugPrint('watcher SSE: $e'));
    _titlesRefresh = Timer.periodic(
        const Duration(minutes: 2), (_) => _refreshTitles());
    await _refreshTitles();
    await _pollPermissions();
  }

  /// Fired every 5s (see [ForegroundTaskOptions.eventAction] at init).
  @override
  void onRepeatEvent(DateTime timestamp) {
    _pollPermissions();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _titlesRefresh?.cancel();
    await _sub?.cancel();
    _client?.close();
  }

  Future<void> _onEvent(OcEvent e) async {
    final sid = e.data['sessionID'] as String?;
    if (sid == null) return;
    switch (e.type) {
      case 'session.execution.succeeded':
        await _sendOutcome(sid, L.tr('تم التنفيذ', 'Finished'));
        break;
      case 'session.execution.failed':
        await _sendOutcome(sid, L.tr('فشل التنفيذ', 'Run failed'));
        break;
      case 'session.execution.interrupted':
        await _sendOutcome(sid, L.tr('توقف التنفيذ', 'Run stopped'));
        break;
    }
  }

  Future<void> _sendOutcome(String sessionId, String outcome) async {
    final title = await _titleFor(sessionId);
    FlutterForegroundTask.sendDataToMain(<String, Object?>{
      'type': 'done',
      'sessionID': sessionId,
      'sessionTitle': title,
      'outcome': outcome,
    });
  }

  Future<void> _pollPermissions() async {
    final client = _client;
    if (client == null) return;
    try {
      final list = await client.listPermissionRequests();
      final liveIds = <String>{};
      for (final p in list) {
        liveIds.add(p.id);
        if (!_notifiedPermissionIds.add(p.id)) continue;
        final title = await _titleFor(p.sessionID);
        FlutterForegroundTask.sendDataToMain(<String, Object?>{
          'type': 'permission',
          'sessionID': p.sessionID,
          'sessionTitle': title,
          'action': p.actionLabel,
          'message': p.message ?? '',
        });
      }
      _notifiedPermissionIds.removeWhere((id) => !liveIds.contains(id));
    } catch (e) {
      debugPrint('watcher poll error: $e');
    }
  }

  Future<String> _titleFor(String sessionId) async {
    final cached = _sessionTitles[sessionId];
    if (cached != null) return cached;
    // Fall back to a friendly placeholder; titles are refreshed lazily.
    return L.tr('جلسة', 'Session');
  }

  Future<void> _refreshTitles() async {
    final client = _client;
    if (client == null) return;
    try {
      final sessions = await client.listSessions(limit: 100);
      for (final s in sessions) {
        final t = s.title?.trim();
        if (t != null && t.isNotEmpty) {
          _sessionTitles[s.id] = t;
        }
      }
    } catch (e) {
      debugPrint('watcher refresh titles: $e');
    }
  }
}
