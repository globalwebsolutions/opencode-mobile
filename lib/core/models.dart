/// Data models for the OpenCode V2 HTTP API.
///
/// Shapes are derived from the real server responses (OpenCode 2.0.x).
library;

import 'dart:convert';

class ModelRef {
  final String id;
  final String providerID;
  final String? variant;

  const ModelRef({required this.id, required this.providerID, this.variant});

  String get label => '$providerID/$id';

  factory ModelRef.fromJson(Map<String, dynamic> json) => ModelRef(
        id: json['id'] as String? ?? '',
        providerID: json['providerID'] as String? ?? '',
        variant: json['variant'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerID': providerID,
        if (variant != null) 'variant': variant,
      };
}

class TokenUsage {
  final int input;
  final int output;
  final int reasoning;
  final int cacheRead;
  final int cacheWrite;

  const TokenUsage({
    this.input = 0,
    this.output = 0,
    this.reasoning = 0,
    this.cacheRead = 0,
    this.cacheWrite = 0,
  });

  int get total => input + output + reasoning + cacheRead + cacheWrite;

  factory TokenUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TokenUsage();
    final cache = json['cache'];
    return TokenUsage(
      input: (json['input'] as num?)?.toInt() ?? 0,
      output: (json['output'] as num?)?.toInt() ?? 0,
      reasoning: (json['reasoning'] as num?)?.toInt() ?? 0,
      cacheRead: (cache is Map ? (cache['read'] as num?)?.toInt() ?? 0 : 0),
      cacheWrite: (cache is Map ? (cache['write'] as num?)?.toInt() ?? 0 : 0),
    );
  }
}

class OcSession {
  final String id;
  final String? title;
  final String? agent;
  final ModelRef? model;
  final String? projectID;
  final String? directory;
  final double? cost;
  final TokenUsage tokens;
  final int? createdMs;
  final int? updatedMs;

  const OcSession({
    required this.id,
    this.title,
    this.agent,
    this.model,
    this.projectID,
    this.directory,
    this.cost,
    this.tokens = const TokenUsage(),
    this.createdMs,
    this.updatedMs,
  });

  factory OcSession.fromJson(Map<String, dynamic> json) {
    final time = json['time'];
    final location = json['location'];
    return OcSession(
      id: json['id'] as String? ?? '',
      title: json['title'] as String?,
      agent: json['agent'] as String?,
      model: json['model'] is Map
          ? ModelRef.fromJson(Map<String, dynamic>.from(json['model'] as Map))
          : null,
      projectID: json['projectID'] as String?,
      directory: location is Map ? location['directory'] as String? : null,
      cost: (json['cost'] as num?)?.toDouble(),
      tokens: TokenUsage.fromJson(json['tokens'] is Map
          ? Map<String, dynamic>.from(json['tokens'] as Map)
          : null),
      createdMs: time is Map ? (time['created'] as num?)?.toInt() : null,
      updatedMs: time is Map ? (time['updated'] as num?)?.toInt() : null,
    );
  }

  OcSession copyWith({
    String? title,
    String? agent,
    ModelRef? model,
    double? cost,
    TokenUsage? tokens,
    int? updatedMs,
  }) =>
      OcSession(
        id: id,
        title: title ?? this.title,
        agent: agent ?? this.agent,
        model: model ?? this.model,
        projectID: projectID,
        directory: directory,
        cost: cost ?? this.cost,
        tokens: tokens ?? this.tokens,
        createdMs: createdMs,
        updatedMs: updatedMs ?? this.updatedMs,
      );
}

/// One content block inside an assistant message.
class OcPart {
  final String type; // 'text' | 'reasoning' | 'tool' | 'step-start' | ...
  final String? text;
  final int? ordinal;
  // Tool part fields.
  final String? toolId;
  final String? toolName;
  final String? toolStatus; // pending | running | completed | error
  final String? toolInput; // pretty-printed input JSON
  final String? toolOutput; // combined text output
  final String? toolError;
  final Map<String, dynamic>? toolMetadata;
  final int? createdMs;

  const OcPart({
    required this.type,
    this.text,
    this.ordinal,
    this.toolId,
    this.toolName,
    this.toolStatus,
    this.toolInput,
    this.toolOutput,
    this.toolError,
    this.toolMetadata,
    this.createdMs,
  });

  factory OcPart.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final time = json['time'];
    if (type == 'tool') {
      final state = json['state'];
      String? input;
      if (state is Map && state['input'] != null) {
        input = _prettyJson(state['input']);
      }
      String? output;
      if (state is Map && state['content'] is List) {
        final buf = StringBuffer();
        for (final c in state['content'] as List) {
          if (c is Map && c['text'] is String) {
            buf.write(c['text'] as String);
            buf.write('\n');
          }
        }
        output = buf.toString().trim();
      }
      final metadata = state is Map && state['metadata'] is Map
          ? Map<String, dynamic>.from(state['metadata'] as Map)
          : null;
      return OcPart(
        type: 'tool',
        toolId: json['id'] as String?,
        toolName: json['name'] as String?,
        toolStatus: state is Map ? state['status'] as String? : null,
        toolInput: input,
        toolOutput: output,
        toolMetadata: metadata,
        createdMs: time is Map ? (time['ran'] as num?)?.toInt() : null,
      );
    }
    return OcPart(
      type: type,
      text: json['text'] as String?,
      createdMs: time is Map ? (time['created'] as num?)?.toInt() : null,
    );
  }

  static String _prettyJson(Object? o) {
    try {
      return const JsonEncoder.withIndent('  ').convert(o);
    } catch (_) {
      return o.toString();
    }
  }

  OcPart copyWithText(String text) => OcPart(
        type: type,
        text: text,
        ordinal: ordinal,
        toolId: toolId,
        toolName: toolName,
        toolStatus: toolStatus,
        toolInput: toolInput,
        toolOutput: toolOutput,
        toolError: toolError,
        toolMetadata: toolMetadata,
        createdMs: createdMs,
      );

  OcPart copyWithTool({
    String? toolName,
    String? toolStatus,
    String? toolInput,
    String? toolOutput,
    String? toolError,
    Map<String, dynamic>? toolMetadata,
  }) =>
      OcPart(
        type: type,
        text: text,
        ordinal: ordinal,
        toolId: toolId,
        toolName: toolName ?? this.toolName,
        toolStatus: toolStatus ?? this.toolStatus,
        toolInput: toolInput ?? this.toolInput,
        toolOutput: toolOutput ?? this.toolOutput,
        toolError: toolError ?? this.toolError,
        toolMetadata: toolMetadata ?? this.toolMetadata,
        createdMs: createdMs,
      );
}

class OcMessage {
  final String id;
  final String type; // 'user' | 'assistant' | ...
  final String? text; // user message body
  final List<OcPart> content;
  final String? agent;
  final ModelRef? model;
  final String? finish;
  final double? cost;
  final TokenUsage tokens;
  final int? createdMs;
  final bool streaming; // true while the assistant is still generating

  const OcMessage({
    required this.id,
    required this.type,
    this.text,
    this.content = const [],
    this.agent,
    this.model,
    this.finish,
    this.cost,
    this.tokens = const TokenUsage(),
    this.createdMs,
    this.streaming = false,
  });

  factory OcMessage.fromJson(Map<String, dynamic> json) {
    final time = json['time'];
    final content = <OcPart>[];
    if (json['content'] is List) {
      for (final c in json['content'] as List) {
        if (c is Map) {
          content.add(OcPart.fromJson(Map<String, dynamic>.from(c)));
        }
      }
    }
    return OcMessage(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      text: json['text'] as String?,
      content: content,
      agent: json['agent'] as String?,
      model: json['model'] is Map
          ? ModelRef.fromJson(Map<String, dynamic>.from(json['model'] as Map))
          : null,
      finish: json['finish'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      tokens: TokenUsage.fromJson(json['tokens'] is Map
          ? Map<String, dynamic>.from(json['tokens'] as Map)
          : null),
      createdMs: time is Map ? (time['created'] as num?)?.toInt() : null,
    );
  }

  OcMessage copyWith({
    List<OcPart>? content,
    String? finish,
    double? cost,
    TokenUsage? tokens,
    bool? streaming,
    String? agent,
    ModelRef? model,
  }) =>
      OcMessage(
        id: id,
        type: type,
        text: text,
        content: content ?? this.content,
        agent: agent ?? this.agent,
        model: model ?? this.model,
        finish: finish ?? this.finish,
        cost: cost ?? this.cost,
        tokens: tokens ?? this.tokens,
        createdMs: createdMs,
        streaming: streaming ?? this.streaming,
      );
}

class PermissionRequest {
  final String id;
  final String sessionID;
  final String action;
  final List<String> resources;
  final String? message;
  final Map<String, dynamic> metadata;

  const PermissionRequest({
    required this.id,
    required this.sessionID,
    required this.action,
    this.resources = const [],
    this.message,
    this.metadata = const {},
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) =>
      PermissionRequest(
        id: json['id'] as String? ?? '',
        sessionID: json['sessionID'] as String? ?? '',
        action: json['action'] as String? ?? '',
        resources: (json['resources'] as List? ?? [])
            .whereType<String>()
            .toList(),
        message: json['message'] as String?,
        metadata: json['metadata'] is Map
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : const {},
      );

  /// Human label of the requested action, e.g. "bash" / "edit".
  String get actionLabel => metadata['title'] as String? ?? action;
}

class OcProject {
  final String id;
  final String canonical;
  final String? vcs;

  const OcProject({
    required this.id,
    required this.canonical,
    this.vcs,
  });

  factory OcProject.fromJson(Map<String, dynamic> json) => OcProject(
        id: json['id'] as String? ?? '',
        canonical: json['canonical'] as String? ?? '',
        vcs: json['vcs'] as String?,
      );

  String get name {
    final parts = canonical.split(RegExp(r'[\\/]'));
    return parts.isEmpty || parts.last.isEmpty ? canonical : parts.last;
  }
}

class AgentInfo {
  final String id;
  final String name;
  final String? description;
  final bool builtIn;

  const AgentInfo({
    required this.id,
    required this.name,
    this.description,
    this.builtIn = true,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) => AgentInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? json['id'] as String? ?? '',
        description: json['description'] as String?,
        builtIn: json['builtIn'] as bool? ?? true,
      );
}

class ServerInfo {
  final String version;
  final List<String> urls;

  const ServerInfo({required this.version, this.urls = const []});

  factory ServerInfo.fromJson(Map<String, dynamic> json) => ServerInfo(
        version: json['version'] as String? ?? '',
        urls: (json['urls'] as List? ?? []).whereType<String>().toList(),
      );
}

/// One decoded SSE event.
class OcEvent {
  final String id;
  final String type;
  final Map<String, dynamic> data;

  const OcEvent({
    required this.id,
    required this.type,
    this.data = const {},
  });

  factory OcEvent.fromJson(Map<String, dynamic> json) => OcEvent(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? '',
        data: json['data'] is Map
            ? Map<String, dynamic>.from(json['data'] as Map)
            : const {},
      );
}
