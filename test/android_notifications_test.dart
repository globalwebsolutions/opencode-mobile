import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Background notifications broke twice for reasons that no Dart test could
/// see, so guard the platform wiring itself:
///
/// 1. `flutter_foreground_task` does not ship the `<service>` entry in its own
///    manifest — without it the service can never start, and the plugin
///    reports that as a result object instead of throwing.
/// 2. The watcher isolate can only reach the UI after
///    `initCommunicationPort()` has been called in `main()`.
void main() {
  test('AndroidManifest declares the foreground service and its type', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(
      manifest,
      contains(
        'com.pravera.flutter_foreground_task.service.ForegroundService',
      ),
      reason: 'the plugin does not declare its own service',
    );
    expect(manifest, contains('android:foregroundServiceType='),
        reason: 'required from Android 14 on');
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'));
  });

  test('main() opens the background communication port', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('initCommunicationPort()'));
  });
}
