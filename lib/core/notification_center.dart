/// Main-isolate side of notifications: initializes local notifications,
/// subscribes to data from the background watcher, and fires alerts.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:opencode_mobile/core/l10n.dart';
import 'package:opencode_mobile/core/notification_watcher.dart';

/// True when the notification system finished initializing successfully.
/// The settings UI uses this to show a helpful message instead of crashing.
bool get notificationSystemReady => _ready;
bool _ready = false;

/// Optional failure reason, for surfacing to the user in Settings.
String? get notificationSystemError => _initError;
String? _initError;

/// Retries initialization a few times: the first attempt can land before the
/// Android Activity/Context is attached, and flutter_local_notifications then
/// throws a NullPointerException inside `initialize()`.
Future<void> retryInitializeNotificationSystem({int attempts = 3}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await initializeNotificationSystem();
    if (_ready) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  debugPrint('notification init gave up: $_initError');
}

bool _dataCallbackRegistered = false;

/// Initializes the notification system once. Never throws: failures are
/// recorded in [notificationSystemError] so the app still launches and the
/// user can retry. Safe to call many times.
Future<void> initializeNotificationSystem() async {
  if (_ready) return;
  // 1) Open the channel the watcher isolate sends its events over. This has
  //    nothing to do with the local-notifications plugin, so it must not be
  //    skipped just because that plugin failed to initialize.
  try {
    // Prepare the foreground service options (doesn't start the service).
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'opencode_foreground',
        channelName: L.tr('OpenCode خدمة الخلفية', 'OpenCode background service'),
        channelDescription: L.tr(
            'يظل متواصلًا بالسيرفر في الخلفية', 'Keeps the server connection alive'),
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        // The watcher holds a long-lived SSE connection: without the Wi-Fi
        // lock Android dozes the radio and the stream dies while the screen
        // is off.
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: true,
        // Keep watching after the user swipes the task away.
        stopWithTask: false,
      ),
    );
    // Subscribe to messages from the background isolate. Guarded so a retry
    // can't register the same callback twice (which would double every alert).
    if (!_dataCallbackRegistered) {
      FlutterForegroundTask.addTaskDataCallback(_onDataFromWatcher);
      _dataCallbackRegistered = true;
    }
  } catch (e) {
    // Never let notification setup break the app — record it and move on.
    debugPrint('foreground task init failed: $e');
    _initError = '$e';
  }

  // 2) Local notifications, used for the alert-style messages.
  try {
    const androidSettings =
        AndroidInitializationSettings('ic_stat_ic_notification');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('notification tapped payload=${response.payload}');
      },
    );

    // Create the alert channel (high importance so permission requests pop).
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
          AndroidNotificationChannel(
        'opencode_alerts',
        L.tr('إشعارات OpenCode', 'OpenCode notifications'),
        description: L.tr('طلب صلاحية أو انتهاء تنفيذ', 'Permission requests and finished runs'),
        importance: Importance.high,
      ));
    }

    _initError = null;
    _ready = true;
  } catch (e) {
    debugPrint('local notifications init failed: $e');
    _initError = '$e';
  }
}

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

void _onDataFromWatcher(Object? data) {
  if (data is! Map) return;
  final type = data['type'] as String?;
  switch (type) {
    case 'permission':
      _fireAlert(
        id: (data['sessionID'] as String? ?? '').hashCode ^
            (data['action'] as String? ?? '').hashCode,
        title: L.tr(
          'طلب صلاحية: ${data['action'] ?? ''}',
          'Permission request: ${data['action'] ?? ''}',
        ),
        body: '${data['sessionTitle'] ?? ''} — ${data['message'] ?? ''}',
      );
      break;
    case 'done':
      _fireAlert(
        id: 'done_${data['sessionID']}'.hashCode,
        title: (data['outcome'] as String? ?? '') +
            L.tr(' في ', ' in ') +
            (data['sessionTitle'] as String? ?? ''),
        body: L.tr('اضغط لفتح التطبيق', 'Tap to open the app'),
      );
      break;
  }
}

Future<void> _fireAlert({
  required int id,
  required String title,
  required String body,
}) async {
  // Don't interrupt the user while they're looking at the app.
  if (await FlutterForegroundTask.isAppOnForeground) return;
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      'opencode_alerts',
      L.tr('إشعارات OpenCode', 'OpenCode notifications'),
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    ),
  );
  await _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
  );
}

/// Starts the foreground service with the given visible label.
Future<void> startForegroundService(String persistentText) async {
  // Android 13+ requires explicit notification permission. A cancelled or
  // denied dialog must not crash the app — surface a clear error instead.
  try {
    final permission =
        await FlutterForegroundTask.requestNotificationPermission();
    if (permission != NotificationPermission.granted) {
      throw Exception(L.tr('لم يتم منح إذن الإشعارات — فعّله من إعدادات النظام', 'Notification permission was not granted — enable it in system settings'));
    }
  } catch (e) {
    final s = '$e';
    if (s.contains('PermissionRequestCancelled') ||
        s.contains('denied') ||
        s.toLowerCase().contains('permission') ||
        s.contains('إذن')) {
      throw Exception(L.tr('لم يتم منح إذن الإشعارات — جرّب تاني ووافق على النافذة', 'Notification permission not granted — try again and accept the dialog'));
    }
    rethrow;
  }
  // startService never throws: it returns a failure result instead. Ignoring
  // it used to report success even when nothing started, which is exactly how
  // the "switch says on but no notifications arrive" bug looked.
  final result = await FlutterForegroundTask.startService(
    notificationTitle: 'OpenCode',
    notificationText: persistentText,
    callback: startNotificationService,
  );
  if (result is ServiceRequestFailure) {
    throw Exception('${result.error}');
  }
}

Future<void> stopForegroundService() async {
  final result = await FlutterForegroundTask.stopService();
  if (result is ServiceRequestFailure) {
    throw Exception('${result.error}');
  }
}

Future<bool> get isForegroundServiceRunning =>
    FlutterForegroundTask.isRunningService;

/// Convenience: updates the foreground persistent notification text.
Future<void> updatePersistentNotificationText(String text) async {
  final result = await FlutterForegroundTask.updateService(
    notificationText: text,
  );
  if (result is ServiceRequestFailure) {
    throw Exception('${result.error}');
  }
}
