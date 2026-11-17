// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

// Prints mirror log lines to stdout so they show in a terminal and in
// `flutter run`; the log file is the record.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:path/path.dart' as p;

/// Service mapping local application diagnostic logs to standard console output
/// and appending them to ~/.local/state/protognome/app.log.
class LoggerService {
  /// Returns the shared LoggerService instance.
  factory LoggerService() => _instance;

  LoggerService._internal() {
    _initLogFile();
  }
  static final LoggerService _instance = LoggerService._internal();

  File? _logFile;
  static const int _maxLogBytes = 5 * 1024 * 1024;

  /// Sanitizes a log [message] by replacing CR/LF control characters.
  static String sanitize(String message) {
    return message.replaceAll('\r', ' ').replaceAll('\n', ' ');
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
      if (!_logFile!.existsSync()) {
        _logFile!.createSync(recursive: true);
      }
      if (!Platform.isWindows) {
        Process.runSync('chmod', ['600', _logFile!.path]);
      }
      log('--- ProtoGNOME Session Started ---');
    } on Object catch (error) {
      print('Failed to initialize local LoggerService: $error');
    }
  }

  /// Appends [message] with a timestamp to the log file and prints to stdout.
  void log(String message) {
    final safeMessage = sanitize(message);
    print(safeMessage);
    if (_logFile != null) {
      try {
        if (_logFile!.existsSync() && _logFile!.lengthSync() > _maxLogBytes) {
          _logFile!.renameSync('${_logFile!.path}.1');
        }
        final ts = DateTime.now().toIso8601String();
        _logFile!.writeAsStringSync(
          '[$ts] $safeMessage\n',
          mode: FileMode.append,
        );
      } on Object {
        // Silently fail if log cannot be appended
      }
    }
  }

  /// Formats and logs an [error] with a descriptive [prefix] and optional
  /// [stack] trace.
  void logError(String prefix, Object error, [StackTrace? stack]) {
    final msg = '[ERROR] $prefix: $error';
    log(msg);
    if (stack != null) {
      log('Stack trace:\n$stack');
    }
  }
}
