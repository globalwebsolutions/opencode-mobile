import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/core/models.dart';

/// Regression tests parsing recorded real server payloads (OpenCode 2.0.x).
void main() {
  test('parses a session from recorded server JSON', () {
    const raw = '''
    {
      "id": "ses_ecb132f49ffevtCGVJAz36590O",
      "projectID": "47293331e1eabc3c7de4274f053b3ce0f9636331",
      "agent": "build",
      "model": {"id": "glm-5.3", "providerID": "opencode-go", "variant": "default"},
      "cost": 0.33669348,
      "tokens": {
        "input": 116989, "output": 13531, "reasoning": 0,
        "cache": {"read": 438953, "write": 0}
      },
      "time": {"created": 1791889297785, "updated": 1791889652439},
      "title": "فتح OpenCode على الموبايل باستخدام Flutter",
      "location": {"directory": "/Users/render/Documents/Codex/PharmaOS"}
    }
    ''';
    final session = OcSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    expect(session.id, 'ses_ecb132f49ffevtCGVJAz36590O');
    expect(session.agent, 'build');
    expect(session.model?.id, 'glm-5.3');
    expect(session.model?.providerID, 'opencode-go');
    expect(session.directory, '/Users/render/Documents/Codex/PharmaOS');
    expect(session.tokens.input, 116989);
    expect(session.tokens.cacheRead, 438953);
    expect(session.cost, closeTo(0.3367, 0.0001));
    expect(session.createdMs, 1791889297785);
  });

  test('parses a user message from recorded server JSON', () {
    const raw = '''
    {
      "id": "msg_134ecd0b1001uTXuD00x0kS5rQ",
      "metadata": {"displayText": "hi"},
      "time": {"created": 1791889297871},
      "text": "عايز اعمل برنامج فلاتر",
      "files": [], "agents": [],
      "type": "user"
    }
    ''';
    final message =
        OcMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(message.type, 'user');
    expect(message.text, 'عايز اعمل برنامج فلاتر');
    expect(message.content, isEmpty);
  });

  test('parses an assistant message with reasoning, text, and tool parts',
      () {
    const raw = '''
    {
      "id": "msg_134f26c48001t81B2ygQgNHzFL",
      "time": {"created": 1791889665112, "streamed": 1791889668917},
      "type": "assistant",
      "agent": "build",
      "model": {"id": "glm-5.3", "providerID": "opencode-go"},
      "content": [
        {"type": "reasoning", "text": "Let me check.",
         "state": {"reasoningField": "reasoning_content"},
         "time": {"created": 1}},
        {"type": "text", "text": "الشكل مختلف عن المتوقع"},
        {"type": "tool", "id": "chatcmpl-tool-ba0350d618335569", "name": "shell",
         "executed": false,
         "state": {
           "status": "running",
           "input": {"command": "echo hi"},
           "metadata": {}
         },
         "time": {"created": 2, "ran": 3}}
      ],
      "finish": "tool-calls", "rawFinish": "tool_calls",
      "cost": 0.01337894
    }
    ''';
    final message =
        OcMessage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(message.type, 'assistant');
    expect(message.content.length, 3);

    final reasoning = message.content[0];
    expect(reasoning.type, 'reasoning');
    expect(reasoning.text, 'Let me check.');

    final text = message.content[1];
    expect(text.type, 'text');
    expect(text.text, contains('الشكل'));

    final tool = message.content[2];
    expect(tool.type, 'tool');
    expect(tool.toolId, 'chatcmpl-tool-ba0350d618335569');
    expect(tool.toolName, 'shell');
    expect(tool.toolStatus, 'running');
    expect(tool.toolInput, contains('echo hi'));
    expect(message.finish, 'tool-calls');
    expect(message.cost, closeTo(0.013379, 0.000001));
  });

  test('parses a completed tool state with output content', () {
    const raw = '''
    {
      "type": "tool", "id": "chatcmpl-tool-a2d3da9a8d67df6b", "name": "webfetch",
      "executed": false,
      "state": {
        "status": "completed",
        "input": {"url": "https://example.com"},
        "content": [{"type": "text", "text": "the page"}],
        "metadata": {"status": "completed", "truncated": false, "exit": 0}
      },
      "time": {"created": 4, "ran": 5, "completed": 6}
    }
    ''';
    final part = OcPart.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(part.toolStatus, 'completed');
    expect(part.toolOutput, 'the page');
    expect(part.toolMetadata?['exit'], 0);
    expect(part.toolInput, contains('example.com'));
  });

  test('parses a permission request', () {
    const raw = '''
    {
      "id": "perm_1", "sessionID": "ses_x", "action": "bash",
      "resources": ["/tmp/x.txt"], "save": ["bash"],
      "message": "Wants to run bash", "metadata": {"title": "Shell"}
    }
    ''';
    final request = PermissionRequest.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
    expect(request.id, 'perm_1');
    expect(request.sessionID, 'ses_x');
    expect(request.action, 'bash');
    expect(request.resources, ['/tmp/x.txt']);
    expect(request.actionLabel, 'Shell');
  });

  test('parses an SSE event envelope', () {
    const raw = '''
    {"id":"evt_1","type":"session.text.delta",
     "data":{"sessionID":"ses_a","assistantMessageID":"msg_a","ordinal":0,"delta":"أ"}}
    ''';
    final event = OcEvent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    expect(event.type, 'session.text.delta');
    expect(event.data['delta'], 'أ');
    expect(event.data['sessionID'], 'ses_a');
  });
}
