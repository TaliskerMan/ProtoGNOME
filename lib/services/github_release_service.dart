// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../models/compat_tool.dart';
import 'database_service.dart';
import 'secret_service.dart';
import 'logger_service.dart';
import 'steam_service.dart';

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

/// Result of choosing the download + checksum assets from a release's asset list.
class AssetSelection {
  final String? downloadUrl;
  final int? downloadSize;
  final String? checksumUrl;
  const AssetSelection({this.downloadUrl, this.downloadSize, this.checksumUrl});
}

/// Service querying GitHub Releases APIs to list and download Steam compatibility tools.
/// Features zip/tar.gz/tar.xz/tar.zst archive extraction routines and tool deletion operations.
class GitHubReleaseService {
  static final GitHubReleaseService _instance =
      GitHubReleaseService._internal();
  factory GitHubReleaseService() => _instance;
  GitHubReleaseService._internal();

  /// Hard sanity bound on a download. Proton runtimes are well under 1 GiB;
  /// this only exists to stop a malformed/oversized response filling the disk.
  static const int kMaxDownloadBytes = 4 * 1024 * 1024 * 1024; // 4 GiB

  final _db = DatabaseService();
  String _githubToken = '';

  /// True if the last GitHub API call was rejected for rate-limiting. The UI can
  /// read this to prompt the user to add a token instead of appearing to fail
  /// silently.
  bool isRateLimited = false;

  /// Generates HTTP headers for GitHub API queries, including authorization tokens if present.
  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        if (_githubToken.isNotEmpty) 'Authorization': 'token $_githubToken',
      };

  /// True if a token is currently configured.
  bool get hasToken => _githubToken.isNotEmpty;

  /// Initializes the service, reading the GitHub token from the platform secret
  /// store. If a legacy plaintext token exists in the SQLite settings table
  /// (older versions stored it there), it is migrated into the secret store and
  /// scrubbed from the database.
  Future<void> init() async {
    final secret = await SecretService().getGithubToken();
    if (secret != null && secret.isNotEmpty) {
      _githubToken = secret;
      return;
    }
    final legacy = await _db.getSetting('github_token') ?? '';
    if (legacy.isNotEmpty) {
      await SecretService().setGithubToken(legacy);
      await _db.setSetting('github_token', ''); // scrub plaintext copy
      _githubToken = legacy;
      LoggerService().log('Migrated GitHub token from database to secret store.');
    }
  }

  /// Sets a new GitHub API [token] and persists it in the platform secret store.
  Future<void> setGithubToken(String token) async {
    _githubToken = token;
    await SecretService().setGithubToken(token);
  }

  /// Chooses the download asset (matching [assetSuffix]) and any published
  /// checksum asset (`.sha512sum`/`.sha256sum`) from a release's asset list.
  /// Pure function so it can be unit-tested.
  static AssetSelection selectAsset(
      List<dynamic> assets, String assetSuffix) {
    String? downloadUrl;
    int? downloadSize;
    String? checksumUrl;
    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (assetSuffix.isNotEmpty && name.endsWith(assetSuffix)) {
        downloadUrl = asset['browser_download_url'] as String?;
        downloadSize = asset['size'] as int?;
      }
      if (name.endsWith('.sha512sum') || name.endsWith('.sha256sum')) {
        checksumUrl = asset['browser_download_url'] as String?;
      }
    }
    return AssetSelection(
      downloadUrl: downloadUrl,
      downloadSize: downloadSize,
      checksumUrl: checksumUrl,
    );
  }

  /// Extracts the expected hex digest for [assetFileName] from the body of a
  /// `shaNNNsum` file. Such files contain `<hex>␠␠<filename>` lines. Returns the
  /// digest matching the asset, or — if the file has a single entry — that
  /// entry's digest. Returns null if nothing matches (caller refuses install).
  static String? parseChecksumDigest(String content, String assetFileName) {
    String? onlyDigest;
    int entries = 0;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      entries++;
      final parts = line.split(RegExp(r'\s+'));
      final digest = parts.first;
      if (parts.length >= 2) {
        // The filename may be path-prefixed and/or marked with '*' (binary mode).
        final fname = p.basename(parts.sublist(1).join(' ')).replaceFirst('*', '');
        if (fname == assetFileName) return digest;
      }
      onlyDigest ??= digest;
    }
    return entries == 1 ? onlyDigest : null;
  }

  /// Returns false for archive members that would escape the extraction root:
  /// absolute paths or any path containing a `..` segment. Pure + testable.
  static bool isSafeArchiveMember(String member) {
    final m = member.trim().replaceAll('\\', '/');
    if (m.isEmpty) return true;
    if (m.startsWith('/')) return false;
    for (final seg in m.split('/')) {
      if (seg == '..') return false;
    }
    return true;
  }

  /// Fetches available releases for a specific [toolType] (e.g. 'ge-proton') from GitHub.
  /// Falls back to local database caches on request limits or network issues.
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
        isRateLimited = true;
        LoggerService().log(
            'Warning: GitHub API rate limit exceeded for $repo. Add a token in Settings to raise the limit.');
        return await _db.getCachedTools(toolType); // Fall back to cache
      }
      if (response.statusCode != 200) return [];
      isRateLimited = false;

      final releases = jsonDecode(response.body) as List<dynamic>;
      final tools = <CompatTool>[];

      for (final release in releases) {
        final tag = release['tag_name'] as String? ?? '';
        final date = (release['published_at'] as String? ?? '').split('T').first;

        final assets = release['assets'] as List<dynamic>? ?? [];
        final selection = selectAsset(assets, assetSuffix);

        String? downloadUrl = selection.downloadUrl;
        // For STL (which has no separate binary asset), use tarball.
        if (assetSuffix.isEmpty) {
          downloadUrl = release['tarball_url'] as String?;
        }

        tools.add(CompatTool(
          name: tag,
          version: tag,
          toolType: toolType,
          releaseDate: date,
          downloadUrl: downloadUrl,
          downloadSize: selection.downloadSize,
          checksum: selection.checksumUrl,
        ));
      }

      await _db.cacheTools(tools);
      return tools;
    } catch (error) {
      LoggerService().logError('Fetching releases for $toolType', error);
      return await _db.getCachedTools(toolType);
    }
  }

  /// Queries GitHub releases for all configured compat tool sources.
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

  /// Downloads the specified compatibility [tool] to a temporary directory,
  /// piping chunk progress to [onProgress], verifies its published checksum,
  /// and extracts it to the active [installDir]. Returns false (and installs
  /// nothing) if the download is oversized or the checksum does not match.
  Future<bool> downloadAndInstall(
    CompatTool tool,
    String installDir, {
    void Function(double progress)? onProgress,
  }) async {
    if (tool.downloadUrl == null) return false;

    final tempDir = Directory.systemTemp.createTempSync('protognome_dl_');

    try {
      final uri = Uri.parse(tool.downloadUrl!);
      final request = http.Request('GET', uri);
      request.headers.addAll(_headers);
      final streamed = await request.send();

      if (streamed.statusCode != 200) return false;

      final total = streamed.contentLength ?? 0;
      if (total > kMaxDownloadBytes) {
        LoggerService().logError('Download',
            'Asset for ${tool.name} reports $total bytes, exceeding the ${kMaxDownloadBytes} byte cap. Aborting.');
        return false;
      }
      var received = 0;

      final tempFile = File(p.join(tempDir.path, p.basename(uri.path)));
      final sink = tempFile.openWrite();

      await for (final chunk in streamed.stream) {
        received += chunk.length;
        if (received > kMaxDownloadBytes) {
          await sink.close();
          LoggerService().logError('Download',
              'Download for ${tool.name} exceeded the ${kMaxDownloadBytes} byte cap mid-stream. Aborting.');
          return false;
        }
        sink.add(chunk);
        if (total > 0) {
          onProgress?.call(received / total);
        }
      }
      await sink.close();

      // Integrity: verify the published checksum before extracting/installing an
      // executable runtime. Refuse on mismatch or when verification can't run.
      if (tool.checksum != null && tool.checksum!.isNotEmpty) {
        final ok = await _verifyChecksum(
            tempFile, tool.checksum!, p.basename(tempFile.path));
        if (!ok) {
          LoggerService().logError('Install',
              'Checksum verification failed for ${tool.name}; refusing to install.');
          return false;
        }
        LoggerService().log('Checksum verified for ${tool.name}.');
      } else {
        LoggerService().log(
            'No checksum published for ${tool.name}; installing without integrity verification.');
      }

      return await _extractArchive(tempFile, installDir, tool.name);
    } catch (error) {
      LoggerService().logError('Downloading ${tool.name}', error);
      return false;
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Downloads [checksumUrl], extracts the expected digest, and compares it to
  /// the hash computed over [file] (streamed, so large files are not buffered).
  /// The algorithm is chosen from the checksum asset's extension.
  Future<bool> _verifyChecksum(
      File file, String checksumUrl, String assetFileName) async {
    try {
      final resp = await http.get(Uri.parse(checksumUrl), headers: _headers);
      if (resp.statusCode != 200) {
        LoggerService().logError(
            'Checksum', 'Could not fetch checksum (HTTP ${resp.statusCode}).');
        return false;
      }
      final expected = parseChecksumDigest(resp.body, assetFileName);
      if (expected == null) {
        LoggerService().logError(
            'Checksum', 'No matching digest for $assetFileName in checksum file.');
        return false;
      }
      final algo = checksumUrl.endsWith('.sha256sum') ? sha256 : sha512;
      final digest = await algo.bind(file.openRead()).first;
      final actual = digest.toString().toLowerCase();
      if (actual != expected.toLowerCase()) {
        LoggerService().logError('Checksum',
            'Mismatch for $assetFileName: expected $expected, got $actual.');
        return false;
      }
      return true;
    } catch (error) {
      LoggerService().logError('Checksum verification', error);
      return false;
    }
  }

  /// Private helper that spawns OS subprocesses (tar, zstd) or uses Dart ZipDecoder
  /// to extract compatibility tool archives into [installDir]. Returns true on
  /// success. For tar archives it lists and validates members first, refusing to
  /// extract if any member would escape [installDir] (defence-in-depth matching
  /// the ZIP branch rather than trusting the system tar).
  Future<bool> _extractArchive(
      File archiveFile, String installDir, String toolName) async {
    final path = archiveFile.path;
    final installDirEntity = Directory(installDir);
    if (!installDirEntity.existsSync()) {
      installDirEntity.createSync(recursive: true);
    }

    if (path.endsWith('.tar.gz') || path.endsWith('.tgz')) {
      if (!await _validateTarMembers(path, ['-tzf'])) return false;
      final r = await Process.run('tar', ['-xzf', path, '-C', installDir]);
      return r.exitCode == 0;
    } else if (path.endsWith('.tar.xz')) {
      if (!await _validateTarMembers(path, ['-tJf'])) return false;
      final r = await Process.run('tar', ['-xJf', path, '-C', installDir]);
      return r.exitCode == 0;
    } else if (path.endsWith('.tar.zst')) {
      final safeTempDir = Directory.systemTemp.createTempSync('zst_extract_');
      final safeTarPath = p.join(safeTempDir.path, 'tmp.tar');
      try {
        final zstdResult = await Process.run(
            'zstd', ['-d', archiveFile.path, '-o', safeTarPath]);
        if (zstdResult.exitCode != 0) {
          LoggerService().logError('Zstd Extraction',
              'Exit code ${zstdResult.exitCode}: ${zstdResult.stderr}');
          return false;
        }
        if (!await _validateTarMembers(safeTarPath, ['-tf'])) return false;
        final r = await Process.run('tar', ['-xf', safeTarPath, '-C', installDir]);
        return r.exitCode == 0;
      } finally {
        try {
          safeTempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    } else if (path.endsWith('.zip')) {
      final bytes = archiveFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final outPath = p.normalize(p.join(installDir, file.name));
        if (!p.isWithin(p.normalize(installDir), outPath)) {
          LoggerService().logError(
              'Zip Extraction', 'Path traversal attempt blocked: ${file.name}');
          continue;
        }
        if (file.isFile) {
          File(outPath)
            ..createSync(recursive: true)
            ..writeAsBytesSync(file.content as List<int>);
        } else {
          Directory(outPath).createSync(recursive: true);
        }
      }
      return true;
    }
    LoggerService().logError('Extraction', 'Unsupported archive format: $path');
    return false;
  }

  /// Lists a tar archive's members (without extracting) and validates that none
  /// would escape the destination. Returns false if listing fails or any member
  /// is unsafe.
  Future<bool> _validateTarMembers(String tarPath, List<String> listFlags) async {
    final res = await Process.run('tar', [...listFlags, tarPath]);
    if (res.exitCode != 0) {
      LoggerService()
          .logError('Tar list', 'Exit ${res.exitCode}: ${res.stderr}');
      return false;
    }
    for (final raw in (res.stdout as String).split('\n')) {
      final member = raw.trim();
      if (member.isEmpty) continue;
      if (!isSafeArchiveMember(member)) {
        LoggerService().logError(
            'Tar Extraction', 'Unsafe member blocked (path traversal): $member');
        return false;
      }
    }
    return true;
  }

  /// Removes a compatibility tool matching [toolName] from the [installDir].
  /// Implements path traversal checks to ensure deletions are constrained within [installDir].
  bool removeTool(String toolName, String installDir) {
    final targetDirName =
        SteamService().findInstalledToolDir(toolName, customDir: installDir) ??
            p.basename(toolName);
    final toolPath = Directory(p.join(installDir, targetDirName));

    // Strict bounds check to prevent directory deletion exploits
    if (!p.isWithin(p.normalize(installDir), p.normalize(toolPath.path))) {
      return false;
    }

    if (!toolPath.existsSync()) return false;
    try {
      toolPath.deleteSync(recursive: true);
      _db.deleteTool(toolName);
      _db.deleteTool(targetDirName);
      return true;
    } catch (error) {
      LoggerService().logError('Removing $toolName', error);
      return false;
    }
  }
}
