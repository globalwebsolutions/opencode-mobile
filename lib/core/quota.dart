/// OpenCode plan quota: how much of the monthly (and weekly / 5-hour)
/// allowance is left.
///
/// The OpenCode **server API does not expose this** — `/api/provider`,
/// `/api/credential` and the session endpoints only carry local session data.
/// The plan windows live upstream at
/// `GET https://opencode.ai/zen/go/v1/usage`, which answers to the OpenCode
/// console credential the server already holds (reachable via
/// `GET /api/credential`). So: ask the server for the token, then ask the
/// usage API for the numbers.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'l10n.dart';
import 'opencode_client.dart';

/// Where the usage API lives.
const quotaUsageUrl = 'https://opencode.ai/zen/go/v1/usage';

/// One usage window of the plan.
class QuotaWindow {
  /// `rolling` (5 hours), `weekly`, or `monthly`.
  final String id;

  /// Percentage of the allowance already used (0–100).
  final double percent;

  /// When this window resets.
  final DateTime? resetsAt;

  const QuotaWindow({
    required this.id,
    required this.percent,
    this.resetsAt,
  });

  double get remaining => (100 - percent).clamp(0, 100).toDouble();

  /// "5 ساعات" / "5 hours" etc.
  String get label => switch (id) {
        'rolling' => L.tr('آخر 5 ساعات', 'Last 5 hours'),
        'weekly' => L.tr('الأسبوع', 'This week'),
        'monthly' => L.tr('الشهر', 'This month'),
        _ => id,
      };
}

/// The plan's usage windows, newest data first (rolling → monthly).
class QuotaSnapshot {
  final List<QuotaWindow> windows;

  const QuotaSnapshot(this.windows);

  bool get isEmpty => windows.isEmpty;

  /// The monthly window, which is what most people mean by "the quota".
  QuotaWindow? get monthly {
    for (final w in windows) {
      if (w.id == 'monthly') return w;
    }
    return null;
  }

  /// Parses `{"usage":{"rolling":{"percent":0,"resetsAt":"…"}, …}}`.
  factory QuotaSnapshot.fromUsageJson(Map<String, dynamic> json) {
    final usage = json['usage'];
    if (usage is! Map) return const QuotaSnapshot([]);
    const order = ['rolling', 'weekly', 'monthly'];
    final windows = <QuotaWindow>[];
    for (final id in order) {
      final raw = usage[id];
      if (raw is! Map) continue;
      final percent = (raw['percent'] as num?)?.toDouble();
      if (percent == null) continue;
      final resets = raw['resetsAt'] as String?;
      windows.add(QuotaWindow(
        id: id,
        percent: percent,
        resetsAt: resets == null ? null : DateTime.tryParse(resets)?.toLocal(),
      ));
    }
    return QuotaSnapshot(windows);
  }
}

/// Raised when the quota can't be read (no credential, expired token, …).
class QuotaException implements Exception {
  final String message;
  const QuotaException(this.message);

  @override
  String toString() => message;
}

/// Picks the console token out of `GET /api/credential`.
///
/// The server holds one credential per signed-in account; the active OpenCode
/// one is the token the usage API accepts.
String? pickConsoleToken(List<Map<String, dynamic>> credentials) {
  String? fallback;
  for (final cred in credentials) {
    if (cred['integrationID'] != 'opencode') continue;
    final value = cred['value'];
    if (value is! Map) continue;
    final token = value['access'] as String?;
    if (token == null || token.isEmpty) continue;
    if (cred['active'] == true) return token;
    fallback ??= token;
  }
  return fallback;
}

/// Reads the plan quota. Throws [QuotaException] with a message that can be
/// shown to the user.
Future<QuotaSnapshot> fetchQuota(
  OpenCodeClient client, {
  http.Client? httpClient,
}) async {
  final List<Map<String, dynamic>> credentials;
  try {
    credentials = await client.listCredentials();
  } catch (e) {
    throw QuotaException(
        L.tr('مقدرناش نقرا بيانات الاعتماد من السيرفر', 'Could not read credentials from the server'));
  }

  final token = pickConsoleToken(credentials);
  if (token == null) {
    throw QuotaException(L.tr(
        'مفيش حساب OpenCode متسجل على السيرفر — اعمل تسجيل دخول من الكمبيوتر',
        'No OpenCode account is signed in on the server — sign in from your computer'));
  }

  final own = httpClient == null;
  final http_ = httpClient ?? http.Client();
  try {
    final res = await http_.get(
      Uri.parse(quotaUsageUrl),
      headers: {'Authorization': 'Bearer $token', 'accept': 'application/json'},
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode == 403) {
      // EntitlementError: the credential is fine, there is just no Go plan on
      // this account — e.g. pay-as-you-go Zen, or your own provider keys.
      throw QuotaException(L.tr(
          'الحساب ده مفيش عليه خطة Go — مفيش كوتة شهرية تتعرض',
          'No Go plan on this account — nothing to meter'));
    }
    if (res.statusCode == 401) {
      throw QuotaException(L.tr(
          'التوكن انتهى — سجّل دخول تاني من على الكمبيوتر',
          'The sign-in expired — sign in again from your computer'));
    }
    if (res.statusCode != 200) {
      throw QuotaException(L.tr('رد غير متوقع (${res.statusCode})',
          'Unexpected response (${res.statusCode})'));
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw QuotaException(L.tr('رد غير مفهوم من السيرفر', 'Unreadable server response'));
    }
    final snapshot = QuotaSnapshot.fromUsageJson(decoded);
    if (snapshot.isEmpty) {
      throw QuotaException(L.tr(
          'الحساب ده مفيش عليه خطة Go — الكوتة مش متاحة',
          'This account has no Go plan — no quota to show'));
    }
    return snapshot;
  } on QuotaException {
    rethrow;
  } catch (e) {
    throw QuotaException(L.tr('تعذر الاتصال بسيرفر الكوتة: $e',
        'Could not reach the quota service: $e'));
  } finally {
    if (own) http_.close();
  }
}

/// "3 أيام" / "5 ساعات" — a short countdown to [when], empty when unknown.
String quotaResetLabel(DateTime? when) {
  if (when == null) return '';
  final diff = when.difference(DateTime.now());
  if (diff.isNegative) return L.tr('الآن', 'now');
  if (diff.inDays >= 1) {
    final d = diff.inDays;
    return L.tr('$d يوم', d == 1 ? '1 day' : '$d days');
  }
  if (diff.inHours >= 1) {
    final h = diff.inHours;
    return L.tr('$h ساعة', h == 1 ? '1 hour' : '$h hours');
  }
  final m = diff.inMinutes.clamp(1, 59);
  return L.tr('$m دقيقة', m == 1 ? '1 minute' : '$m minutes');
}
