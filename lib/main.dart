import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app.dart';
import 'core/notification_center.dart';

void main() {
  // Opens the port the background watcher isolate sends its events over.
  // Without this, `sendDataToMain` from the service never reaches the UI —
  // i.e. no permission/“finished” alerts, even with the service running.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const OpenCodeMobileApp());

  // Initialize notifications OFF the critical startup path so that a plugin
  // or icon resource failure can never leave the user on a black screen.
  // It runs after the first frame (the Android Context must exist, otherwise
  // flutter_local_notifications throws), and retries a few times; it swallows
  // its own errors and reports them internally.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(retryInitializeNotificationSystem());
  });
}
