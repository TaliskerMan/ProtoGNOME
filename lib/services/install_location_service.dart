// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:path/path.dart' as p;

/// Represents a target software environment (Steam, Lutris, Heroic) and its local
/// installation directory path for compatibility runner tools.
class InstallLocation {
  /// Creates a representation of a tool installation directory location.
  InstallLocation({
    required this.id,
    required this.name,
    required this.path,
  });

  /// The unique identifier of the installation target.
  final String id;

  /// The descriptive name of the installation target (e.g. 'Lutris').
  final String name;

  /// The absolute directory path where compatibility tools are installed.
  final String path;
}

/// Service that queries the local filesystem to discover compatible runner/wrapper targets.
/// Detects Lutris directories, Heroic configs, and Steam configurations.
class InstallLocationService {
  factory InstallLocationService() => _instance;
  InstallLocationService._internal();
  static final InstallLocationService _instance =
      InstallLocationService._internal();

  final String _home = Platform.environment['HOME'] ?? '';

  /// Queries directories to return all active and placeholder [InstallLocation] entries.
  List<InstallLocation> getAvailableLocations(String? steamCompatToolsDir) {
    final locations = <InstallLocation>[];

    // Steam
    if (steamCompatToolsDir != null &&
        Directory(steamCompatToolsDir).existsSync()) {
      locations.add(
        InstallLocation(
          id: 'steam',
          name: 'Steam',
          path: steamCompatToolsDir,
        ),
      );
    }

    // Lutris
    final lutrisPath = p.join(_home, '.local/share/lutris/runners/wine');
    if (Directory(p.join(_home, '.local/share/lutris')).existsSync()) {
      // Ensure runners/wine exists if Lutris is installed
      Directory(lutrisPath).createSync(recursive: true);
      locations.add(
        InstallLocation(
          id: 'lutris',
          name: 'Lutris',
          path: lutrisPath,
        ),
      );
    } else {
      // Placeholder if not installed
      locations.add(
        InstallLocation(
          id: 'lutris',
          name: 'Lutris (Not Installed)',
          path: lutrisPath,
        ),
      );
    }

    // Heroic
    final heroicPath = p.join(_home, '.config/heroic/tools/proton');
    if (Directory(p.join(_home, '.config/heroic')).existsSync()) {
      Directory(heroicPath).createSync(recursive: true);
      locations.add(
        InstallLocation(
          id: 'heroic',
          name: 'Heroic Games Launcher',
          path: heroicPath,
        ),
      );
    } else {
      // Placeholder
      locations.add(
        InstallLocation(
          id: 'heroic',
          name: 'Heroic Games Launcher (Not Installed)',
          path: heroicPath,
        ),
      );
    }

    return locations;
  }
}
