/// Chat state: message history, live streaming, and permission requests.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/opencode_client.dart';
import 'app_state.dart';

/// Owns one session's messages, live event application, and permission
/// handling for the chat screen.
class ChatState extends ChangeNotifier {
  final AppState app;
  final String sessionID;

  ChatState({required this.app, required this.sessionID}) {
    _eventsSub = app.events.listen(_onEvent);
    app.addListener(_onAppChanged);
  }

  List<OcMessage> messages = [];
  bool loading = false;
  bool busy = false; // execution in progress
  bool sending = false;
  String? error;
  List<PermissionRequest> pendingPermissions = [];
  double? sessionCost;

  StreamSubscription<OcEvent>? _eventsSub;
  Timer? _permissionTimer;
  bool _wasConnected = false;

  OpenCodeClient? get _client => app.client;

  /// Loads the message history and, when [thenSend] is provided (a chat
  /// started from the home composer), sends it as the first message.
  Future<void> bootstrap({String? thenSend}) async {
    await load();
    if (thenSend != null && thenSend.trim().isNotEmpty) {
      await send(thenSend);
    }
  }

  /// Loads the message history and assigns per-type ordinals to text parts so
  /// later live deltas line up with the fetched content.
  Future<void> load() async {
    final client = _client;
    if (client == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final fetched = await client.getMessages(sessionID);
      messages = _assignOrdinals(fetched);
      sessionCost = _sumCost(messages);
      error = null;
    } catch (e) {
      error = '$e';
    } finally {
      loading = false;
      notifyListeners();
    }
    await pollPermissions();
  }

  /// Sends a user message; the assistant reply arrives via live events.
  Future<void> send(String text) async {
    final client = _client;
    final trimmed = text.trim();
    if (client == null || trimmed.isEmpty || busy) return;
    sending = true;
    busy = true;
    notifyListeners();
    messages = [
      ...messages,
      OcMessage(
        id: 'local_user_${DateTime.now().millisecondsSinceEpoch}',
        type: 'user',
        text: trimmed,
        createdMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    notifyListeners();
    try {
      await client.prompt(sessionID, trimmed);
    } catch (e) {
      busy = false;
      error = '$e';
      notifyListeners();
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> interrupt() async {
    final client = _client;
    if (client == null) return;
    try {
      await client.interrupt(sessionID);
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  // -- models -----------------------------------------------------------------

  List<ModelOption> models = [];
  bool loadingModels = false;

  /// Loads the model catalog once (cached for the screen's lifetime).
  Future<void> loadModels() async {
    final client = _client;
    if (client == null || loadingModels || models.isNotEmpty) return;
    loadingModels = true;
    notifyListeners();
    try {
      models = await client.listModels();
    } catch (e) {
      error = '$e';
    } finally {
      loadingModels = false;
      notifyListeners();
    }
  }

  /// Switches this session's model.
  Future<void> switchModel(ModelOption model, {String? variant}) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.setSessionModel(
        sessionID,
        ModelRef(
          id: model.id,
          providerID: model.providerID,
          variant: variant,
        ),
      );
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  /// Clears the transient error banner.
  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> replyPermission(PermissionRequest request, String decision) async {
    final client = _client;
    if (client == null) return;
    pendingPermissions =
        pendingPermissions.where((p) => p.id != request.id).toList();
    notifyListeners();
    try {
      await client.replyPermission(sessionID, request.id, decision);
    } catch (e) {
      error = '$e';
      notifyListeners();
      await pollPermissions();
    }
  }

  /// Fetches pending permission requests for this session.
  Future<void> pollPermissions() async {
    final client = _client;
    if (client == null) return;
    try {
      final pending = await client.listSessionPermissions(sessionID);
      pendingPermissions = pending;
      if (pending.isNotEmpty) {
        busy = true;
        _startPermissionPolling();
      }
      notifyListeners();
    } catch (_) {
      // Permissions polling is best-effort.
    }
  }

  // ---------------------------------------------------------------------------
  // Live event application
  // ---------------------------------------------------------------------------

  void _onEvent(OcEvent e) {
    if (e.data['sessionID'] != sessionID) return;
    switch (e.type) {
      case 'session.step.started':
        busy = true;
        _ensureMessage(
          e.data['assistantMessageID'] as String? ?? '',
          agent: e.data['agent'] as String?,
          model: e.data['model'] is Map
              ? ModelRef.fromJson(
                  Map<String, dynamic>.from(e.data['model'] as Map))
              : null,
        );
        _startPermissionPolling();
        break;
      case 'session.reasoning.started':
        _upsertTextishPart(e, 'reasoning');
        break;
      case 'session.reasoning.delta':
        _appendTextishPart(e, 'reasoning');
        break;
      case 'session.reasoning.ended':
        _setTextishPart(e, 'reasoning');
        break;
      case 'session.text.started':
        _upsertTextishPart(e, 'text');
        break;
      case 'session.text.delta':
        _appendTextishPart(e, 'text');
        break;
      case 'session.text.ended':
        _setTextishPart(e, 'text');
        break;
      case 'session.tool.input.started':
        _upsertToolPart(e, status: 'running');
        break;
      case 'session.tool.input.delta':
        _appendToolInput(e);
        break;
      case 'session.tool.input.ended':
        _setToolInput(e, raw: true);
        break;
      case 'session.tool.called':
        _setToolInput(e, raw: false);
        pollPermissions();
        break;
      case 'session.tool.success':
        _setToolResult(e, 'completed');
        break;
      case 'session.tool.failed':
        _setToolResult(e, 'error');
        break;
      case 'session.tool.progress':
        _setToolMetadata(e);
        break;
      case 'session.step.ended':
        _finishMessage(
          e.data['assistantMessageID'] as String? ?? '',
          finish: e.data['finish'] as String?,
          cost: (e.data['cost'] as num?)?.toDouble(),
          tokens: e.data['tokens'] is Map
              ? TokenUsage.fromJson(
                  Map<String, dynamic>.from(e.data['tokens'] as Map))
              : null,
        );
        break;
      case 'session.step.failed':
        _finishMessage(e.data['assistantMessageID'] as String? ?? '',
            finish: 'error');
        break;
      case 'session.execution.started':
        busy = true;
        error = null;
        _startPermissionPolling();
        break;
      case 'session.execution.succeeded':
      case 'session.execution.failed':
      case 'session.execution.interrupted':
        busy = false;
        _stopPermissionPolling();
        if (e.type == 'session.execution.failed') {
          final err = e.data['error'];
          error = err is Map ? '${err['message']}' : 'فشل التنفيذ';
        }
        // Reconcile with the server's view of the finished messages.
        unawaited(load());
        break;
      case 'session.usage.updated':
        sessionCost = (e.data['cost'] as num?)?.toDouble() ?? sessionCost;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  // -- message/part helpers ---------------------------------------------------

  List<OcMessage> _assignOrdinals(List<OcMessage> fetched) {
    return fetched.map((m) {
      if (m.type != 'assistant') return m;
      final counters = <String, int>{};
      final parts = m.content.map((p) {
        if (p.type == 'text' || p.type == 'reasoning') {
          final ordinal = counters[p.type] ?? 0;
          counters[p.type] = ordinal + 1;
          return OcPart(
            type: p.type,
            text: p.text,
            ordinal: ordinal,
            createdMs: p.createdMs,
          );
        }
        return p;
      }).toList();
      return m.copyWith(content: parts);
    }).toList();
  }

  double? _sumCost(List<OcMessage> list) {
    double total = 0;
    var any = false;
    for (final m in list) {
      if (m.cost != null) {
        total += m.cost!;
        any = true;
      }
    }
    return any ? total : null;
  }

  int _messageIndex(String id) => messages.indexWhere((m) => m.id == id);

  void _ensureMessage(String id, {String? agent, ModelRef? model}) {
    if (_messageIndex(id) >= 0) return;
    messages = [
      ...messages,
      OcMessage(
        id: id,
        type: 'assistant',
        agent: agent,
        model: model,
        content: const [],
        createdMs: DateTime.now().millisecondsSinceEpoch,
        streaming: true,
      ),
    ];
  }

  void _updateMessage(String id, OcMessage Function(OcMessage) update) {
    final idx = _messageIndex(id);
    if (idx < 0) return;
    final updated = update(messages[idx]);
    if (identical(updated, messages[idx])) return;
    messages = List.of(messages)..[idx] = updated;
  }

  void _updateParts(String messageID,
      List<OcPart> Function(List<OcPart> parts) update) {
    _updateMessage(messageID, (m) => m.copyWith(content: update(m.content)));
  }

  OcPart? _findTextish(List<OcPart> parts, String type, int ordinal) {
    for (final p in parts) {
      if (p.type == type && (p.ordinal ?? 0) == ordinal) return p;
    }
    return null;
  }

  void _upsertTextishPart(OcEvent e, String type) {
    final msgID = _mid(e);
    _ensureMessage(msgID);
    final ordinal = (e.data['ordinal'] as num?)?.toInt() ?? 0;
    _updateParts(msgID, (parts) {
      if (_findTextish(parts, type, ordinal) != null) return parts;
      return [
        ...parts,
        OcPart(type: type, ordinal: ordinal, text: ''),
      ];
    });
  }

  void _appendTextishPart(OcEvent e, String type) {
    final msgID = _mid(e);
    final ordinal = (e.data['ordinal'] as num?)?.toInt() ?? 0;
    final delta = e.data['delta'] as String? ?? '';
    if (delta.isEmpty) return;
    _ensureMessage(msgID);
    _updateParts(msgID, (parts) {
      final existing = _findTextish(parts, type, ordinal);
      if (existing == null) {
        return [...parts, OcPart(type: type, ordinal: ordinal, text: delta)];
      }
      return [
        for (final p in parts)
          if (p.type == type && (p.ordinal ?? 0) == ordinal)
            p.copyWithText((p.text ?? '') + delta)
          else
            p,
      ];
    });
  }

  void _setTextishPart(OcEvent e, String type) {
    final msgID = _mid(e);
    final ordinal = (e.data['ordinal'] as num?)?.toInt() ?? 0;
    final text = e.data['text'] as String? ?? '';
    _ensureMessage(msgID);
    _updateParts(msgID, (parts) {
      final existing = _findTextish(parts, type, ordinal);
      if (existing == null) {
        return [...parts, OcPart(type: type, ordinal: ordinal, text: text)];
      }
      return [
        for (final p in parts)
          if (p.type == type && (p.ordinal ?? 0) == ordinal)
            p.copyWithText(text)
          else
            p,
      ];
    });
  }

  // -- tool part helpers ------------------------------------------------------

  String _mid(OcEvent e) => e.data['assistantMessageID'] as String? ?? '';

  String _tid(OcEvent e) => e.data['id'] as String? ?? '';

  OcPart? _findTool(List<OcPart> parts, String toolID) {
    for (final p in parts) {
      if (p.type == 'tool' && p.toolId == toolID) return p;
    }
    return null;
  }

  void _upsertToolPart(OcEvent e, {required String status}) {
    final msgID = _mid(e);
    final toolID = _tid(e);
    final name = e.data['name'] as String?;
    _ensureMessage(msgID);
    _updateParts(msgID, (parts) {
      if (_findTool(parts, toolID) != null) return parts;
      return [
        ...parts,
        OcPart(
          type: 'tool',
          toolId: toolID,
          toolName: name,
          toolStatus: status,
          toolInput: '',
        ),
      ];
    });
  }

  void _appendToolInput(OcEvent e) {
    final delta = e.data['delta'] as String? ?? '';
    if (delta.isEmpty) return;
    _updateTool(e, (p) => p.copyWithTool(toolInput: (p.toolInput ?? '') + delta));
  }

  void _setToolInput(OcEvent e, {required bool raw}) {
    final value = raw
        ? e.data['text'] as String?
        : _prettyJson(e.data['input']);
    _updateTool(e, (p) => p.copyWithTool(toolInput: value, toolStatus: 'running'));
  }

  void _setToolResult(OcEvent e, String status) {
    String? output;
    final content = e.data['content'];
    if (content is List) {
      final buf = StringBuffer();
      for (final c in content) {
        if (c is Map && c['text'] is String) {
          buf.write(c['text'] as String);
          buf.write('\n');
        }
      }
      output = buf.toString().trim();
    }
    String? toolError;
    if (status == 'error') {
      final err = e.data['error'];
      toolError = err is Map
          ? '${err['message'] ?? err['type'] ?? 'فشلت الأداة'}'
          : 'فشلت الأداة';
    }
    Map<String, dynamic>? metadata;
    if (e.data['metadata'] is Map) {
      metadata = Map<String, dynamic>.from(e.data['metadata'] as Map);
    }
    _updateTool(
      e,
      (p) => p.copyWithTool(
        toolStatus: status,
        toolOutput: output,
        toolError: toolError,
        toolMetadata: metadata,
      ),
    );
  }

  void _setToolMetadata(OcEvent e) {
    Map<String, dynamic>? metadata;
    if (e.data['metadata'] is Map) {
      metadata = Map<String, dynamic>.from(e.data['metadata'] as Map);
    }
    _updateTool(e, (p) => p.copyWithTool(toolMetadata: metadata));
  }

  void _updateTool(OcEvent e, OcPart Function(OcPart) update) {
    final msgID = _mid(e);
    final toolID = _tid(e);
    _ensureMessage(msgID);
    _updateParts(msgID, (parts) {
      final idx = parts.indexWhere(
          (p) => p.type == 'tool' && p.toolId == toolID);
      if (idx < 0) {
        return [
          ...parts,
          update(OcPart(
            type: 'tool',
            toolId: toolID,
            toolName: e.data['name'] as String?,
            toolStatus: 'running',
            toolInput: '',
          )),
        ];
      }
      return [
        for (var i = 0; i < parts.length; i++)
          i == idx ? update(parts[idx]) : parts[i],
      ];
    });
  }

  void _finishMessage(String id,
      {String? finish, double? cost, TokenUsage? tokens}) {
    _updateMessage(
      id,
      (m) => m.copyWith(
        streaming: false,
        finish: finish ?? m.finish,
        cost: cost ?? m.cost,
        tokens: tokens ?? m.tokens,
      ),
    );
  }

  static String? _prettyJson(Object? o) {
    if (o == null) return null;
    if (o is String) return o;
    try {
      return const JsonEncoder.withIndent('  ').convert(o);
    } catch (_) {
      return o.toString();
    }
  }

  // -- permission polling -------------------------------------------------------

  void _startPermissionPolling() {
    _permissionTimer ??=
        Timer.periodic(const Duration(milliseconds: 2500), (_) {
      pollPermissions();
    });
  }

  void _stopPermissionPolling() {
    _permissionTimer?.cancel();
    _permissionTimer = null;
    // One final poll to catch requests that arrived after the last check.
    pollPermissions();
  }

  void _onAppChanged() {
    if (app.sseStatus == SseStatus.connected && !_wasConnected) {
      _wasConnected = true;
      // Missed events during the disconnect: reload the current state.
      load();
    } else if (app.sseStatus != SseStatus.connected) {
      _wasConnected = false;
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _permissionTimer?.cancel();
    app.removeListener(_onAppChanged);
    super.dispose();
  }
}
