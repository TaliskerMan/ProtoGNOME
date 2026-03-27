// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:path/path.dart' as p;

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;

  File? _logFile;

  LoggerService._internal() {
    _initLogFile();
  }

  void _initLogFile() {
    try {
      final stateHome = Platform.environment['XDG_STATE_HOME'] ??
          p.join(Platform.environment['HOME'] ?? '', '.local', 'state');
      
      final logDir = Directory(p.join(stateHome, 'protognome'));
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      
      _logFile = File(p.join(logDir.path, 'app.log'));
      log('--- ProtoGNOME Session Started ---');
    } catch (e) {
      print('Failed to initialize local LoggerService: $e');
    }
  }

  void log(String message) {
    print(message);
    if (_logFile != null) {
      try {
        final ts = DateTime.now().toIso8601String();
        _logFile!.writeAsStringSync('[$ts] $message\n', mode: FileMode.append);
      } catch (e) {
        // Silently fail if log cannot be appended
      }
    }
  }

  void logError(String prefix, Object error, [StackTrace? stack]) {
    final msg = '[ERROR] $prefix: $error';
    log(msg);
    if (stack != null) {
      log('Stack trace:\n$stack');
    }
  }
}
