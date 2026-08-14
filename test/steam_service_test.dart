// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:protognome/services/steam_service.dart';

void main() {
  group('SteamService tool matching', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('steam_service_test_');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('matches tool with exact folder name', () {
      Directory(p.join(tempDir.path, 'GE-Proton11-1')).createSync();

      final service = SteamService();
      expect(
        service.isToolInstalled('GE-Proton11-1', customDir: tempDir.path),
        isTrue,
      );
      expect(
        service.findInstalledToolDir('GE-Proton11-1', customDir: tempDir.path),
        'GE-Proton11-1',
      );
    });

    test('matches tool with architecture suffix (-x86_64)', () {
      Directory(p.join(tempDir.path, 'GE-Proton11-5-x86_64')).createSync();

      final service = SteamService();
      expect(
        service.isToolInstalled('GE-Proton11-5', customDir: tempDir.path),
        isTrue,
      );
      expect(
        service.findInstalledToolDir('GE-Proton11-5', customDir: tempDir.path),
        'GE-Proton11-5-x86_64',
      );
    });

    test('matches tool using internal version file', () {
      final toolDir = Directory(p.join(tempDir.path, 'Custom-Proton-Build'))..createSync();
      File(p.join(toolDir.path, 'version')).writeAsStringSync('1786437966 GE-Proton11-5');

      final service = SteamService();
      expect(
        service.isToolInstalled('GE-Proton11-5', customDir: tempDir.path),
        isTrue,
      );
      expect(
        service.findInstalledToolDir('GE-Proton11-5', customDir: tempDir.path),
        'Custom-Proton-Build',
      );
    });

    test('returns false and null when tool is not installed', () {
      final service = SteamService();
      expect(
        service.isToolInstalled('GE-Proton11-99', customDir: tempDir.path),
        isFalse,
      );
      expect(
        service.findInstalledToolDir('GE-Proton11-99', customDir: tempDir.path),
        isNull,
      );
    });
  });
}
