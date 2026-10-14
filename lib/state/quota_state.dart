/// Shared quota + spend state.
///
/// Kept in one place because three surfaces show it (the home chip, the
/// connection sheet, and Settings) and each should not hit the network on its
/// own.
library;

import 'package:flutter/foundation.dart';

import '../core/l10n.dart';
import '../core/quota.dart';
import '../core/usage.dart';
import 'app_state.dart';

class QuotaState extends ChangeNotifier {
  QuotaState(this.app) {
    app.addListener(_onAppChanged);
  }

  final AppState app;

  QuotaSnapshot? quota;
  UsageSummary? usage;

  /// Why the quota is missing, if it is.
  String? quotaError;

  /// Why the spend summary is missing, if it is.
  String? usageError;

  bool loading = false;
  DateTime? loadedAt;

  bool _inFlight = false;
  Object? _lastClient;

  /// The monthly window, i.e. "the quota" for most people.
  QuotaWindow? get monthly => quota?.monthly;

  /// True when there is something worth showing without opening Settings.
  bool get hasQuota => monthly != null;

  Future<void> refresh() async {
    if (_inFlight) return;
    final client = app.client;
    if (client == null) {
      reset();
      return;
    }

    _inFlight = true;
    loading = true;
    notifyListeners();

    try {
      quota = await fetchQuota(client);
      quotaError = null;
    } on QuotaException catch (e) {
      quota = null;
      quotaError = e.message;
    } catch (e) {
      quota = null;
      quotaError = '$e';
    }

    try {
      usage = await client.getUsageSummary();
      usageError = null;
    } catch (e) {
      usage = null;
      usageError = L.tr('مقدرناش نقرا الاستهلاك', 'Could not read usage');
    }

    _inFlight = false;
    loading = false;
    loadedAt = DateTime.now();
    notifyListeners();
  }

  void reset() {
    quota = null;
    usage = null;
    quotaError = null;
    usageError = null;
    loading = false;
    loadedAt = null;
    notifyListeners();
  }

  /// Drop stale numbers when the server (or demo mode) changes.
  void _onAppChanged() {
    if (!identical(app.client, _lastClient)) {
      _lastClient = app.client;
      if (quota != null || usage != null || quotaError != null) {
        quota = null;
        usage = null;
        quotaError = null;
        usageError = null;
        loadedAt = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }
}
