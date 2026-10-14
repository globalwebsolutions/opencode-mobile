import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/widgets/developer_card.dart';
import 'package:opencode_mobile/widgets/related_projects_card.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: ListView(children: [child]))),
  );
  await tester.pump();
}

void main() {
  testWidgets('developer card credits the team at phone width', (tester) async {
    await _pump(tester, const DeveloperCard());

    expect(find.text(developerName), findsOneWidget);
    expect(find.textContaining(developerYear), findsWidgets);
    expect(find.text('Globalweb.Solutions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('related projects card lists the VS Code companion',
      (tester) async {
    await _pump(tester, const RelatedProjectsCard());

    expect(find.text('OpenCode Chat Sidebar'), findsOneWidget);
    expect(find.text('GitHub Releases'), findsOneWidget);
    // The link must be the Releases page (that is where the .vsix lives).
    expect(relatedProjects.single.url, endsWith('/releases'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('related projects card survives a long description',
      (tester) async {
    await _pump(
      tester,
      const RelatedProjectsCard(projects: [
        RelatedProject(
          badge: 'XX',
          name: 'A very long project name that would overflow a narrow phone',
          descriptionAr: 'وصف طويل جدًا للتأكد إن مفيش أي قص أو overflow في الكارت',
          descriptionEn: 'A long description to make sure nothing overflows',
          url: 'https://example.com/releases',
          sourceLabel: 'GitHub Releases',
        ),
      ]),
    );

    expect(tester.takeException(), isNull);
  });

  test('copy is provided in both languages', () {
    L.lang = AppLang.arabic;
    expect(relatedProjects.single.description, contains('VS Code'));
    L.lang = AppLang.english;
    expect(relatedProjects.single.description, contains('VS Code'));
    L.lang = AppLang.arabic;
  });
}
