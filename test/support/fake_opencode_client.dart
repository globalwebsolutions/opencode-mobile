import 'dart:async';

import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/core/opencode_client.dart';
import 'package:opencode_mobile/core/usage.dart';

/// Deterministic in-process OpenCode client used to drive the real widget
/// tree end-to-end. The real HTTP/SSE wire behavior is covered separately by
/// test/opencode_client_test.dart and test/chat_state_test.dart against a
/// real in-process HTTP server.
class FakeOpenCodeClient extends OpenCodeClient {
  FakeOpenCodeClient() : super(baseUrl: 'http://fake.local', token: 'fake');

  final StreamController<OcEvent> eventsController =
      StreamController<OcEvent>.broadcast();
  final List<String> prompts = [];
  final List<String> permissionReplies = [];

  List<OcSession> sessions = [];
  List<OcMessage> messages = [];
  List<PermissionRequest> pendingPermissions = [];
  List<OcProject> projects = [];

  /// Console credentials the server reports (empty = no quota to show).
  List<Map<String, dynamic>> credentials = [];

  /// Local spend the server reports.
  UsageSummary usageSummary = const UsageSummary();

  @override
  Future<List<Map<String, dynamic>>> listCredentials() async => credentials;

  @override
  Future<UsageSummary> getUsageSummary() async => usageSummary;

  @override
  Future<ServerInfo> getInfo() async =>
      ServerInfo(version: '2.0.26', urls: [baseUrl]);

  @override
  Future<List<OcSession>> listSessions({int limit = 100}) async => sessions;

  @override
  Future<List<OcMessage>> getMessages(String sessionID, {int limit = 200}) async =>
      List.of(messages);

  @override
  Future<void> prompt(String sessionID, String text,
      {List<Map<String, dynamic>> files = const []}) async {
    prompts.add(text);
    // A real server persists the user message and, after execution ends,
    // the assistant reply; the reconciled history reflects both.
    messages = [
      ...messages,
      OcMessage(id: 'msg_u_$text', type: 'user', text: text),
      OcMessage(
        id: 'msg_live1',
        type: 'assistant',
        agent: 'build',
        content: const [OcPart(type: 'text', text: 'الرد وصل كامل')],
      ),
    ];
  }

  @override
  Future<void> interrupt(String sessionID) async {}

  @override
  Future<List<PermissionRequest>> listSessionPermissions(
      String sessionID) async {
    await Future<void>.delayed(Duration.zero);
    return List.of(pendingPermissions);
  }

  @override
  Future<void> replyPermission(
      String sessionID, String requestID, String decision) async {
    permissionReplies.add(decision);
    pendingPermissions =
        pendingPermissions.where((p) => p.id != requestID).toList();
  }

  @override
  Future<List<OcProject>> listProjects() async => projects;

  @override
  Stream<OcEvent> events(
      {void Function(SseStatus status)? onStatus,
      Duration maxBackoff = const Duration(seconds: 30)}) {
    onStatus?.call(SseStatus.connected);
    return eventsController.stream;
  }
}
