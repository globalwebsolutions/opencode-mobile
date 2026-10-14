import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/widgets/session_tile.dart';

/// Renders a single tile on a narrow phone surface — the meta row used to
/// overflow here (its model badge and time had no flex at all).
Future<void> _pumpTile(WidgetTester tester, OcSession session) async {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            SessionTile(session: session, busy: false, onTap: () {}),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('meta row fits without a directory', (tester) async {
    await _pumpTile(
      tester,
      const OcSession(
        id: 'ses_1',
        title: 'Waiting for shell command',
        model: ModelRef(id: 'kimi-k2.7-code', providerID: 'opencode-go'),
        cost: 0.007,
        updatedMs: 1000,
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('meta row fits with a long directory and model', (tester) async {
    await _pumpTile(
      tester,
      const OcSession(
        id: 'ses_2',
        title: 'Appending “world” to a.txt',
        directory: '/Users/render/Downloads/some-very-long-project-name',
        model: ModelRef(
          id: 'deepseek-v4.1-flash',
          providerID: 'opencode-go',
        ),
        cost: 0.014,
        updatedMs: 1000,
      ),
    );

    expect(tester.takeException(), isNull);
    // Only the last path segment is shown, and the row keeps its time.
    expect(find.text('some-very-long-project-name'), findsOneWidget);
  });
}
