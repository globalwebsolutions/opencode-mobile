/// Main-isolate side of notifications: initializes local notifications,
/// subscribes to data from the background watcher, and fires alerts.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:opencode_mobile/core/notification_watcher.dart';

/// True when the notification system finished initializing successfully.
/// The settings UI uses this to show a helpful message instead of crashing.
bool get notificationSystemReady => _ready;
bool _ready = false;

/// Optional failure reason, for surfacing to the user in Settings.
String? get notificationSystemError => _initError;
String? _initError;

/// Initializes the notification system once. Never throws: failures are
/// recorded in [notificationSystemError] so the app still launches and the
/// user can retry. Safe to call many times.
Future<void> initializeNotificationSystem() async {
  if (_ready) return;
  try {
    // Prepare the foreground service options (doesn't start the service).
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'opencode_foreground',
        channelName: 'OpenCode خدمة الخلفية',
        channelDescription: 'يظل متواصلًا بالسيرفر في الخلفية',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
      ),
    );

    // Initialize local notifications for the alert-style messages.
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
          const AndroidNotificationChannel(
        'opencode_alerts',
        'إشعارات OpenCode',
        description: 'طلب صلاحية أو انتهاء تنفيذ',
        importance: Importance.high,
      ));
    }

    // Subscribe to messages from the background isolate.
    FlutterForegroundTask.addTaskDataCallback(_onDataFromWatcher);

    _initError = null;
    _ready = true;
  } catch (e) {
    // Never let notification setup break the app — record it and move on.
    debugPrint('notification init failed: $e');
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
        title: 'طلب صلاحية: ${data['action']}',
        body: '${data['sessionTitle']} — ${data['message'] ?? ''}',
      );
      break;
    case 'done':
      _fireAlert(
        id: 'done_${data['sessionID']}'.hashCode,
        title: '${data['outcome']} في ${data['sessionTitle']}',
        body: 'اضغط لفتح التطبيق',
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
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'opencode_alerts',
      'إشعارات OpenCode',
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
      throw Exception('لم يتم منح إذن الإشعارات — فعّله من إعدادات النظام');
    }
  } catch (e) {
    final s = '$e';
    if (s.contains('PermissionRequestCancelled') ||
        s.contains('denied') ||
        s.contains('إذن')) {
      throw Exception('لم يتم منح إذن الإشعارات — جرّب تاني ووافق على النافذة');
    }
    rethrow;
  }
  await FlutterForegroundTask.startService(
    notificationTitle: 'OpenCode',
    notificationText: persistentText,
    callback: startNotificationService,
  );
}

Future<void> stopForegroundService() async {
  await FlutterForegroundTask.stopService();
}

Future<bool> get isForegroundServiceRunning =>
    FlutterForegroundTask.isRunningService;

/// Convenience: updates the foreground persistent notification text.
Future<void> updatePersistentNotificationText(String text) async {
  await FlutterForegroundTask.updateService(notificationText: text);
}
