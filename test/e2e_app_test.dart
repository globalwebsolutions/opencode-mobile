import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app.dart';
import 'package:opencode_mobile/core/connection_store.dart';
import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/state/app_state.dart';
import 'package:opencode_mobile/state/settings_state.dart';

import 'support/fake_opencode_client.dart';

void main() {
  testWidgets('end-to-end: sessions list, chat, streaming, permissions',
      (tester) async {
    final fake = FakeOpenCodeClient()
      ..projects = [const OcProject(id: 'p1', canonical: '/tmp/project', vcs: 'git')]
      ..sessions = [
        const OcSession(
          id: 'ses_e2e1',
          title: 'تجربة E2E',
          agent: 'build',
          directory: '/tmp/project',
        ),
      ]
      ..messages = [
        const OcMessage(id: 'msg_u1', type: 'user', text: 'السلام عليكم'),
        const OcMessage(
          id: 'msg_a1',
          type: 'assistant',
          agent: 'build',
          content: [OcPart(type: 'text', text: 'وعليكم السلام')],
        ),
      ];

    final appState = AppState();
    // Force Arabic UI for deterministic assertions (test platform defaults
    // to English otherwise).
    final settings = SettingsState(ConnectionStore())
      ..setLang(AppLang.arabic);

    // With an injected state, bootstrap never runs: the app starts on the
    // splash (phase boot) until pairing is simulated below.
    await tester.pumpWidget(OpenCodeMobileApp(
        appState: appState, settings: settings));
    await tester.pump(const Duration(milliseconds: 10));

    // Simulate a completed pairing (the pairing wire flow itself is covered
    // by test/opencode_client_test.dart against a real HTTP server).
    appState.attachForTest(fake);

    // The SSE status transition triggers the sessions refresh.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));

    // Home is the chat-first landing screen.
    expect(find.textContaining('إزاي أقدر أساعدك'), findsOneWidget);

    // Projects & history live behind the folder button in the top bar.
    await tester.tap(find.byIcon(Icons.folder_open_rounded));
    await tester.pumpAndSettle();
    expect(find.text('تجربة E2E'), findsOneWidget);

    // Open the chat and render the history.
    await tester.tap(find.text('تجربة E2E'));
    await tester.pumpAndSettle();
    expect(find.textContaining('السلام عليكم'), findsWidgets);
    expect(find.textContaining('وعليكم السلام'), findsWidgets);

    // Send a message: optimistic user bubble appears.
    final chatField = find.byType(TextField).first;
    await tester.enterText(chatField, 'ابعت الرد');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(fake.prompts, ['ابعت الرد']);
    expect(find.text('ابعت الرد'), findsOneWidget);

    // The server streams the assistant reply live.
    void push(String type, Map<String, dynamic> data) =>
        fake.eventsController.add(OcEvent(
          id: 'evt_${DateTime.now().microsecondsSinceEpoch}',
          type: type,
          data: {'sessionID': 'ses_e2e1', ...data},
        ));

    push('session.execution.started', {});
    push('session.step.started', {
      'assistantMessageID': 'msg_live1',
      'agent': 'build',
    });
    push('session.text.started', {'assistantMessageID': 'msg_live1', 'ordinal': 0});
    push('session.text.delta', {
      'assistantMessageID': 'msg_live1',
      'ordinal': 0,
      'delta': 'الرد ',
    });
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    push('session.text.delta', {
      'assistantMessageID': 'msg_live1',
      'ordinal': 0,
      'delta': 'وصل',
    });
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 30));
    // The streamed text renders live, character group by character group.
    expect(find.textContaining('الرد وصل'), findsWidgets);

    // A permission request arrives: the inline card offers decisions.
    fake.pendingPermissions = [
      const PermissionRequest(
        id: 'perm_1',
        sessionID: 'ses_e2e1',
        action: 'bash',
        resources: ['/tmp/x.sh'],
        message: 'عايز يشغل أمر',
      ),
    ];
    push('session.tool.called', {
      'assistantMessageID': 'msg_live1',
      'id': 'tool_1',
      'name': 'shell',
      'input': {'command': 'echo hi'},
    });
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.textContaining('عايز يشغل أمر'), findsOneWidget);

    await tester.tap(find.text('سماح مرة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    expect(fake.permissionReplies, ['once']);

    // Finish the turn: execution ends and the message stops streaming.
    push('session.text.ended', {
      'assistantMessageID': 'msg_live1',
      'ordinal': 0,
      'text': 'الرد وصل كامل',
    });
    push('session.step.ended', {
      'assistantMessageID': 'msg_live1',
      'finish': 'stop',
    });
    push('session.execution.succeeded', {});
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.textContaining('الرد وصل كامل'), findsWidgets);

    fake.eventsController.close();
  });
}
