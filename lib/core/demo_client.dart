/// Demo mode: a complete, in-memory OpenCode server.
///
/// Lets the app be opened, reviewed and tested without a real OpenCode
/// installation — which is what Google Play reviewers (and anyone trying the
/// app before pairing) need. All data below is fake.
library;

import 'dart:async';

import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/core/models.dart';
import 'package:opencode_mobile/core/opencode_client.dart';

/// Marks the fake server so the UI can label the session as a demo.
const demoBaseUrl = 'demo://opencode';

class DemoOpenCodeClient extends OpenCodeClient {
  DemoOpenCodeClient() : super(baseUrl: demoBaseUrl, token: 'demo');

  final StreamController<OcEvent> _events =
      StreamController<OcEvent>.broadcast();
  int _seq = 0;
  final List<PermissionRequest> _pending = [demoPermissionRequest()];
  final Map<String, List<OcMessage>> _history = {
    'ses_demo_1': demoSeedMessages(),
  };

  static final int _now = DateTime.now().millisecondsSinceEpoch;

  @override
  Future<ServerInfo> getInfo() async =>
      const ServerInfo(version: '2.0.26 · demo', urls: [demoBaseUrl]);

  @override
  Future<List<OcProject>> listProjects() async => demoProjects;

  @override
  Future<List<OcSession>> listSessions({int limit = 100}) async =>
      demoSessionList();

  @override
  Future<List<OcMessage>> getMessages(String sessionID,
          {int limit = 200}) async =>
      List.of(_history[sessionID] ?? const <OcMessage>[]);

  @override
  Future<OcSession> createSession(
      {required String directory, String? title}) async {
    final session = OcSession(
      id: 'ses_demo_${_seq++}',
      title: title ?? L.tr('محادثة تجريبية', 'Demo chat'),
      directory: directory,
      agent: 'build',
      model: demoModels.first.ref,
      createdMs: _now,
      updatedMs: _now,
    );
    _sessions.insert(0, session);
    return session;
  }

  @override
  Future<List<ModelOption>> listModels() async => demoModels;

  @override
  Future<void> setSessionModel(String sessionID, ModelRef model) async {}

  @override
  Future<List<PermissionRequest>> listSessionPermissions(
      String sessionID) async {
    await Future<void>.delayed(Duration.zero);
    return _pending.where((p) => p.sessionID == sessionID).toList();
  }

  @override
  Future<List<PermissionRequest>> listPermissionRequests() async =>
      List.of(_pending);

  @override
  Future<void> replyPermission(
      String sessionID, String requestID, String decision) async {
    _pending.removeWhere((p) => p.id == requestID);
  }

  /// Streams a canned reply so the reviewer sees how live streaming, tool
  /// cards and cost look.
  @override
  Future<void> prompt(String sessionID, String text,
      {List<Map<String, dynamic>> files = const []}) async {
    final reply = L.tr(
      'وضع العرض: ده رد تجريبي. لما توصّل سيرفر OpenCode بتاعك، الردود دي بتيجي '
          'من الوكيل الحقيقي أداة بأداة ومعاها التكلفة والتوكنز.',
      'Demo mode: this is a canned reply. Once you pair your own OpenCode '
          'server, real agent replies stream in here tool by tool with cost '
          'and token usage.',
    );

    final history = _history.putIfAbsent(sessionID, () => []);
    history.add(OcMessage(
      id: 'msg_demo_u${_seq++}',
      type: 'user',
      text: text,
      createdMs: DateTime.now().millisecondsSinceEpoch,
    ));

    final assistantID = 'msg_demo_a${_seq++}';
    _emit('session.execution.started', {'sessionID': sessionID});
    _emit('session.step.started', {
      'sessionID': sessionID,
      'assistantMessageID': assistantID,
      'agent': 'build',
      'model': demoModels.first.ref.toJson(),
    });
    _emit('session.reasoning.started',
        {'sessionID': sessionID, 'assistantMessageID': assistantID, 'ordinal': 0});
    for (final chunk in _chunks(
        L.tr('بفكر في السؤال... ', 'Thinking about the question... '))) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      _emit('session.reasoning.delta', {
        'sessionID': sessionID,
        'assistantMessageID': assistantID,
        'ordinal': 0,
        'delta': chunk,
      });
    }
    _emit('session.reasoning.ended', {
      'sessionID': sessionID,
      'assistantMessageID': assistantID,
      'ordinal': 0,
      'text': L.tr('بفكر في السؤال...', 'Thinking about the question...'),
    });

    final toolID = 'tool_demo_${_seq++}';
    _emit('session.tool.called', {
      'sessionID': sessionID,
      'assistantMessageID': assistantID,
      'id': toolID,
      'name': 'read',
      'input': {'filePath': 'lib/main.dart'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _emit('session.tool.success', {
      'sessionID': sessionID,
      'assistantMessageID': assistantID,
      'id': toolID,
      'name': 'read',
      'output': 'void main() { ... }',
    });

    _emit('session.text.started',
        {'sessionID': sessionID, 'assistantMessageID': assistantID, 'ordinal': 0});
    for (final chunk in _chunks(reply)) {
      await Future<void>.delayed(const Duration(milliseconds: 45));
      _emit('session.text.delta', {
        'sessionID': sessionID,
        'assistantMessageID': assistantID,
        'ordinal': 0,
        'delta': chunk,
      });
    }
    _emit('session.text.ended', {
      'sessionID': sessionID,
      'assistantMessageID': assistantID,
      'ordinal': 0,
      'text': reply,
    });
    _emit('session.step.ended', {
      'sessionID': sessionID,
      'assistantMessageID': assistantID,
      'finish': 'stop',
      'cost': 0.0,
      'tokens': {'input': 0, 'output': 0},
    });
    _emit('session.execution.succeeded', {'sessionID': sessionID});

    history.add(OcMessage(
      id: assistantID,
      type: 'assistant',
      agent: 'build',
      model: demoModels.first.ref,
      finish: 'stop',
      content: [OcPart(type: 'text', text: reply, ordinal: 0)],
    ));
  }

  @override
  Future<void> interrupt(String sessionID) async {
    _emit('session.execution.interrupted', {'sessionID': sessionID});
  }

  @override
  Stream<OcEvent> events({
    void Function(SseStatus status)? onStatus,
    Duration maxBackoff = const Duration(seconds: 30),
  }) {
    onStatus?.call(SseStatus.connected);
    return _events.stream;
  }

  @override
  void close() {
    // Keep the controller open: the demo connection never really drops.
  }

  void _emit(String type, Map<String, dynamic> data) {
    if (_events.isClosed) return;
    _events.add(OcEvent(id: 'evt_demo_${_seq++}', type: type, data: data));
  }

  List<String> _chunks(String text) {
    final out = <String>[];
    for (var i = 0; i < text.length; i += 6) {
      out.add(text.substring(i, i + 6 > text.length ? text.length : i + 6));
    }
    return out;
  }

  final List<OcSession> _sessions = demoSessionList();
}

// -----------------------------------------------------------------------------
// Fixtures
// -----------------------------------------------------------------------------

/// Built on demand (not `const`) so the demo data follows the app language.
PermissionRequest demoPermissionRequest() => PermissionRequest(
      id: 'perm_demo_1',
      sessionID: 'ses_demo_1',
      action: 'bash',
      resources: const ['rm -rf build/'],
      message: L.tr(
        'الوكيل عايز يشغل أمر على جهازك — وافق أو ارفض',
        'The agent wants to run a command on your machine — allow or deny',
      ),
      metadata: {'title': L.tr('تشغيل أمر', 'Run a command')},
    );

const demoProjects = <OcProject>[
  OcProject(id: 'prj_demo_1', canonical: '/Users/you/projects/taskflow', vcs: 'git'),
  OcProject(id: 'prj_demo_2', canonical: '/Users/you/projects/storefront', vcs: 'git'),
  OcProject(id: 'prj_demo_3', canonical: '/Users/you/notes'),
];

/// A few models, mirroring the shape the real server returns.
final demoModels = <ModelOption>[
  const ModelOption(
    id: 'glm-5.3',
    providerID: 'opencode-go',
    name: 'GLM 5.3',
  ),
  const ModelOption(
    id: 'deepseek-v4.1-flash',
    providerID: 'opencode-go',
    name: 'DeepSeek V4.1 Flash',
  ),
  const ModelOption(
    id: 'claude-sonnet-4-5',
    providerID: 'anthropic',
    name: 'Claude Sonnet 4.5',
  ),
];

extension on ModelOption {
  ModelRef get ref => ModelRef(id: id, providerID: providerID);
}

/// Newest first, with a live "running" session so the busy states show too.
List<OcSession> demoSessionList() {
  final now = DemoOpenCodeClient._now;
  return [
    OcSession(
      id: 'ses_demo_1',
      title: L.tr('أضف شاشة تسجيل الدخول', 'Add the login screen'),
      agent: 'build',
      model: const ModelRef(id: 'glm-5.3', providerID: 'opencode-go'),
      directory: '/Users/you/projects/taskflow',
      cost: 0.0412,
      tokens: const TokenUsage(input: 18400, output: 3120, reasoning: 890),
      createdMs: now - 7200000,
      updatedMs: now - 60000,
    ),
    OcSession(
      id: 'ses_demo_2',
      title: L.tr('صلّح باج في السلة', 'Fix the cart bug'),
      agent: 'build',
      model: const ModelRef(id: 'deepseek-v4.1-flash', providerID: 'opencode-go'),
      directory: '/Users/you/projects/storefront',
      cost: 0.0093,
      tokens: const TokenUsage(input: 7200, output: 410, reasoning: 120),
      createdMs: now - 86400000,
      updatedMs: now - 5400000,
    ),
    OcSession(
      id: 'ses_demo_3',
      title: L.tr('راجع تغييرات الجيت', 'Review the git changes'),
      agent: 'plan',
      model: const ModelRef(id: 'claude-sonnet-4-5', providerID: 'anthropic'),
      directory: '/Users/you/projects/taskflow',
      cost: 0.0277,
      tokens: const TokenUsage(input: 31000, output: 1450),
      createdMs: now - 172800000,
      updatedMs: now - 90000000,
    ),
    OcSession(
      id: 'ses_demo_4',
      title: L.tr('اكتب README للمشروع', 'Write the project README'),
      agent: 'build',
      model: const ModelRef(id: 'glm-5.3', providerID: 'opencode-go'),
      directory: '/Users/you/notes',
      cost: 0.0018,
      tokens: const TokenUsage(input: 2400, output: 620),
      createdMs: now - 259200000,
      updatedMs: now - 172800000,
    ),
  ];
}

/// Seed history for the first demo session, so opening it shows real-looking
/// content: reasoning, a tool card, streamed text and cost.
List<OcMessage> demoSeedMessages() => [
      OcMessage(
        id: 'msg_seed_1',
        type: 'user',
        text: L.tr('ضيف شاشة تسجيل دخول بإيميل وباسورد',
            'Add a login screen with email and password'),
        createdMs: DemoOpenCodeClient._now - 3600000,
      ),
      OcMessage(
        id: 'msg_seed_2',
        type: 'assistant',
        agent: 'build',
        model: const ModelRef(id: 'glm-5.3', providerID: 'opencode-go'),
        finish: 'stop',
        createdMs: DemoOpenCodeClient._now - 3500000,
        content: [
          OcPart(
            type: 'reasoning',
            ordinal: 0,
            text: L.tr(
                'أشوف بنية المشروع الأول بعدين أضيف الشاشة في مسار الـ auth.',
                'Let me read the project structure first, then add the screen on '
                    'the auth route.'),
          ),
          const OcPart(
            type: 'tool',
            toolId: 'tool_seed_1',
            toolName: 'read',
            toolStatus: 'completed',
            toolInput: '{"filePath": "lib/app.dart"}',
            toolOutput: 'MaterialApp(home: const _Root(), ...)',
          ),
          OcPart(
            type: 'text',
            ordinal: 0,
            text: L.tr(
              'تمام، لقيت نقطة الربط. ضفت شاشة تسجيل الدخول وربطتها بالتنقل، '
                  'وكمان ضفت التحقق من الإيميل والباسورد قبل الإرسال.',
              'Found the right hook. I added the login screen, wired it into the '
                  'navigation and added email/password validation before submit.',
            ),
          ),
        ],
      ),
    ];
