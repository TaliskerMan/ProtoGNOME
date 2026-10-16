// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Represents a target software environment (Steam or Heroic) and its local
/// installation directory path for compatibility runner tools.
@immutable
class InstallLocation {
  /// Creates a representation of a tool installation directory location.
  const InstallLocation({
    required this.id,
    required this.name,
    required this.path,
  });

  /// The unique identifier of the installation target.
  final String id;

  /// The descriptive name of the installation target (e.g. 'Heroic Games
  /// Launcher').
  final String name;

  /// The absolute directory path where compatibility tools are installed.
  final String path;

  /// Two locations are the same target when their id and path match, so a
  /// freshly rebuilt list still matches an earlier selection.
  @override
  bool operator ==(Object other) =>
      other is InstallLocation && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);
}

/// Service that queries the local filesystem to discover compatible
/// runner/wrapper targets. Detects Steam and Heroic. Lutris is not offered: it
/// runs Wine builds, and neither tool ProtoGNOME installs (GE-Proton,
/// Luxtorpeda) is one.
class InstallLocationService {
  /// Returns the shared InstallLocationService instance.
  factory InstallLocationService() => _instance;
  InstallLocationService._internal();
  static final InstallLocationService _instance =
      InstallLocationService._internal();

  final String _home = Platform.environment['HOME'] ?? '';

  /// Queries directories to return all active and placeholder [InstallLocation]
  /// entries.
  List<InstallLocation> getAvailableLocations(String? steamCompatToolsDir) {
    final locations = <InstallLocation>[];

    // Steam: offered whenever Steam itself was found. compatibilitytools.d
    // doesn't exist until the first tool is installed (the installer creates
    // it), so requiring it hid Steam on fresh installs.
    if (steamCompatToolsDir != null) {
      locations.add(
        InstallLocation(
          id: 'steam',
          name: 'Steam',
          path: steamCompatToolsDir,
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
