// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

/// Represents a Steam compatibility tool (e.g. Proton-GE, Luxtorpeda, Boxtron)
/// loaded from GitHub releases or detected in the local system configuration.
class CompatTool {
  /// The descriptive name of the compatibility tool.
  final String name;

  /// The version string of the tool release.
  final String version;

  /// Optional ISO date string of the release.
  final String? releaseDate;

  /// URL pointer to download the tool archive file.
  final String? downloadUrl;

  /// Total size of the download archive in bytes.
  final int? downloadSize;

  /// Optional checksum string to verify the download package.
  final String? checksum;

  /// Type category of tool, e.g. 'ge-proton', 'luxtorpeda', 'boxtron'.
  final String toolType;

  /// Tracks if the tool is installed locally.
  bool isInstalled;

  /// State flag tracking active download processes.
  bool isDownloading;

  /// Current download fraction from 0.0 to 1.0.
  double downloadProgress;

  /// Creates a [CompatTool] instance representing a compatibility wrapper.
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

  /// Convenience getter for display labels.
  String get displayName => name;

  /// Serializes the compatibility tool fields into a database map.
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

  /// Deserializes database maps into a [CompatTool] instance.
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
