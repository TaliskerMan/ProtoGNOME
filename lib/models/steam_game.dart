// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

class SteamGame {
  final int appId;
  final String gameName;
  String? compatTool; // internal name e.g. 'GE-Proton9-20'
  final bool isShortcut;
  final String? libraryPath;
  bool isSelected; // for batch operations

  SteamGame({
    required this.appId,
    required this.gameName,
    this.compatTool,
    this.isShortcut = false,
    this.libraryPath,
    this.isSelected = false,
  });

  String get appIdStr => appId.toString();

  Map<String, dynamic> toMap() {
    return {
      'app_id': appId,
      'game_name': gameName,
      'compat_tool': compatTool,
      'is_shortcut': isShortcut ? 1 : 0,
      'library_path': libraryPath,
    };
  }

  factory SteamGame.fromMap(Map<String, dynamic> map) {
    return SteamGame(
      appId: map['app_id'] as int,
      gameName: map['game_name'] as String,
      compatTool: map['compat_tool'] as String?,
      isShortcut: (map['is_shortcut'] as int? ?? 0) == 1,
      libraryPath: map['library_path'] as String?,
    );
  }
}
