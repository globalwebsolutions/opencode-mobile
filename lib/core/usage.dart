/// Local usage summary: what the server recorded for this machine — cost and
/// tokens per period (GET /api/experimental/session/stats).
///
/// This is *spend*, not the plan quota: it answers "what have I used", while
/// `quota.dart` answers "how much of my allowance is left".
library;

/// One period of usage as the server reports it.
class UsageSummary {
  final int sessions;
  final int prompts;
  final int steps;

  final int inputTokens;
  final int outputTokens;
  final int reasoningTokens;

  /// Total cost in USD as recorded by the server.
  final double cost;

  /// The period the server aggregated.
  final DateTime? from;
  final DateTime? to;

  const UsageSummary({
    this.sessions = 0,
    this.prompts = 0,
    this.steps = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.reasoningTokens = 0,
    this.cost = 0,
    this.from,
    this.to,
  });

  int get totalTokens => inputTokens + outputTokens + reasoningTokens;

  /// Length of the reported period in days (1 when the server sends a single
  /// day, 0 when it sends no range at all).
  int get periodDays {
    final a = from;
    final b = to;
    if (a == null || b == null) return 0;
    final days = b.difference(a).inDays;
    return days < 1 ? 1 : days;
  }

  bool get isEmpty => sessions == 0 && totalTokens == 0 && cost == 0;

  /// Parses the `{"data":{…}}` payload (and tolerates a bare object).
  factory UsageSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final map = data is Map ? Map<String, dynamic>.from(data) : json;

    final tokens = map['tokens'] is Map
        ? Map<String, dynamic>.from(map['tokens'] as Map)
        : const <String, dynamic>{};
    final range = map['range'] is Map
        ? Map<String, dynamic>.from(map['range'] as Map)
        : const <String, dynamic>{};

    DateTime? time(Object? ms) => ms is num
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
        : null;

    return UsageSummary(
      sessions: (map['sessions'] as num?)?.toInt() ?? 0,
      prompts: (map['prompts'] as num?)?.toInt() ?? 0,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      inputTokens: (tokens['input'] as num?)?.toInt() ?? 0,
      outputTokens: (tokens['output'] as num?)?.toInt() ?? 0,
      reasoningTokens: (tokens['reasoning'] as num?)?.toInt() ?? 0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      from: time(range['from']),
      to: time(range['to']),
    );
  }
}
