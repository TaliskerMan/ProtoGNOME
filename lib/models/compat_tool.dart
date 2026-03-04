// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

class CompatTool {
  final String name;
  final String version;
  final String? releaseDate;
  final String? downloadUrl;
  final int? downloadSize;
  final String? checksum;
  final String toolType; // 'ge-proton', 'boxtron', 'luxtorpeda', etc.
  bool isInstalled;
  bool isDownloading;
  double downloadProgress;

  CompatTool({
    required this.name,
    required this.version,
    required this.toolType,
    this.releaseDate,
    this.downloadUrl,
    this.downloadSize,
    this.checksum,
    this.isInstalled = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  String get displayName => name;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'version': version,
      'tool_type': toolType,
      'release_date': releaseDate,
      'download_url': downloadUrl,
      'download_size': downloadSize,
      'checksum': checksum,
      'is_installed': isInstalled ? 1 : 0,
    };
  }

  factory CompatTool.fromMap(Map<String, dynamic> map) {
    return CompatTool(
      name: map['name'] as String,
      version: map['version'] as String,
      toolType: map['tool_type'] as String,
      releaseDate: map['release_date'] as String?,
      downloadUrl: map['download_url'] as String?,
      downloadSize: map['download_size'] as int?,
      checksum: map['checksum'] as String?,
      isInstalled: (map['is_installed'] as int? ?? 0) == 1,
    );
  }
}
