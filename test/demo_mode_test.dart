import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app.dart';
import 'package:opencode_mobile/core/connection_store.dart';
import 'package:opencode_mobile/core/demo_client.dart';
import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/state/app_state.dart';
import 'package:opencode_mobile/state/settings_state.dart';

void main() {
  group('DemoOpenCodeClient', () {
    test('serves sample projects, sessions and seeded history', () async {
      final client = DemoOpenCodeClient();

      expect(await client.listProjects(), isNotEmpty);
      expect(await client.listSessions(), isNotEmpty);
      expect(await client.listModels(), isNotEmpty);

      final history = await client.getMessages('ses_demo_1');
      expect(history, isNotEmpty);
      // Seeded assistant message: reasoning + tool card + text.
      final parts = history.last.content.map((p) => p.type).toList();
      expect(parts, containsAll(['reasoning', 'tool', 'text']));
    });

    test('a permission request is pending so the card can be demoed', () async {
      final client = DemoOpenCodeClient();
      final pending = await client.listPermissionRequests();
      expect(pending, hasLength(1));

      await client.replyPermission(
          pending.first.sessionID, pending.first.id, 'once');
      expect(await client.listPermissionRequests(), isEmpty);
    });

    test('prompt streams a reply and stores it in the history', () async {
      final client = DemoOpenCodeClient();
      final types = <String>[];
      client.events(onStatus: (_) {}).listen((e) => types.add(e.type));

      await client.prompt('ses_demo_2', 'مرحبا');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(types, contains('session.execution.started'));
      expect(types, contains('session.text.delta'));
      expect(types, contains('session.execution.succeeded'));

      final history = await client.getMessages('ses_demo_2');
      expect(history.first.type, 'user');
      expect(history.last.type, 'assistant');
    });
  });

  testWidgets('demo mode fills the home screen with sample data',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final appState = AppState();
    final settings = SettingsState(ConnectionStore())..setLang(AppLang.arabic);
    await tester.pumpWidget(
        OpenCodeMobileApp(appState: appState, settings: settings));
    await tester.pump(const Duration(milliseconds: 10));

    // Attach the demo server directly: `enterDemoMode()` also persists the
    // flag through secure storage, and that platform channel never answers in
    // a widget test (it would await forever).
    appState.attachForTest(DemoOpenCodeClient());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));

    // The banner makes it obvious this is not a real server.
    expect(find.text('وضع العرض التجريبي'), findsOneWidget);
    // Demo project + demo conversations are rendered.
    expect(find.text('taskflow'), findsWidgets);
    expect(find.text('أضف شاشة تسجيل الدخول'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
