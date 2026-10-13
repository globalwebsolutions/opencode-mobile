import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/core/opencode_client.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('redeems a pairing link and authenticates with Basic auth', () async {
    var sawAuth = false;
    server.listen((request) async {
      if (request.uri.path == '/auth/connect/CODE123') {
        request.response.statusCode = 200;
        request.response.write(jsonEncode({'token': 'test-token'}));
        await request.response.close();
      } else if (request.uri.path == '/api/info') {
        final auth = request.headers.value(HttpHeaders.authorizationHeader);
        sawAuth = auth ==
            'Basic ${base64Encode(utf8.encode('opencode:test-token'))}';
        request.response.statusCode = 200;
        request.response.write(jsonEncode({
          'version': '2.0.26',
          'urls': ['http://${server.address.address}:${server.port}'],
        }));
        await request.response.close();
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    });

    final token = await OpenCodeClient.redeemPairingLink(
        'http://${server.address.address}:${server.port}/auth/connect/CODE123');
    expect(token, 'test-token');

    final client = OpenCodeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: token,
    );
    final info = await client.getInfo();
    expect(info.version, '2.0.26');
    expect(sawAuth, isTrue);
  });

  test('rejects a non-pairing link', () async {
    expect(
      () => OpenCodeClient.baseUrlFromLink('http://x:1/other/path'),
      throwsFormatException,
    );
    expect(
      () => OpenCodeClient.baseUrlFromLink('ftp://x:1/auth/connect/abc'),
      throwsFormatException,
    );
  });

  test('lists sessions through the REST API', () async {
    server.listen((request) async {
      expect(request.uri.path, '/api/session');
      expect(request.uri.queryParameters['order'], 'desc');
      request.response.statusCode = 200;
      request.response.write(jsonEncode({
        'data': [
          {
            'id': 'ses_1',
            'agent': 'build',
            'model': {'id': 'glm-5.3', 'providerID': 'opencode-go'},
            'title': 'تجربة',
            'time': {'created': 1, 'updated': 2},
            'location': {'directory': '/tmp/proj'},
          }
        ],
      }));
      await request.response.close();
    });

    final client = OpenCodeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 't',
    );
    final sessions = await client.listSessions();
    expect(sessions.length, 1);
    expect(sessions.first.id, 'ses_1');
    expect(sessions.first.title, 'تجربة');
    expect(sessions.first.model?.id, 'glm-5.3');
  });

  test('streams and decodes SSE events, ignoring heartbeats', () async {
    final statusLog = <SseStatus>[];
    final doneSub = server.listen((request) async {
      expect(request.uri.path, '/api/event');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Basic ${base64Encode(utf8.encode('opencode:t'))}',
      );
      request.response.statusCode = 200;
      request.response.headers.contentType =
          ContentType.parse('text/event-stream; charset=utf-8');
      request.response.bufferOutput = false;
      await request.response.flush();

      void send(String frame) {
        request.response.write('data: $frame\n\n');
      }

      send(jsonEncode({'id': 'e1', 'type': 'server.connected', 'data': {}}));
      request.response.write(': heartbeat\n\n');
      send(jsonEncode({
        'id': 'e2',
        'type': 'session.text.delta',
        'data': {'sessionID': 'ses_1', 'delta': 'أهلا'}
      }));
      await request.response.flush();

      // Hold the response open until the client cancels the subscription.
      await Future<void>.delayed(const Duration(seconds: 2));
      await request.response.close();
    });

    final client = OpenCodeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 't',
    );
    final received = <String>[];
    final gotSecond = Completer<void>();
    late final StreamSubscription<OcEvent> subscription;
    subscription = client.events(onStatus: statusLog.add).listen((event) {
      received.add(event.type);
      if (received.length >= 2) {
        gotSecond.complete();
      }
    });
    await gotSecond.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    await doneSub.cancel();

    expect(received, containsAll(['server.connected', 'session.text.delta']));
    expect(statusLog, contains(SseStatus.connected));
  });
}
