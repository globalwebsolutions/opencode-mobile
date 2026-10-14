import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opencode_mobile/core/opencode_client.dart';
import 'package:opencode_mobile/core/quota.dart';
import 'package:opencode_mobile/core/usage.dart';

/// The exact shape the usage API returned for a Go account.
const _liveUsage = '''
{"usage":{
  "rolling":{"status":"ok","percent":0,"resetsAt":"2026-10-14T21:07:26.000Z"},
  "weekly":{"status":"ok","percent":10,"resetsAt":"2026-10-19T00:00:00.000Z"},
  "monthly":{"status":"ok","percent":5,"resetsAt":"2026-11-14T05:52:40.000Z"}
}}''';

void main() {
  group('QuotaSnapshot.fromUsageJson', () {
    test('parses the three Go windows in order', () {
      final snapshot = QuotaSnapshot.fromUsageJson(
          jsonDecode(_liveUsage) as Map<String, dynamic>);

      expect(snapshot.windows.map((w) => w.id).toList(),
          ['rolling', 'weekly', 'monthly']);
      expect(snapshot.monthly!.percent, 5);
      expect(snapshot.monthly!.remaining, 95);
      expect(snapshot.windows.first.remaining, 100);
      expect(snapshot.monthly!.resetsAt, isNotNull);
    });

    test('tolerates an empty or unexpected payload', () {
      expect(QuotaSnapshot.fromUsageJson(const {}).isEmpty, isTrue);
      expect(
          QuotaSnapshot.fromUsageJson(const {'usage': 'nope'}).isEmpty, isTrue);
    });

    test('never reports a negative remainder', () {
      final over = QuotaSnapshot.fromUsageJson(const {
        'usage': {
          'monthly': {'percent': 130},
        },
      });
      expect(over.monthly!.remaining, 0);
    });
  });

  group('pickConsoleToken', () {
    test('prefers the active opencode credential', () {
      final token = pickConsoleToken([
        {
          'integrationID': 'opencode',
          'active': false,
          'value': {'type': 'oauth', 'access': 'old'},
        },
        {
          'integrationID': 'opencode',
          'active': true,
          'value': {'type': 'oauth', 'access': 'live'},
        },
      ]);
      expect(token, 'live');
    });

    test('ignores other integrations and tokenless entries', () {
      expect(
        pickConsoleToken([
          {'integrationID': 'github', 'active': true, 'value': {'access': 'x'}},
          {'integrationID': 'opencode', 'active': true, 'value': {'type': 'api'}},
        ]),
        isNull,
      );
    });

    test('falls back to an inactive credential rather than none', () {
      expect(
        pickConsoleToken([
          {
            'integrationID': 'opencode',
            'active': false,
            'value': {'access': 'saved'},
          },
        ]),
        'saved',
      );
    });
  });

  group('fetchQuota', () {
    test('sends the console token and parses the answer', () async {
      String? seenAuth;
      final snapshot = await fetchQuota(
        _FakeClient([{'integrationID': 'opencode', 'active': true, 'value': {'access': 'tok_1'}}]),
        httpClient: MockClient((request) async {
          seenAuth = request.headers['Authorization'];
          expect(request.url.toString(), quotaUsageUrl);
          return http.Response(_liveUsage, 200);
        }),
      );

      expect(seenAuth, 'Bearer tok_1');
      expect(snapshot.monthly!.remaining, 95);
    });

    test('a 403 reads as "no Go plan", not as an auth failure', () async {
      // Anyone on Zen pay-as-you-go or their own provider keys lands here, so
      // the wording must not sound like something broke.
      try {
        await fetchQuota(
          _FakeClient([
            {'integrationID': 'opencode', 'active': true, 'value': {'access': 'tok'}},
          ]),
          httpClient: MockClient((_) async => http.Response('{}', 403)),
        );
        fail('expected a QuotaException');
      } on QuotaException catch (e) {
        expect(e.message, contains('خطة Go'));
      }
    });

    test('explains an expired credential instead of crashing', () async {
      await expectLater(
        fetchQuota(
          _FakeClient([
            {'integrationID': 'opencode', 'active': true, 'value': {'access': 'tok'}},
          ]),
          httpClient: MockClient((_) async => http.Response('nope', 401)),
        ),
        throwsA(isA<QuotaException>()),
      );
    });

    test('reports a server with no signed-in account', () async {
      await expectLater(
        fetchQuota(_FakeClient(const [])),
        throwsA(isA<QuotaException>()),
      );
    });
  });

  group('UsageSummary.fromJson', () {
    // Trimmed from the real /api/experimental/session/stats payload.
    final payload = jsonDecode('''
{"data":{"range":{"from":1790801924157,"to":1791996405540},"sessions":109,
 "prompts":371,"steps":7041,
 "tokens":{"input":21345934,"output":3027125,"reasoning":1030088,
           "cache":{"read":1472497549,"write":44647108}},
 "cost":100.46059657800004}}''') as Map<String, dynamic>;

    test('reads cost, tokens and the reported period', () {
      final usage = UsageSummary.fromJson(payload);
      expect(usage.cost, closeTo(100.46, 0.01));
      expect(usage.inputTokens, 21345934);
      expect(usage.outputTokens, 3027125);
      expect(usage.reasoningTokens, 1030088);
      expect(usage.totalTokens, 25403147);
      expect(usage.sessions, 109);
      expect(usage.prompts, 371);
      expect(usage.periodDays, greaterThan(1));
      expect(usage.isEmpty, isFalse);
    });

    test('survives a payload without the data envelope or range', () {
      final usage = UsageSummary.fromJson(const {'cost': 1.5});
      expect(usage.cost, 1.5);
      expect(usage.periodDays, 0);
      expect(usage.totalTokens, 0);
    });
  });

  test('quotaResetLabel counts down in days, hours and minutes', () {
    final inThreeDays = DateTime.now().add(const Duration(days: 3, hours: 1));
    expect(quotaResetLabel(inThreeDays), '3 يوم');

    final inFiveHours = DateTime.now().add(const Duration(hours: 5, minutes: 5));
    expect(quotaResetLabel(inFiveHours), '5 ساعة');

    // Half a minute of slack so the assertion can't land on 9 minutes.
    final inTenMinutes =
        DateTime.now().add(const Duration(minutes: 10, seconds: 30));
    expect(quotaResetLabel(inTenMinutes), '10 دقيقة');

    expect(quotaResetLabel(DateTime.now().subtract(const Duration(hours: 1))),
        'الآن');
  });
}

/// Minimal stand-in for OpenCodeClient that only answers credentials.
class _FakeClient extends OpenCodeClient {
  _FakeClient(this.credentials)
      : super(baseUrl: 'http://fake.local', token: 'fake');

  final List<Map<String, dynamic>> credentials;

  @override
  Future<List<Map<String, dynamic>>> listCredentials() async => credentials;
}
