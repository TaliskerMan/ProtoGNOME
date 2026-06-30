// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as p;

/// Service mapping local application diagnostic logs to standard console output
/// and appending them to ~/.local/state/protognome/app.log.
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;

  File? _logFile;

  LoggerService._internal() {
    _initLogFile();
  }

  /// Initializes the log file configuration under XDG state directories.
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
    } catch (error) {
      print('Failed to initialize local LoggerService: $error');
    }
  }

  /// Appends [message] with a timestamp to the log file and prints to stdout.
  void log(String message) {
    print(message);
    if (_logFile != null) {
      try {
        final ts = DateTime.now().toIso8601String();
        _logFile!.writeAsStringSync('[$ts] $message\n', mode: FileMode.append);
      } catch (error) {
        // Silently fail if log cannot be appended
      }
    }
  }

  /// Formats and logs an [error] with a descriptive [prefix] and optional [stack] trace.
  void logError(String prefix, Object error, [StackTrace? stack]) {
    final msg = '[ERROR] $prefix: $error';
    log(msg);
    if (stack != null) {
      log('Stack trace:\n$stack');
    }
  }
}
