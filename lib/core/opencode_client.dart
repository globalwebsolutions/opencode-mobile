/// HTTP + SSE client for the OpenCode V2 server API.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Thrown for non-2xx API responses.
class OpenCodeApiException implements Exception {
  final int statusCode;
  final String message;

  const OpenCodeApiException(this.statusCode, this.message);

  bool get unauthorized => statusCode == 401;

  @override
  String toString() => 'OpenCodeApiException($statusCode): $message';
}

/// Status of the live SSE event connection.
enum SseStatus { connecting, connected, disconnected }

/// REST + SSE client for one OpenCode server, authenticated with a pairing
/// token via HTTP Basic auth (`opencode:<token>`).
class OpenCodeClient {
  final String baseUrl;
  final String token;
  final http.Client _http;

  OpenCodeClient({
    required this.baseUrl,
    required this.token,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  String get _authorization =>
      'Basic ${base64Encode(utf8.encode('opencode:$token'))}';

  Map<String, String> get _headers => {
        'authorization': _authorization,
        'accept': 'application/json',
      };

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  // ---------------------------------------------------------------------------
  // Pairing
  // ---------------------------------------------------------------------------

  /// Extracts the server base URL from a pairing link, e.g.
  /// `http://192.168.1.5:49374/auth/connect/abc` -> `http://192.168.1.5:49374`.
  static String baseUrlFromLink(String link) {
    final uri = Uri.parse(link.trim());
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('اللينك لازم يبدأ بـ http:// أو https://');
    }
    if (!uri.path.startsWith('/auth/connect/')) {
      throw const FormatException(
          'ده مش لينك pairing صحيح — لازم يحتوي /auth/connect/');
    }
    return '${uri.scheme}://${uri.host}:${uri.port}';
  }

  /// Redeems a one-time pairing link (as printed by `opencode pair`) into an
  /// auth token. Works without prior authentication.
  static Future<String> redeemPairingLink(String link) async {
    final uri = Uri.parse(link.trim());
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('اللينك لازم يبدأ بـ http:// أو https://');
    }
    if (!uri.path.startsWith('/auth/connect/')) {
      throw const FormatException(
          'ده مش لينك pairing صحيح — لازم يحتوي /auth/connect/');
    }
    final client = http.Client();
    try {
      final res = await client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw OpenCodeApiException(
            res.statusCode, _errorMessage(res) ?? 'فشل الاتصال بالسيرفر');
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['token'] is String) {
        return body['token'] as String;
      }
      throw FormatException('رد غير متوقع من السيرفر: $body');
    } finally {
      client.close();
    }
  }

  static String? _errorMessage(http.Response res) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // REST endpoints
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _getJson(String path,
      [Map<String, String>? query]) async {
    final res = await _http
        .get(_uri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw OpenCodeApiException(
          res.statusCode, _errorMessage(res) ?? res.reasonPhrase ?? 'خطأ');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _sendJson(
      String method, String path, Map<String, dynamic>? body) async {
    final request = http.Request(method, _uri(path));
    request.headers.addAll(_headers);
    request.headers['content-type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _http.send(request).timeout(const Duration(seconds: 30));
    final res =
        await http.Response.fromStream(streamed).timeout(const Duration(seconds: 60));
    if (res.statusCode >= 400) {
      throw OpenCodeApiException(
          res.statusCode, _errorMessage(res) ?? res.reasonPhrase ?? 'خطأ');
    }
    if (res.body.isEmpty) return {};
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<ServerInfo> getInfo() async =>
      ServerInfo.fromJson(await _getJson('/api/info'));

  Future<List<OcSession>> listSessions({int limit = 100}) async {
    final json = await _getJson('/api/session', {
      'limit': '$limit',
      'order': 'desc',
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => OcSession.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Fetches a session's message history. The server caps `limit` at 200.
  Future<List<OcMessage>> getMessages(String sessionID, {int limit = 200}) async {
    final json = await _getJson('/api/session/$sessionID/message', {
      'limit': '$limit',
      'order': 'asc',
    });
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => OcMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<OcSession> createSession({required String directory, String? title}) async {
    final json = await _sendJson('POST', '/api/session', {
      'location': {'directory': directory},
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
    });
    final data = json['data'];
    if (data is Map) {
      return OcSession.fromJson(Map<String, dynamic>.from(data));
    }
    throw const OpenCodeApiException(500, 'فشل إنشاء الجلسة');
  }

  Future<void> renameSession(String sessionID, String title) async =>
      _sendJson('PATCH', '/api/session/$sessionID', {'title': title});

  Future<void> deleteSession(String sessionID) async =>
      _sendJson('DELETE', '/api/session/$sessionID', null);

  /// Sends a user message to the session.
  Future<void> prompt(String sessionID, String text) async =>
      _sendJson('POST', '/api/session/$sessionID/prompt', {'text': text});

  Future<void> interrupt(String sessionID) async =>
      _sendJson('POST', '/api/session/$sessionID/interrupt', null);

  Future<List<OcProject>> listProjects() async {
    final res = await _http
        .get(_uri('/api/project'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw OpenCodeApiException(
          res.statusCode, _errorMessage(res) ?? 'فشل تحميل المشاريع');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => OcProject.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<AgentInfo>> listAgents() async {
    final json = await _getJson('/api/agent');
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => AgentInfo.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<PermissionRequest>> listSessionPermissions(String sessionID) async {
    final json = await _getJson('/api/session/$sessionID/permission');
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => PermissionRequest.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<PermissionRequest>> listPermissionRequests() async {
    final json = await _getJson('/api/permission/request');
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => PermissionRequest.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> replyPermission(
      String sessionID, String requestID, String decision) async {
    await _sendJson(
      'POST',
      '/api/session/$sessionID/permission/$requestID/reply',
      {'decision': decision},
    );
  }

  void close() => _http.close();

  // ---------------------------------------------------------------------------
  // SSE event stream
  // ---------------------------------------------------------------------------

  /// Streams live events over SSE with automatic reconnection and backoff.
  ///
  /// The stream is live-only (no replay): after a reconnect, callers should
  /// refresh their state. Cancelling the subscription stops reconnection.
  Stream<OcEvent> events({
    void Function(SseStatus status)? onStatus,
    Duration maxBackoff = const Duration(seconds: 30),
  }) async* {
    var backoff = const Duration(seconds: 1);
    while (true) {
      HttpClient? client;
      StreamSubscription<String>? lineSub;
      try {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final request =
            await client.getUrl(Uri.parse('$baseUrl/api/event'));
        request.headers.set(HttpHeaders.authorizationHeader, _authorization);
        request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
        request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        final response = await request.close();

        if (response.statusCode != 200) {
          throw OpenCodeApiException(response.statusCode,
              'فشل فتح قناة الأحداث (HTTP ${response.statusCode})');
        }
        onStatus?.call(SseStatus.connected);
        backoff = const Duration(seconds: 1);

        final lines = response.transform(utf8.decoder).transform(const LineSplitter());
        final events = StreamController<OcEvent>();
        var buffer = StringBuffer();

        lineSub = lines.listen(
          (line) {
            if (line.startsWith('data:')) {
              if (buffer.isNotEmpty) buffer.write('\n');
              buffer.write(line.substring(5).trim());
            } else if (line.isEmpty) {
              if (buffer.isNotEmpty) {
                final payload = buffer.toString();
                buffer = StringBuffer();
                try {
                  final decoded = jsonDecode(payload);
                  if (decoded is Map<String, dynamic> && !events.isClosed) {
                    events.add(OcEvent.fromJson(decoded));
                  }
                } catch (_) {
                  // Ignore malformed frames.
                }
              }
            }
            // Comment lines (": heartbeat") and other fields are ignored.
          },
          onDone: () {
            if (!events.isClosed) {
              events.addError(
                  const OpenCodeApiException(503, 'انقطعت قناة الأحداث'));
              events.close();
            }
          },
          onError: (Object e) {
            if (!events.isClosed) {
              events.addError(e);
              events.close();
            }
          },
          cancelOnError: true,
        );

        try {
          await for (final event in events.stream) {
            yield event;
          }
        } finally {
          await events.close();
          await lineSub.cancel();
          client.close(force: true);
        }
        // The server closed the stream without an error: reconnect below.
      } catch (_) {
        // Fall through to reconnect with backoff.
      } finally {
        await lineSub?.cancel();
        client?.close(force: true);
      }
      onStatus?.call(SseStatus.disconnected);
      await Future<void>.delayed(backoff);
      backoff = backoff * 2;
      if (backoff > maxBackoff) backoff = maxBackoff;
    }
  }
}
