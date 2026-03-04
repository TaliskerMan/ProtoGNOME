// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:path/path.dart' as p;

class InstallLocation {
  final String id;
  final String name;
  final String path;

  InstallLocation({
    required this.id,
    required this.name,
    required this.path,
  });
}

class InstallLocationService {
  static final InstallLocationService _instance = InstallLocationService._internal();
  factory InstallLocationService() => _instance;
  InstallLocationService._internal();

  final String _home = Platform.environment['HOME'] ?? '';

  List<InstallLocation> getAvailableLocations(String? steamCompatToolsDir) {
    final locations = <InstallLocation>[];

    // Steam
    if (steamCompatToolsDir != null && Directory(steamCompatToolsDir).existsSync()) {
      locations.add(InstallLocation(
        id: 'steam',
        name: 'Steam',
        path: steamCompatToolsDir,
      ));
    }

    // Lutris
    final lutrisPath = p.join(_home, '.local/share/lutris/runners/wine');
    if (Directory(p.join(_home, '.local/share/lutris')).existsSync()) {
       // Ensure runners/wine exists if Lutris is installed
       Directory(lutrisPath).createSync(recursive: true);
       locations.add(InstallLocation(
         id: 'lutris',
         name: 'Lutris',
         path: lutrisPath,
       ));
    } else {
      // Placeholder if not installed
      locations.add(InstallLocation(
         id: 'lutris',
         name: 'Lutris (Not Installed)',
         path: lutrisPath,
       ));
    }

    // Heroic
    final heroicPath = p.join(_home, '.config/heroic/tools/proton');
    if (Directory(p.join(_home, '.config/heroic')).existsSync()) {
      Directory(heroicPath).createSync(recursive: true);
      locations.add(InstallLocation(
         id: 'heroic',
         name: 'Heroic Games Launcher',
         path: heroicPath,
       ));
    } else {
      // Placeholder
      locations.add(InstallLocation(
         id: 'heroic',
         name: 'Heroic Games Launcher (Not Installed)',
         path: heroicPath,
       ));
    }

    return locations;
  }
}
