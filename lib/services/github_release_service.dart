// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/compat_tool.dart';
import 'database_service.dart';
import 'logger_service.dart';

/// Tool source definitions ported from ProtonUp-Qt's ctloader.py / ctmods.
const List<Map<String, dynamic>> kToolSources = [
  {
    'name': 'GE-Proton',
    'type': 'ge-proton',
    'repo': 'GloriousEggroll/proton-ge-custom',
    'asset_suffix': '.tar.gz',
    'description': 'GloriousEggroll\'s Proton build with extra patches',
  },
  {
    'name': 'Proton-GE (tkg)',
    'type': 'proton-tkg',
    'repo': 'Frogging-Family/wine-tkg-git',
    'asset_suffix': '.tar.zst',
    'description': 'TkG\'s Proton build with advanced configuration',
  },
  {
    'name': 'Boxtron',
    'type': 'boxtron',
    'repo': 'dreamer/boxtron',
    'asset_suffix': '.tar.xz',
    'description': 'Steam Play compatibility tool for DOS games via DOSBox',
  },
  {
    'name': 'Luxtorpeda',
    'type': 'luxtorpeda',
    'repo': 'luxtorpeda-dev/luxtorpeda',
    'asset_suffix': '.tar.xz',
    'description': 'Steam Play compatibility tool for specific games using native Linux engines',
  },
  {
    'name': 'SteamTinkerLaunch',
    'type': 'stl',
    'repo': 'sonic2kk/steamtinkerlaunch',
    'asset_suffix': '',
    'description': 'Wrapper for Steam with extensive game launch configuration',
  },
];

/// Fetches releases and manages download of compatibility tools from GitHub.
/// Ports ProtonUp-Qt's GitHub-based tool fetching logic.
class GitHubReleaseService {
  static final GitHubReleaseService _instance =
      GitHubReleaseService._internal();
  factory GitHubReleaseService() => _instance;
  GitHubReleaseService._internal();

  final _db = DatabaseService();
  String _githubToken = '';

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        if (_githubToken.isNotEmpty) 'Authorization': 'token $_githubToken',
      };

  Future<void> init() async {
    _githubToken = await _db.getSetting('github_token') ?? '';
  }

  void setGithubToken(String token) {
    _githubToken = token;
    _db.setSetting('github_token', token);
  }

  /// Fetch available releases for a specific tool type from GitHub.
  Future<List<CompatTool>> fetchAvailableReleases(String toolType,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getCachedTools(toolType);
      if (cached.isNotEmpty) return cached;
    }

    final source = kToolSources.firstWhere(
      (s) => s['type'] == toolType,
      orElse: () => {},
    );
    if (source.isEmpty) return [];

    final repo = source['repo'] as String;
    final assetSuffix = source['asset_suffix'] as String;
    final url =
        Uri.parse('https://api.github.com/repos/$repo/releases?per_page=30');

    try {
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 403 || response.statusCode == 429) {
        LoggerService().log('Warning: GitHub API rate limit exceeded for $repo');
        return await _db.getCachedTools(toolType); // Fall back to cache
      }
      if (response.statusCode != 200) return [];

      final releases = jsonDecode(response.body) as List<dynamic>;
      final tools = <CompatTool>[];

      for (final release in releases) {
        final tag = release['tag_name'] as String? ?? '';
        final date = (release['published_at'] as String? ?? '').split('T').first;

        String? downloadUrl;
        int? downloadSize;
        String? checksum;

        // Find the right asset
        final assets = release['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (assetSuffix.isNotEmpty && name.endsWith(assetSuffix)) {
            downloadUrl = asset['browser_download_url'] as String?;
            downloadSize = asset['size'] as int?;
          }
          // Look for checksums
          if (name.endsWith('.sha512sum') || name.endsWith('.sha256sum')) {
            checksum = asset['browser_download_url'] as String?;
          }
        }

        // For STL (which has no separate binary asset), use tarball
        if (assetSuffix.isEmpty) {
          downloadUrl = release['tarball_url'] as String?;
        }

        tools.add(CompatTool(
          name: tag,
          version: tag,
          toolType: toolType,
          releaseDate: date,
          downloadUrl: downloadUrl,
          downloadSize: downloadSize,
          checksum: checksum,
        ));
      }

      // Cache the results
      await _db.cacheTools(tools);
      return tools;
    } catch (e) {
      LoggerService().logError('Fetching releases for $toolType', e);
      return await _db.getCachedTools(toolType);
    }
  }

  /// Fetch releases for ALL configured tool types.
  Future<Map<String, List<CompatTool>>> fetchAllReleases(
      {bool forceRefresh = false}) async {
    final result = <String, List<CompatTool>>{};
    for (final source in kToolSources) {
      final toolType = source['type'] as String;
      result[toolType] = await fetchAvailableReleases(toolType,
          forceRefresh: forceRefresh);
    }
    return result;
  }

  /// Download and extract a compatibility tool to the install directory.
  /// Reports progress via the [onProgress] callback.
  Future<bool> downloadAndInstall(
    CompatTool tool,
    String installDir, {
    void Function(double progress)? onProgress,
  }) async {
    if (tool.downloadUrl == null) return false;

    final tempDir = Directory.systemTemp.createTempSync('protognome_dl_');

    try {
      // Download the file
      final uri = Uri.parse(tool.downloadUrl!);
      final request = http.Request('GET', uri);
      request.headers.addAll(_headers);
      final streamed = await request.send();

      if (streamed.statusCode != 200) return false;

      final total = streamed.contentLength ?? 0;
      var received = 0;

      final tempFile = File(p.join(tempDir.path, p.basename(uri.path)));
      final sink = tempFile.openWrite();

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total);
        }
      }
      await sink.close();

      // Extract to install directory
      await _extractArchive(tempFile, installDir, tool.name);

      return true;
    } catch (e) {
      LoggerService().logError('Downloading ${tool.name}', e);
      return false;
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _extractArchive(
      File archiveFile, String installDir, String toolName) async {
    final path = archiveFile.path;
    final installDirEntity = Directory(installDir);
    if (!installDirEntity.existsSync()) {
      installDirEntity.createSync(recursive: true);
    }

    if (path.endsWith('.tar.gz') || path.endsWith('.tgz')) {
      await Process.run('tar', ['-xzf', path, '-C', installDir]);
    } else if (path.endsWith('.tar.xz')) {
      await Process.run('tar', ['-xJf', path, '-C', installDir]);
    } else if (path.endsWith('.tar.zst')) {
      final safeTempDir = Directory.systemTemp.createTempSync('zst_extract_');
      final safeTarPath = p.join(safeTempDir.path, 'tmp.tar');
      final zstdResult = await Process.run('zstd', ['-d', archiveFile.path, '-o', safeTarPath]);
      if (zstdResult.exitCode == 0) {
        await Process.run('tar', ['-xf', safeTarPath, '-C', installDir]);
      } else {
        LoggerService().logError('Zstd Extraction', 'Exit code ${zstdResult.exitCode}: ${zstdResult.stderr}');
      }
      try { safeTempDir.deleteSync(recursive: true); } catch (_) {}
    } else if (path.endsWith('.zip')) {
      final bytes = archiveFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final outPath = p.join(installDir, file.name);
        if (file.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
    }
  }

  /// Remove a compatibility tool from the install directory.
  bool removeTool(String toolName, String installDir) {
    final toolPath = Directory(p.join(installDir, toolName));
    if (!toolPath.existsSync()) return false;
    try {
      toolPath.deleteSync(recursive: true);
      _db.deleteTool(toolName);
      return true;
    } catch (e) {
      LoggerService().logError('Removing $toolName', e);
      return false;
    }
  }
}
