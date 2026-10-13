/// Sessions list state with live updates.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/opencode_client.dart';
import 'app_state.dart';

/// Owns the sessions list, refreshed from the API and kept in sync from the
/// live event feed.
class SessionsState extends ChangeNotifier {
  final AppState app;

  SessionsState({required this.app}) {
    _eventsSub = app.events.listen(_onEvent);
    app.addListener(_onAppChanged);
    // The "connected" SSE transition may already have happened before this
    // state was created (the home screen builds after pairing): catch up.
    if (app.phase == AppPhase.ready) {
      refresh(silent: true);
    }
  }

  List<OcSession> sessions = [];
  final Map<String, bool> busySessions = {};
  bool loading = false;
  String? error;

  StreamSubscription<OcEvent>? _eventsSub;
  Timer? _refreshDebounce;

  OpenCodeClient? get _client => app.client;

  Future<void> refresh({bool silent = false}) async {
    final client = _client;
    if (client == null) return;
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      sessions = await client.listSessions();
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<OcSession> createSession({required String directory, String? title}) async {
    final client = _client;
    if (client == null) throw StateError('غير متصل');
    final session = await client.createSession(directory: directory, title: title);
    await refresh(silent: true);
    return session;
  }

  Future<void> renameSession(String sessionID, String title) async {
    final client = _client;
    if (client == null) return;
    await client.renameSession(sessionID, title);
    await refresh(silent: true);
  }

  Future<void> deleteSession(String sessionID) async {
    final client = _client;
    if (client == null) return;
    await client.deleteSession(sessionID);
    sessions = sessions.where((s) => s.id != sessionID).toList();
    notifyListeners();
  }

  void _onEvent(OcEvent e) {
    final sid = e.data['sessionID'] as String?;
    switch (e.type) {
      case 'session.created':
      case 'session.deleted':
      case 'session.renamed':
      case 'session.moved':
      case 'session.forked':
        _scheduleRefresh();
        break;
      case 'session.execution.started':
        if (sid != null) busySessions[sid] = true;
        notifyListeners();
        break;
      case 'session.execution.succeeded':
      case 'session.execution.failed':
      case 'session.execution.interrupted':
        if (sid != null) busySessions[sid] = false;
        _scheduleRefresh();
        break;
      case 'session.usage.updated':
        if (sid != null) {
          final idx = sessions.indexWhere((s) => s.id == sid);
          if (idx >= 0) {
            final old = sessions[idx];
            sessions[idx] = old.copyWith(
              cost: (e.data['cost'] as num?)?.toDouble(),
              tokens: TokenUsage.fromJson(e.data['tokens'] is Map
                  ? Map<String, dynamic>.from(e.data['tokens'] as Map)
                  : null),
              updatedMs: DateTime.now().millisecondsSinceEpoch,
            );
            notifyListeners();
          }
        }
        break;
      default:
        break;
    }
  }

  void _onAppChanged() {
    // Refresh when the connection (re)connects after a drop, and when a new
    // pairing becomes active.
    if (app.phase == AppPhase.ready && app.sseStatus == SseStatus.connected) {
      if (!_wasConnected) {
        _wasConnected = true;
        refresh(silent: true);
      }
    } else {
      _wasConnected = false;
    }
  }

  bool _wasConnected = false;

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _refreshDebounce?.cancel();
    app.removeListener(_onAppChanged);
    super.dispose();
  }
}
