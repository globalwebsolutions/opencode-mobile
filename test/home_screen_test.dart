import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/app.dart';
import 'package:opencode_mobile/core/connection_store.dart';
import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/state/app_state.dart';
import 'package:opencode_mobile/state/settings_state.dart';

import 'support/fake_opencode_client.dart';

const _projects = [
  OcProject(id: 'p1', canonical: '/tmp/pharmaos', vcs: 'git'),
  OcProject(id: 'p2', canonical: '/tmp/pushtosell'),
];

/// Phone-sized surface (e.g. a 393 x 852 device) so layout problems that only
/// show up on narrow screens — like a clipped top bar — fail the test.
Future<void> _pumpHome(
  WidgetTester tester,
  AppState appState, {
  FakeOpenCodeClient? client,
}) async {
  tester.view.physicalSize = const Size(393 * 3, 852 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final settings = SettingsState(ConnectionStore())..setLang(AppLang.arabic);
  await tester.pumpWidget(
      OpenCodeMobileApp(appState: appState, settings: settings));
  await tester.pump(const Duration(milliseconds: 10));
  appState.attachForTest(
      client ?? (FakeOpenCodeClient()..projects = _projects));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  testWidgets('top bar fits a phone width without clipping the wordmark',
      (tester) async {
    await _pumpHome(tester, AppState());

    // The wordmark renders in full (this used to be clipped to "OpenC…").
    expect(find.text('OpenCode'), findsOneWidget);

    // Nothing overflowed horizontally.
    expect(tester.takeException(), isNull);

    final rendered = tester.getSize(find.text('OpenCode'));
    expect(rendered.width, greaterThan(0));
  });

  testWidgets('overflow menu holds the guide and settings, projects stays out',
      (tester) async {
    await _pumpHome(tester, AppState());

    // Projects is a first-class icon action.
    expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    expect(find.text('دليل التوصيل'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('tapping the status dot opens the connection sheet',
      (tester) async {
    await _pumpHome(tester, AppState());

    await tester.tap(find.byType(AppLogo));
    await tester.pumpAndSettle();
    expect(find.text('حالة الاتصال'), findsOneWidget);
    expect(find.text('متصل'), findsOneWidget);
    expect(find.text('إدارة السيرفرات'), findsOneWidget);
  });

  testWidgets('a quick suggestion prefills the composer', (tester) async {
    await _pumpHome(tester, AppState());

    await tester.tap(find.text('صلّح باج في الكود'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'صلّح باج في الكود');
  });

  testWidgets('the project selector opens the searchable picker',
      (tester) async {
    await _pumpHome(tester, AppState());

    // The first project is preselected and shown on the selector card.
    expect(find.text('pharmaos'), findsOneWidget);

    await tester.tap(find.text('pharmaos'));
    await tester.pumpAndSettle();
    expect(find.text('اختار المشروع'), findsOneWidget);
    expect(find.text('2 من 2'), findsOneWidget);
    expect(find.text('pushtosell'), findsOneWidget);

    await tester.tap(find.text('pushtosell'));
    await tester.pumpAndSettle();
    expect(find.text('اختار المشروع'), findsNothing);
    expect(find.text('pushtosell'), findsOneWidget);
    expect(find.text('/tmp/pushtosell'), findsOneWidget);
  });

  testWidgets('recent chats show the latest conversations', (tester) async {
    final client = FakeOpenCodeClient()
      ..projects = _projects
      ..sessions = [
        const OcSession(
          id: 'ses_1',
          title: 'أحدث محادثة',
          directory: '/tmp/pharmaos',
          updatedMs: 2000,
        ),
        const OcSession(
          id: 'ses_2',
          title: 'محادثة أقدم',
          directory: '/tmp/pushtosell',
          updatedMs: 1000,
        ),
      ];
    await _pumpHome(tester, AppState(), client: client);

    expect(find.text('آخر المحادثات'), findsOneWidget);
    expect(find.text('أحدث محادثة'), findsOneWidget);

    // The list is lazy: scroll down to reach the second conversation.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('محادثة أقدم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
