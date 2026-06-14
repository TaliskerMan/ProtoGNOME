// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/steam_game.dart';
import 'vdf_parser.dart';
import 'logger_service.dart';

/// Handles Steam config file scanning, VDF parsing, and compatibility tool lookup.
/// Ports key utilities of ProtonUp-Qt's steamutil.py to Dart/Flutter.
class SteamService {
  static final SteamService _instance = SteamService._internal();
  factory SteamService() => _instance;
  SteamService._internal();

  static const List<String> _possibleSteamRoots = [
    '.local/share/Steam',
    '.steam/root',
    '.steam/steam',
    '.steam/debian-installation',
  ];

  /// Returns the absolute path of the detected Steam root directory, or null if not found.
  String? getSteamRoot() {
    final home = Platform.environment['HOME'] ?? '';
    final seen = <String>{};
    for (final rel in _possibleSteamRoots) {
      final path = p.normalize(p.join(home, rel));
      final resolved = Directory(path).existsSync()
          ? File(path).resolveSymbolicLinksSync()
          : path;
      if (seen.add(resolved) && Directory(resolved).existsSync()) {
        return resolved;
      }
    }
    return null;
  }

  /// Returns the directory path where Steam's configuration files reside (e.g. config.vdf).
  String? getSteamConfigDir() {
    final root = getSteamRoot();
    if (root == null) return null;
    return p.join(root, 'config');
  }

  /// Returns the path to the Steam compatibilitytools.d folder containing custom wrappers.
  String? getCompatToolsDir() {
    final root = getSteamRoot();
    if (root == null) return null;
    return p.join(root, 'compatibilitytools.d');
  }

  /// Checks if both config.vdf and libraryfolders.vdf exist under the config directory.
  bool isValidSteamInstall() {
    final cfgDir = getSteamConfigDir();
    if (cfgDir == null) return false;
    return File(p.join(cfgDir, 'config.vdf')).existsSync() &&
        File(p.join(cfgDir, 'libraryfolders.vdf')).existsSync();
  }

  /// Searches the OS proc directory to verify if a steam executable process is currently running.
  bool isSteamRunning() {
    try {
      final procDir = Directory('/proc');
      for (final entry in procDir.listSync()) {
        if (entry is Directory) {
          final exeLink = File(p.join(entry.path, 'exe'));
          if (exeLink.existsSync()) {
            try {
              final target = exeLink.resolveSymbolicLinksSync();
              if (target.toLowerCase().contains('steam')) return true;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Retrieves the internal CompatToolMapping block parsed from config.vdf.
  Map<String, dynamic>? _getCompatToolMapping() {
    final cfgDir = getSteamConfigDir();
    if (cfgDir == null) return null;
    final configFile = File(p.join(cfgDir, 'config.vdf'));
    if (!configFile.existsSync()) return null;

    try {
      final content = configFile.readAsStringSync();
      final parsed = VdfParser.parse(content);
      final store = parsed['InstallConfigStore'] as Map<String, dynamic>?;
      if (store == null) return null;
      final software = store['Software'] as Map<String, dynamic>?;
      if (software == null) return null;
      final valve = (software['Valve'] ?? software['valve']) as Map<String, dynamic>?;
      if (valve == null) return null;
      return (valve['Steam'] as Map<String, dynamic>?)?['CompatToolMapping']
          as Map<String, dynamic>?;
    } catch (e) {
      LoggerService().logError('Reading config.vdf', e);
      return null;
    }
  }

  /// Scans libraryfolders.vdf and manifest files to compile a list of all locally installed [SteamGame]s.
  Future<List<SteamGame>> getInstalledGames() async {
    final cfgDir = getSteamConfigDir();
    if (cfgDir == null) return [];

    final libraryFile = File(p.join(cfgDir, 'libraryfolders.vdf'));
    if (!libraryFile.existsSync()) return [];

    final games = <SteamGame>[];

    try {
      final libContent = libraryFile.readAsStringSync();
      final libVdf = VdfParser.parse(libContent);
      final compatMap = _getCompatToolMapping() ?? {};

      final libraryFolders = libVdf['libraryfolders'] as Map<String, dynamic>?;
      if (libraryFolders == null) return [];

      for (final entry in libraryFolders.entries) {
        final folderData = entry.value;
        if (folderData is! Map) continue;
        final apps = folderData['apps'] as Map<String, dynamic>?;
        if (apps == null) continue;
        final folderPath = folderData['path'] as String? ?? '';

        for (final appId in apps.keys) {
          final steamappsPath = p.join(folderPath, 'steamapps');
          final manifestPath = p.join(steamappsPath, 'appmanifest_$appId.acf');

          // Check if the game is actually installed
          if (!File(manifestPath).existsSync()) continue;

          String gameName = appId;
          try {
            final manifestContent = File(manifestPath).readAsStringSync();
            final manifest = VdfParser.parse(manifestContent);
            final appState = manifest['AppState'] as Map<String, dynamic>?;
            final installDir = appState?['installdir'] as String? ?? '';
            gameName = appState?['name'] as String? ?? appId;
            // Skip if not installed to common
            if (!Directory(p.join(steamappsPath, 'common', installDir)).existsSync()) {
              continue;
            }
          } catch (_) {}

          final ctMapping = compatMap[appId] as Map<String, dynamic>?;
          final compatTool = ctMapping?['name'] as String?;

          games.add(SteamGame(
            appId: int.tryParse(appId) ?? 0,
            gameName: gameName,
            compatTool: compatTool,
            libraryPath: folderPath,
          ));
        }
      }
    } catch (e) {
      LoggerService().logError('Getting installed games', e);
    }

    return games;
  }

  /// Lists compatibility tool subdirectory names found in Steam's compatibilitytools.d or a custom [customDir].
  List<String> getInstalledCompatTools({String? customDir}) {
    final ctDir = customDir ?? getCompatToolsDir();
    if (ctDir == null) return [];

    final dir = Directory(ctDir);
    if (!dir.existsSync()) return [];

    final tools = <String>[];
    for (final entry in dir.listSync()) {
      if (entry is Directory) {
        tools.add(p.basename(entry.path));
      }
    }

    // Sort: GE-Proton first, then others
    tools.sort((a, b) {
      if (a.startsWith('GE-Proton') && !b.startsWith('GE-Proton')) return -1;
      if (!a.startsWith('GE-Proton') && b.startsWith('GE-Proton')) return 1;
      return b.compareTo(a); // reverse alphabetical (newest first)
    });

    return tools;
  }
}
