// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:protognome/models/compat_tool.dart';
import 'package:protognome/services/database_service.dart';
import 'package:protognome/services/logger_service.dart';
import 'package:protognome/services/secret_service.dart';
import 'package:protognome/services/steam_service.dart';

/// Tool source definitions ported from ProtonUp-Qt's ctloader.py / ctmods.
///
/// Only tools whose releases can be verified are offered: each release must
/// publish a checksum file and/or carry GitHub's recorded SHA-256 digest for
/// the download (see [CompatTool.isVerifiable]). Boxtron and SteamTinkerLaunch
/// were removed because their releases can never be verified, and "Proton-GE
/// (tkg)" because wine-tkg-git's releases are Arch Linux Wine packages that
/// Steam cannot use as a compatibility tool.
const List<Map<String, dynamic>> kToolSources = [
  {
    'name': 'GE-Proton',
    'type': 'ge-proton',
    'repo': 'GloriousEggroll/proton-ge-custom',
    'asset_suffix': '.tar.gz',
    'launchers': ['steam', 'heroic'],
    'description': "GloriousEggroll's Proton build with extra patches",
  },
  {
    'name': 'Luxtorpeda',
    'type': 'luxtorpeda',
    'repo': 'luxtorpeda-dev/luxtorpeda',
    'asset_suffix': '.tar.xz',
    'launchers': ['steam'],
    'description':
        'Steam Play compatibility tool for specific games using native Linux '
        'engines',
  },
];

/// True if the tool of [toolType] works with the launcher [launcherId]
/// ('steam' or 'heroic'), following ProtonUp-Qt: GE-Proton works with Steam
/// and Heroic, Luxtorpeda only with Steam.
bool toolSupportsLauncher(String toolType, String launcherId) {
  final source = kToolSources.firstWhere(
    (s) => s['type'] == toolType,
    orElse: () => const {},
  );
  final launchers = source['launchers'] as List<dynamic>? ?? const [];
  return launchers.contains(launcherId);
}

/// Result of choosing the download + checksum assets from a release's asset
/// list.
class AssetSelection {
  /// Creates a selection; every field is null when nothing usable was found.
  const AssetSelection({
    this.downloadUrl,
    this.downloadSize,
    this.checksumUrl,
    this.assetDigest,
  });

  /// Download URL of the chosen archive, if any.
  final String? downloadUrl;

  /// Size of the chosen archive in bytes, as reported by GitHub.
  final int? downloadSize;

  /// The publisher's checksum file for the chosen download, if any.
  final String? checksumUrl;

  /// GitHub's recorded digest for the chosen download (`sha256:<hex>`), if any.
  final String? assetDigest;
}

/// Service querying GitHub Releases APIs to list and download Steam
/// compatibility tools. Features zip/tar.gz/tar.xz archive extraction routines
/// and tool deletion operations.
class GitHubReleaseService {
  /// Returns the shared service instance.
  factory GitHubReleaseService() => _instance;
  GitHubReleaseService._internal();
  static final GitHubReleaseService _instance =
      GitHubReleaseService._internal();

  /// Hard sanity bound on a download. Proton runtimes are well under 1 GiB;
  /// this only exists to stop a malformed/oversized response filling the disk.
  static const int kMaxDownloadBytes = 4 * 1024 * 1024 * 1024; // 4 GiB

  final _db = DatabaseService();
  String _githubToken = '';

  /// True if the last GitHub API call was rejected for rate-limiting. The UI
  /// can read this to prompt the user to add a token instead of appearing to
  /// fail silently.
  bool isRateLimited = false;

  /// Generates HTTP headers for GitHub API queries, including authorization
  /// tokens if present.
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
      LoggerService()
          .log('Migrated GitHub token from database to secret store.');
    }
  }

  /// Sets a new GitHub API [token] and persists it in the platform secret
  /// store.
  Future<void> setGithubToken(String token) async {
    _githubToken = token;
    await SecretService().setGithubToken(token);
  }

  /// Checksum-file extensions recognised next to a download, in preference
  /// order. `.sha512`/`.sha256` (bare) are what Luxtorpeda publishes.
  static const List<String> kChecksumExtensions = [
    '.sha512sum',
    '.sha256sum',
    '.sha512',
    '.sha256',
  ];

  /// Chooses the download asset (matching [assetSuffix]) from a release's
  /// asset list, the publisher's checksum file for THAT asset, and GitHub's
  /// recorded digest for it. Pure function so it can be unit-tested.
  ///
  /// - Builds for other CPUs (aarch64/arm64) are skipped; if several candidates
  ///   remain, one marked x86_64 is preferred. (GE-Proton publishes both
  ///   `-aarch64.tar.gz` and `-x86_64.tar.gz`; previously whichever came last
  ///   in the list was taken.)
  /// - The checksum file must belong to the chosen download: named
  ///   `<download><ext>` or `<download minus suffix><ext>`.
  static AssetSelection selectAsset(
    List<dynamic> assets,
    String assetSuffix,
  ) {
    final byName = <String, Map<String, dynamic>>{};
    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'] as String? ?? '';
        if (name.isNotEmpty) byName[name] = asset;
      }
    }

    if (assetSuffix.isEmpty) return const AssetSelection();
    final candidates = byName.keys
        .where((n) => n.endsWith(assetSuffix) && !_isOtherArch(n))
        .toList();
    if (candidates.isEmpty) return const AssetSelection();
    final chosen = candidates.firstWhere(
      (n) => n.toLowerCase().contains('x86_64'),
      orElse: () => candidates.first,
    );
    final asset = byName[chosen]!;

    String? checksumUrl;
    final stem = chosen.substring(0, chosen.length - assetSuffix.length);
    outer:
    for (final ext in kChecksumExtensions) {
      for (final name in ['$chosen$ext', '$stem$ext']) {
        final c = byName[name];
        if (c != null && c['browser_download_url'] is String) {
          checksumUrl = c['browser_download_url'] as String;
          break outer;
        }
      }
    }

    final rawDigest = asset['digest'];
    final digest = rawDigest is String ? rawDigest : null;
    return AssetSelection(
      downloadUrl: asset['browser_download_url'] as String?,
      downloadSize: asset['size'] as int?,
      checksumUrl: checksumUrl,
      assetDigest: parseGithubDigest(digest) != null ? digest : null,
    );
  }

  /// True for asset names built for a CPU other than x86_64.
  static bool _isOtherArch(String name) {
    final n = name.toLowerCase();
    return n.contains('aarch64') ||
        n.contains('arm64') ||
        n.contains('armhf') ||
        n.contains('i686');
  }

  /// Returns the hex part of a GitHub asset digest (`sha256:<64 hex>`), or
  /// null if [digest] is missing or not in that form. Pure + testable.
  static String? parseGithubDigest(String? digest) {
    if (digest == null) return null;
    final m = RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest.trim());
    return m?.group(1)?.toLowerCase();
  }

  /// Extracts the expected hex digest for [assetFileName] from the body of a
  /// `shaNNNsum` file. Such files contain `<hex>␠␠<filename>` lines. Returns
  /// the digest matching the asset, or — if the file has a single entry — that
  /// entry's digest. Returns null if nothing matches (caller refuses install).
  static String? parseChecksumDigest(String content, String assetFileName) {
    String? onlyDigest;
    var entries = 0;
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      entries++;
      final parts = line.split(RegExp(r'\s+'));
      final digest = parts.first;
      if (parts.length >= 2) {
        // The filename may be path-prefixed and/or marked with '*' (binary
        // mode).
        final fname =
            p.basename(parts.sublist(1).join(' ')).replaceFirst('*', '');
        if (fname == assetFileName) return digest;
      }
      onlyDigest ??= digest;
    }
    return entries == 1 ? onlyDigest : null;
  }

  /// Returns false for archive members that would escape the extraction root:
  /// absolute paths or any path containing a `..` segment. Pure + testable.
  static bool isSafeArchiveMember(String member) {
    final m = member.trim().replaceAll(r'\', '/');
    if (m.isEmpty) return true;
    if (m.startsWith('/')) return false;
    for (final seg in m.split('/')) {
      if (seg == '..') return false;
    }
    return true;
  }

  /// Fetches available releases for a specific [toolType] (e.g. 'ge-proton')
  /// from GitHub. Falls back to local database caches on request limits or
  /// network issues.
  Future<List<CompatTool>> fetchAvailableReleases(
    String toolType, {
    bool forceRefresh = false,
  }) async {
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
          'Warning: GitHub API rate limit exceeded for $repo. Add a token in '
          'Settings to raise the limit.',
        );
        return await _db.getCachedTools(toolType); // Fall back to cache
      }
      if (response.statusCode != 200) return [];
      isRateLimited = false;

      final releases = jsonDecode(response.body) as List<dynamic>;
      final tools = <CompatTool>[];

      for (final release in releases.whereType<Map<String, dynamic>>()) {
        final tag = release['tag_name'] as String? ?? '';
        final date =
            (release['published_at'] as String? ?? '').split('T').first;

        final assets = release['assets'] as List<dynamic>? ?? [];
        final selection = selectAsset(assets, assetSuffix);

        final downloadUrl = selection.downloadUrl;

        tools.add(
          CompatTool(
            name: tag,
            version: tag,
            toolType: toolType,
            releaseDate: date,
            downloadUrl: downloadUrl,
            downloadSize: selection.downloadSize,
            checksum: selection.checksumUrl,
            assetDigest: selection.assetDigest,
          ),
        );
      }

      await _db.cacheTools(tools);
      return tools;
    } on Object catch (error) {
      LoggerService().logError('Fetching releases for $toolType', error);
      return _db.getCachedTools(toolType);
    }
  }

  /// Queries GitHub releases for all configured compat tool sources.
  Future<Map<String, List<CompatTool>>> fetchAllReleases({
    bool forceRefresh = false,
  }) async {
    final result = <String, List<CompatTool>>{};
    for (final source in kToolSources) {
      final toolType = source['type'] as String;
      result[toolType] = await fetchAvailableReleases(
        toolType,
        forceRefresh: forceRefresh,
      );
    }
    return result;
  }

  /// Pure function calculating byte ranges for parallel multi-stream downloads.
  /// (CP-ChangeComments: Utility to divide file size into N balanced range
  /// chunks for download speed optimization)
  static List<Map<String, int>> calculateChunkRanges(
    int totalBytes, {
    int numChunks = 6,
  }) {
    if (totalBytes <= 0) return [];
    final ranges = <Map<String, int>>[];
    final chunkSize = (totalBytes / numChunks).ceil();
    for (var i = 0; i < numChunks; i++) {
      final start = i * chunkSize;
      if (start >= totalBytes) break;
      var end = start + chunkSize - 1;
      if (end >= totalBytes) end = totalBytes - 1;
      ranges.add({'start': start, 'end': end});
    }
    return ranges;
  }

  /// Downloads the byte range [start]..[end] of [url] into its own [partFile].
  ///
  /// Each chunk writes to a separate part file that is concatenated afterwards.
  /// (Previously every chunk opened the shared target with FileMode.writeOnly,
  /// which truncates the file on open, so concurrent chunks wiped each other's
  /// data and left zero-filled holes; the file still reached full length, so
  /// progress hit 100% but the checksum then failed and install was refused.)
  Future<void> _downloadChunk({
    required String url,
    required File partFile,
    required int start,
    required int end,
    required void Function(int bytesRead) onChunkRead,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['Accept'] = 'application/octet-stream';
    request.headers['Range'] = 'bytes=$start-$end';
    final response = await request.send();

    // A 200 means the server ignored the Range header and is sending the whole
    // file, which would corrupt the assembly; only 206 is acceptable here.
    if (response.statusCode != 206) {
      await response.stream.drain<void>();
      throw Exception(
        'Chunk $start-$end: expected HTTP 206, got ${response.statusCode}',
      );
    }

    final expected = end - start + 1;
    var written = 0;
    final sink = partFile.openWrite();
    try {
      await for (final data in response.stream) {
        written += data.length;
        if (written > expected) {
          throw Exception(
            'Chunk $start-$end: received more than $expected bytes',
          );
        }
        sink.add(data);
        onChunkRead(data.length);
      }
    } finally {
      await sink.close();
    }
    if (written != expected) {
      throw Exception(
        'Chunk $start-$end: received $written of $expected bytes',
      );
    }
  }

  /// High-performance multi-connection parallel downloader for release
  /// archives. (CP-ChangeComments: Resolves 302 redirects to edge CDN and runs
  /// parallel chunk workers for 3x-6x faster downloads)
  Future<bool> _downloadParallel(
    String url,
    File tempFile,
    int totalBytes, {
    void Function(double progress)? onProgress,
  }) async {
    final partFiles = <File>[];
    try {
      // Pre-resolve the HTTP 302 redirect to the CDN URL. followRedirects must
      // be off, otherwise the client follows it and 'location' is never
      // present.
      var finalUrl = url;
      final headReq = http.Request('HEAD', Uri.parse(url))
        ..followRedirects = false;
      final headResp = await headReq.send();
      await headResp.stream.drain<void>();
      final location = headResp.headers['location'];
      if (headResp.statusCode >= 300 &&
          headResp.statusCode < 400 &&
          location != null) {
        finalUrl = Uri.parse(url).resolve(location).toString();
      }

      final numChunks = totalBytes > 100 * 1024 * 1024 ? 6 : 4;
      final ranges = calculateChunkRanges(totalBytes, numChunks: numChunks);
      if (ranges.isEmpty) return false;

      for (var i = 0; i < ranges.length; i++) {
        partFiles.add(File('${tempFile.path}.part$i'));
      }

      var totalReceived = 0;
      final futures = <Future<void>>[];
      for (var i = 0; i < ranges.length; i++) {
        futures.add(
          _downloadChunk(
            url: finalUrl,
            partFile: partFiles[i],
            start: ranges[i]['start']!,
            end: ranges[i]['end']!,
            onChunkRead: (read) {
              totalReceived += read;
              onProgress?.call((totalReceived / totalBytes).clamp(0.0, 1.0));
            },
          ),
        );
      }
      await Future.wait(futures, eagerError: true);

      // Assemble the parts in order into the target file.
      final out = tempFile.openWrite();
      try {
        for (final part in partFiles) {
          await out.addStream(part.openRead());
        }
      } finally {
        await out.close();
      }

      final ok = tempFile.lengthSync() == totalBytes;
      if (!ok) {
        LoggerService().log(
          'Parallel download size mismatch (${tempFile.lengthSync()} != '
          '$totalBytes); falling back to single stream.',
        );
      }
      return ok;
    } on Object catch (error) {
      LoggerService()
          .log('Parallel download fallback to single stream: $error');
      return false;
    } finally {
      for (final part in partFiles) {
        try {
          if (part.existsSync()) part.deleteSync();
        } on Object catch (_) {}
      }
    }
  }

  /// Why the last [downloadAndInstall] failed, in words a user can act on.
  /// Null after a successful install.
  String? lastInstallError;

  /// Downloads the specified compatibility [tool] to a temporary directory,
  /// piping chunk progress to [onProgress], verifies it, and extracts it to
  /// the active [installDir]. Returns false (and installs nothing) if the
  /// download is oversized, can't be verified, or fails verification; the
  /// reason is left in [lastInstallError].
  ///
  /// Verification is required: every available check must pass (the
  /// publisher's checksum file and GitHub's recorded SHA-256 digest), and a
  /// release offering neither is refused before anything is downloaded.
  Future<bool> downloadAndInstall(
    CompatTool tool,
    String installDir, {
    void Function(double progress)? onProgress,
  }) async {
    lastInstallError = null;
    if (tool.downloadUrl == null) {
      lastInstallError = 'This release has no download for this computer.';
      return false;
    }
    if (!tool.isVerifiable) {
      lastInstallError =
          "This release can't be verified (it publishes no checksum), so "
          "ProtoGNOME won't install it.";
      LoggerService().logError(
        'Install',
        'No checksum or GitHub digest for ${tool.name}; refusing to install.',
      );
      return false;
    }

    final tempDir = Directory.systemTemp.createTempSync('protognome_dl_');

    try {
      final uri = Uri.parse(tool.downloadUrl!);
      final tempFile = File(p.join(tempDir.path, p.basename(uri.path)));

      // 1. Attempt high-speed parallel multi-connection HTTP range download for
      // files > 10 MB
      final totalSize = tool.downloadSize ?? 0;
      var downloaded = false;
      if (totalSize > 10 * 1024 * 1024 && totalSize <= kMaxDownloadBytes) {
        downloaded = await _downloadParallel(
          tool.downloadUrl!,
          tempFile,
          totalSize,
          onProgress: onProgress,
        );
      }

      // 2. Fall back to standard single-connection streaming download if
      // parallel download was skipped or failed
      if (!downloaded) {
        final request = http.Request('GET', uri);
        request.headers.addAll(_headers);
        final streamed = await request.send();

        if (streamed.statusCode != 200) {
          lastInstallError =
              'The download failed (HTTP ${streamed.statusCode}). Check your '
              'internet connection and try again.';
          return false;
        }

        final total = streamed.contentLength ?? totalSize;
        if (total > kMaxDownloadBytes) {
          LoggerService().logError(
            'Download',
            'Asset for ${tool.name} reports $total bytes, exceeding the '
            '$kMaxDownloadBytes byte cap. Aborting.',
          );
          lastInstallError = 'The download is larger than ProtoGNOME allows.';
          return false;
        }
        var received = 0;

        final sink = tempFile.openWrite();
        await for (final chunk in streamed.stream) {
          received += chunk.length;
          if (received > kMaxDownloadBytes) {
            await sink.close();
            LoggerService().logError(
              'Download',
              'Download for ${tool.name} exceeded the $kMaxDownloadBytes byte '
              'cap mid-stream. Aborting.',
            );
            lastInstallError = 'The download is larger than ProtoGNOME allows.';
            return false;
          }
          sink.add(chunk);
          if (total > 0) {
            onProgress?.call(received / total);
          }
        }
        await sink.close();
      }

      // Integrity: every available check must pass before an executable
      // runtime is extracted. isVerifiable (checked above) guarantees at
      // least one exists.
      final fileName = p.basename(tempFile.path);
      if (tool.checksum != null && tool.checksum!.isNotEmpty) {
        final ok = await _verifyChecksum(tempFile, tool.checksum!, fileName);
        if (!ok) {
          LoggerService().logError(
            'Install',
            'Publisher checksum verification failed for ${tool.name}; refusing '
            'to install.',
          );
          lastInstallError = _verificationFailedMessage;
          return false;
        }
        LoggerService().log('Publisher checksum verified for ${tool.name}.');
      }
      final githubHex = parseGithubDigest(tool.assetDigest);
      if (githubHex != null) {
        final actual =
            (await sha256.bind(tempFile.openRead()).first).toString();
        if (actual != githubHex) {
          LoggerService().logError(
            'Install',
            'GitHub digest mismatch for $fileName: expected $githubHex, got '
            '$actual; refusing to install.',
          );
          lastInstallError = _verificationFailedMessage;
          return false;
        }
        LoggerService().log('GitHub SHA-256 digest verified for ${tool.name}.');
      }

      final extracted = await _extractArchive(tempFile, installDir, tool.name);
      if (!extracted) {
        lastInstallError =
            'The download was verified but could not be unpacked. See the log '
            'for details.';
      }
      return extracted;
    } on Object catch (error) {
      LoggerService().logError('Downloading ${tool.name}', error);
      lastInstallError ??=
          'The download failed. Check your internet connection and try again.';
      return false;
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } on Object catch (_) {}
    }
  }

  static const String _verificationFailedMessage =
      'The download could not be verified against its published checksum, '
      'so it was not installed. It may have been corrupted or altered, or the '
      "checksum could not be fetched. Try again later; don't install it "
      'another way.';

  /// Downloads [checksumUrl], extracts the expected digest, and compares it to
  /// the hash computed over [file] (streamed, so large files are not buffered).
  /// The algorithm is chosen from the checksum asset's extension.
  Future<bool> _verifyChecksum(
    File file,
    String checksumUrl,
    String assetFileName,
  ) async {
    try {
      final resp = await http.get(Uri.parse(checksumUrl), headers: _headers);
      if (resp.statusCode != 200) {
        LoggerService().logError(
          'Checksum',
          'Could not fetch checksum (HTTP ${resp.statusCode}).',
        );
        return false;
      }
      final expected = parseChecksumDigest(resp.body, assetFileName);
      if (expected == null) {
        LoggerService().logError(
          'Checksum',
          'No matching digest for $assetFileName in checksum file.',
        );
        return false;
      }
      final algo = checksumAlgorithmFor(checksumUrl);
      final digest = await algo.bind(file.openRead()).first;
      final actual = digest.toString().toLowerCase();
      if (actual != expected.toLowerCase()) {
        LoggerService().logError(
          'Checksum',
          'Mismatch for $assetFileName: expected $expected, got $actual.',
        );
        return false;
      }
      return true;
    } on Object catch (error) {
      LoggerService().logError('Checksum verification', error);
      return false;
    }
  }

  /// The hash algorithm for a checksum file, from its extension
  /// (`.sha256sum`/`.sha256` → SHA-256, otherwise SHA-512). Pure + testable.
  static Hash checksumAlgorithmFor(String checksumUrl) {
    final u = checksumUrl.toLowerCase();
    return (u.endsWith('.sha256sum') || u.endsWith('.sha256'))
        ? sha256
        : sha512;
  }

  /// Private helper that runs `tar` (array-form arguments) or uses Dart
  /// ZipDecoder to extract compatibility tool archives into [installDir].
  /// Returns true on success. For tar archives it lists and validates members
  /// first, refusing to extract if any member would escape [installDir]
  /// (defence-in-depth matching the ZIP branch rather than trusting the system
  /// tar).
  Future<bool> _extractArchive(
    File archiveFile,
    String installDir,
    String toolName,
  ) async {
    final path = archiveFile.path;
    final installDirEntity = Directory(installDir);
    if (!installDirEntity.existsSync()) {
      installDirEntity.createSync(recursive: true);
    }

    if (path.endsWith('.tar.gz') || path.endsWith('.tgz')) {
      if (!await _validateTarMembers(path, ['-tzf'])) return false;
      final r = await Process.run('tar', ['-xzf', path, '-C', installDir]);
      return _tarOk(r, toolName);
    } else if (path.endsWith('.tar.xz')) {
      if (!await _validateTarMembers(path, ['-tJf'])) return false;
      final r = await Process.run('tar', ['-xJf', path, '-C', installDir]);
      return _tarOk(r, toolName);
    } else if (path.endsWith('.zip')) {
      final bytes = archiveFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive) {
        final outPath = p.normalize(p.join(installDir, file.name));
        if (!p.isWithin(p.normalize(installDir), outPath)) {
          LoggerService().logError(
            'Zip Extraction',
            'Path traversal attempt blocked: ${file.name}',
          );
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

  /// Logs tar's stderr on failure so extraction problems show up in app.log.
  bool _tarOk(ProcessResult r, String toolName) {
    if (r.exitCode != 0) {
      LoggerService().logError(
        'Extracting $toolName',
        'tar exit ${r.exitCode}: ${r.stderr}',
      );
    }
    return r.exitCode == 0;
  }

  /// Lists a tar archive's members (without extracting) and validates that none
  /// would escape the destination. Returns false if listing fails or any member
  /// is unsafe.
  Future<bool> _validateTarMembers(
    String tarPath,
    List<String> listFlags,
  ) async {
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
          'Tar Extraction',
          'Unsafe member blocked (path traversal): $member',
        );
        return false;
      }
    }
    return true;
  }

  /// Removes a compatibility tool matching [toolName] from the [installDir].
  /// Implements path traversal checks to ensure deletions are constrained
  /// within [installDir].
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
      // Cache clean-up only; the folder is already gone.
      unawaited(_db.deleteTool(toolName));
      unawaited(_db.deleteTool(targetDirName));
      return true;
    } on Object catch (error) {
      LoggerService().logError('Removing $toolName', error);
      return false;
    }
  }
}
