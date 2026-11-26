import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:labour_app/app/version.dart';

void main() {
  test("the version sent to the owner's dashboard is pubspec's, before the build number (T22b)", () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(appVersion, line.substring('version:'.length).trim().split('+').first);
  });
}
