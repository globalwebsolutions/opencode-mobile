import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/notification_center.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the notification system (lightweight — prepares options,
  // does not start the service).
  await initializeNotificationSystem();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const OpenCodeMobileApp());
}
