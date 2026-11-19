import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The debug and profile manifests add INTERNET for the Flutter tool, so a debug APK reaches the cloud and hides a
  // release APK that cannot: no login, no licence, no cloud copy (AUTH-01, BILL-05, DATA-06).
  test('a release build may use the internet', () {
    final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(main, contains('<uses-permission android:name="android.permission.INTERNET"'));
  });
}
