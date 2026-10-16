// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

/// Represents a detected Steam game (or non-Steam shortcut library entry)
/// and its assigned compatibility tool configuration.
class SteamGame {
  /// Creates a [SteamGame] representation with associated parameters.
  SteamGame({
    required this.appId,
    required this.gameName,
    this.compatTool,
    this.isShortcut = false,
    this.libraryPath,
    this.isSelected = false,
  });

  /// Deserializes database maps into a [SteamGame] instance.
  factory SteamGame.fromMap(Map<String, dynamic> map) {
    return SteamGame(
      appId: map['app_id'] as int,
      gameName: map['game_name'] as String,
      compatTool: map['compat_tool'] as String?,
      isShortcut: (map['is_shortcut'] as int? ?? 0) == 1,
      libraryPath: map['library_path'] as String?,
    );
  }

  /// The unique application ID assigned by Steam.
  final int appId;

  /// The human-readable name of the game.
  final String gameName;

  /// The active compatibility tool mapped to the game.
  String? compatTool;

  /// Indicates if the entry is a user-added custom shortcut.
  final bool isShortcut;

  /// Path to the Steam library folder where the game is installed.
  final String? libraryPath;

  /// State flag tracking selection states during batch UI operations.
  bool isSelected;

  /// Returns string representation of [appId].
  String get appIdStr => appId.toString();

  /// Serializes game attributes into a database map.
  Map<String, dynamic> toMap() {
    return {
      'app_id': appId,
      'game_name': gameName,
      'compat_tool': compatTool,
      'is_shortcut': isShortcut ? 1 : 0,
      'library_path': libraryPath,
    };
  }
}
