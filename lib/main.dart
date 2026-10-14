import 'package:flutter/material.dart';

import 'app.dart';
import 'core/notification_center.dart';

void main() {
  runApp(const OpenCodeMobileApp());
  // Initialize notifications OFF the critical startup path so that a plugin
  // or icon resource failure can never leave the user on a black screen.
  // The function swallows its own errors and reports them internally.
  initializeNotificationSystem();
}
