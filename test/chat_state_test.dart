import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/core/opencode_client.dart';
import 'package:opencode_mobile/state/app_state.dart';
import 'package:opencode_mobile/state/chat_state.dart';

void main() {
  late HttpServer server;
  late AppState app;
  late ChatState chat;

  setUp(() async {
    final body = jsonEncode({
      'data': [
        {
          'id': 'msg_u1',
          'type': 'user',
          'text': 'السلام عليكم',
          'time': {'created': 1},
        },
        {
          'id': 'msg_a1',
          'type': 'assistant',
          'agent': 'build',
          'model': {'id': 'glm-5.3', 'providerID': 'opencode-go'},
          'content': [
            {'type': 'text', 'text': 'وعليكم السلام'},
          ],
          'finish': 'stop',
          'time': {'created': 2},
        },
      ],
    });
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/api/session/ses_1/message') {
        request.response.statusCode = 200;
        request.response.write(body);
      } else if (request.uri.path == '/api/session/ses_1/permission') {
        request.response.statusCode = 200;
        request.response.write(jsonEncode({'data': []}));
      } else if (request.uri.path == '/api/session/ses_1/prompt') {
        request.response.statusCode = 200;
        request.response.write(jsonEncode({'data': {'id': 'inbox_1'}}));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });

    final client = OpenCodeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      token: 't',
    );
    app = AppState();
    app.attachForTest(client);
    chat = ChatState(app: app, sessionID: 'ses_1');
    addTearDown(() {
      chat.dispose();
      app.dispose();
    });
    await chat.load();
  });

  tearDown(() async {
    await server.close(force: true);
  });

  /// Emits through the app's broadcast stream and waits for delivery.
  Future<void> emit(String type, Map<String, dynamic> data) async {
    app.emitEventForTest(OcEvent(
      id: 'evt',
      type: type,
      data: {'sessionID': 'ses_1', ...data},
    ));
    await pumpEventQueue();
  }

  test('loads history and assigns ordinals', () {
    expect(chat.messages.length, 2);
    expect(chat.messages.first.type, 'user');
    expect(chat.messages.first.text, 'السلام عليكم');
    final assistant = chat.messages.last;
    expect(assistant.content.first.type, 'text');
    expect(assistant.content.first.ordinal, 0);
  });

  test('ignores events from other sessions', () async {
    app.emitEventForTest(OcEvent(
      id: 'e',
      type: 'session.text.delta',
      data: {'sessionID': 'ses_other', 'assistantMessageID': 'msg_new'},
    ));
    await pumpEventQueue();
    expect(chat.messages.length, 2);
  });

  test('builds a live assistant message from streamed events', () async {
    final msgID = 'msg_live_1';
    await emit('session.execution.started', {});
    await emit('session.step.started', {
      'assistantMessageID': msgID,
      'agent': 'build',
      'model': {'id': 'glm-5.3', 'providerID': 'opencode-go'},
    });
    expect(chat.busy, isTrue);
    expect(chat.messages.length, 3);
    expect(chat.messages.last.streaming, isTrue);
    expect(chat.messages.last.agent, 'build');

    await emit('session.reasoning.started',
        {'assistantMessageID': msgID, 'ordinal': 0});
    await emit('session.reasoning.delta',
        {'assistantMessageID': msgID, 'ordinal': 0, 'delta': 'أفكر...'});
    await emit('session.reasoning.ended',
        {'assistantMessageID': msgID, 'ordinal': 0, 'text': 'أفكر بالحل'});

    await emit('session.text.started',
        {'assistantMessageID': msgID, 'ordinal': 0});
    await emit('session.text.delta',
        {'assistantMessageID': msgID, 'ordinal': 0, 'delta': 'أهلا '});
    await emit('session.text.delta',
        {'assistantMessageID': msgID, 'ordinal': 0, 'delta': 'بك'});
    await emit('session.text.ended',
        {'assistantMessageID': msgID, 'ordinal': 0, 'text': 'أهلا بك'});

    final live = chat.messages.last;
    expect(live.content.length, 2);
    expect(live.content[0].type, 'reasoning');
    expect(live.content[0].text, 'أفكر بالحل');
    expect(live.content[1].type, 'text');
    expect(live.content[1].text, 'أهلا بك');

    // Tool call lifecycle.
    await emit('session.tool.input.started',
        {'assistantMessageID': msgID, 'id': 'tool_1', 'name': 'shell'});
    await emit('session.tool.input.delta',
        {'assistantMessageID': msgID, 'id': 'tool_1', 'delta': '{"comma'});
    await emit('session.tool.input.ended', {
      'assistantMessageID': msgID,
      'id': 'tool_1',
      'text': '{"command": "ls"}',
    });
    await emit('session.tool.called', {
      'assistantMessageID': msgID,
      'id': 'tool_1',
      'input': {'command': 'ls'},
      'executed': false,
    });
    await emit('session.tool.success', {
      'assistantMessageID': msgID,
      'id': 'tool_1',
      'content': [
        {'type': 'text', 'text': 'file1'}
      ],
    });

    final tool = chat.messages.last.content
        .where((p) => p.type == 'tool')
        .first;
    expect(tool.toolName, 'shell');
    expect(tool.toolStatus, 'completed');
    expect(tool.toolOutput, 'file1');

    await emit('session.step.ended', {
      'assistantMessageID': msgID,
      'finish': 'stop',
      'cost': 0.01,
      'tokens': {'input': 10, 'output': 5},
    });
    expect(chat.messages.last.streaming, isFalse);
    expect(chat.messages.last.finish, 'stop');
    expect(chat.messages.last.cost, 0.01);

    // Execution end reconciles with the server's message list.
    await emit('session.execution.succeeded', {});
    await pumpEventQueue();
    expect(chat.busy, isFalse);
    // The server copy has 2 messages; the reconciled list replaces the
    // optimistic live data.
    expect(chat.messages.length, 2);
  });

  test('streaming can resume from a fetched partial message', () async {
    // Simulate fetching a message that is mid-stream: reasoning done, text
    // partial. Then the delta continues from where the fetch left off.
    await emit('session.step.started',
        {'assistantMessageID': 'msg_partial', 'agent': 'build'});
    await emit('session.text.started',
        {'assistantMessageID': 'msg_partial', 'ordinal': 0});
    await emit('session.text.delta',
        {'assistantMessageID': 'msg_partial', 'ordinal': 0, 'delta': 'نص جزء '});
    await emit('session.text.delta',
        {'assistantMessageID': 'msg_partial', 'ordinal': 0, 'delta': 'تاني'});
    expect(
      chat.messages.last.content.first.text,
      'نص جزء تاني',
    );
  });

  test('send posts the prompt and adds an optimistic user message', () async {
    await chat.send('ازيك');
    expect(chat.messages.last.type, 'user');
    expect(chat.messages.last.text, 'ازيك');
    expect(chat.busy, isTrue);
  });
}
