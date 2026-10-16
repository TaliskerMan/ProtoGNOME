// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

// Tests for the pure logic in GitHubReleaseService: asset selection, checksum
// file parsing, and archive-member safety. These cover the download/integrity
// path without any network or filesystem access.

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protognome/models/compat_tool.dart';
import 'package:protognome/services/github_release_service.dart';

void main() {
  group('selectAsset', () {
    test('picks the suffixed download asset and the checksum asset', () {
      final assets = [
        {
          'name': 'GE-Proton9-1.tar.gz',
          'browser_download_url': 'https://example/GE-Proton9-1.tar.gz',
          'size': 123456,
        },
        {
          'name': 'GE-Proton9-1.sha512sum',
          'browser_download_url': 'https://example/GE-Proton9-1.sha512sum',
          'size': 200,
        },
        {
          'name': 'source.zip',
          'browser_download_url': 'https://example/source.zip',
          'size': 999,
        },
      ];
      final sel = GitHubReleaseService.selectAsset(assets, '.tar.gz');
      expect(sel.downloadUrl, 'https://example/GE-Proton9-1.tar.gz');
      expect(sel.downloadSize, 123456);
      expect(sel.checksumUrl, 'https://example/GE-Proton9-1.sha512sum');
    });

    test(
        'picks the x86_64 build and ITS checksum when aarch64 is also '
        'published',
        () {
      // Real asset names from GE-Proton11-9 (Oct 2026), aarch64 listed first.
      Map<String, Object> asset(String name, {String? digest}) => {
            'name': name,
            'browser_download_url': 'https://example/$name',
            'size': 1,
            if (digest != null) 'digest': digest,
          };
      final x86 = 'sha256:${'b' * 64}';
      final assets = [
        asset('GE-Proton11-9-aarch64.sha512sum'),
        asset('GE-Proton11-9-aarch64.tar.gz', digest: 'sha256:${'a' * 64}'),
        asset('GE-Proton11-9-x86_64.sha512sum'),
        asset('GE-Proton11-9-x86_64.tar.gz', digest: x86),
      ];
      final sel = GitHubReleaseService.selectAsset(assets, '.tar.gz');
      expect(sel.downloadUrl, 'https://example/GE-Proton11-9-x86_64.tar.gz');
      expect(sel.checksumUrl, 'https://example/GE-Proton11-9-x86_64.sha512sum');
      expect(sel.assetDigest, x86);

      // Same result whatever order GitHub lists them in.
      final reversed = GitHubReleaseService.selectAsset(
        assets.reversed.toList(),
        '.tar.gz',
      );
      expect(reversed.downloadUrl, sel.downloadUrl);
      expect(reversed.checksumUrl, sel.checksumUrl);
    });

    test('never picks an aarch64-only build', () {
      final assets = [
        {
          'name': 'Tool-aarch64.tar.gz',
          'browser_download_url': 'https://example/Tool-aarch64.tar.gz',
          'size': 1,
        },
      ];
      final sel = GitHubReleaseService.selectAsset(assets, '.tar.gz');
      expect(sel.downloadUrl, isNull);
    });

    test("finds Luxtorpeda's bare .sha512 checksum file", () {
      final assets = [
        {
          'name': 'luxtorpeda-v76.3.0.tar.xz',
          'browser_download_url': 'https://example/luxtorpeda-v76.3.0.tar.xz',
          'size': 5,
          'digest': 'sha256:${'c' * 64}',
        },
        {
          'name': 'luxtorpeda-v76.3.0.tar.xz.sha512',
          'browser_download_url':
              'https://example/luxtorpeda-v76.3.0.tar.xz.sha512',
          'size': 1,
        },
      ];
      final sel = GitHubReleaseService.selectAsset(assets, '.tar.xz');
      expect(
        sel.checksumUrl,
        'https://example/luxtorpeda-v76.3.0.tar.xz.sha512',
      );
      expect(sel.assetDigest, 'sha256:${'c' * 64}');
    });

    test("ignores another download's checksum file", () {
      final assets = [
        {
          'name': 'tool.tar.xz',
          'browser_download_url': 'https://example/tool.tar.xz',
          'size': 1,
        },
        {
          'name': 'other.sha512sum',
          'browser_download_url': 'https://example/other.sha512sum',
          'size': 1,
        },
      ];
      final sel = GitHubReleaseService.selectAsset(assets, '.tar.xz');
      expect(sel.checksumUrl, isNull);
    });

    test('leaves checksum null when none is published', () {
      final assets = [
        {
          'name': 'tool.tar.xz',
          'browser_download_url': 'https://example/tool.tar.xz',
          'size': 10,
        },
      ];
      final sel = GitHubReleaseService.selectAsset(assets, '.tar.xz');
      expect(sel.downloadUrl, 'https://example/tool.tar.xz');
      expect(sel.checksumUrl, isNull);
    });
  });

  group('parseChecksumDigest', () {
    test('matches the digest for the requested filename', () {
      const body =
          'aaaa  other.tar.gz\nbbbb1234  GE-Proton9-1.tar.gz\ncccc  '
          'more.tar.gz\n';
      expect(
        GitHubReleaseService.parseChecksumDigest(body, 'GE-Proton9-1.tar.gz'),
        'bbbb1234',
      );
    });

    test('uses the sole digest when the file has one entry', () {
      const body = 'deadbeef  GE-Proton9-1.tar.gz\n';
      expect(
        GitHubReleaseService.parseChecksumDigest(body, 'anything.tar.gz'),
        'deadbeef',
      );
    });

    test('handles binary-mode (*) filename markers', () {
      const body = 'abc123 *tool.tar.zst\n';
      expect(
        GitHubReleaseService.parseChecksumDigest(body, 'tool.tar.zst'),
        'abc123',
      );
    });

    test('returns null when multiple entries and none match', () {
      const body = 'aaaa  one.tar.gz\nbbbb  two.tar.gz\n';
      expect(
        GitHubReleaseService.parseChecksumDigest(body, 'three.tar.gz'),
        isNull,
      );
    });
  });

  group('GitHub digest', () {
    test('parses sha256 digests and rejects anything else', () {
      final hex = 'AB' * 32;
      expect(
        GitHubReleaseService.parseGithubDigest('sha256:$hex'),
        hex.toLowerCase(),
      );
      expect(GitHubReleaseService.parseGithubDigest(null), isNull);
      expect(GitHubReleaseService.parseGithubDigest('sha256:abc'), isNull);
      expect(GitHubReleaseService.parseGithubDigest('md5:${'a' * 32}'), isNull);
    });

    test('selectAsset drops a malformed digest', () {
      final sel = GitHubReleaseService.selectAsset(
        [
          {
            'name': 'tool.tar.xz',
            'browser_download_url': 'https://example/tool.tar.xz',
            'size': 1,
            'digest': 'sha256:not-hex',
          },
        ],
        '.tar.xz',
      );
      expect(sel.assetDigest, isNull);
    });
  });

  group('checksumAlgorithmFor', () {
    test('picks the algorithm from the extension', () {
      expect(GitHubReleaseService.checksumAlgorithmFor('x.sha256sum'), sha256);
      expect(GitHubReleaseService.checksumAlgorithmFor('x.sha256'), sha256);
      expect(GitHubReleaseService.checksumAlgorithmFor('x.sha512sum'), sha512);
      expect(GitHubReleaseService.checksumAlgorithmFor('x.sha512'), sha512);
    });
  });

  group('isVerifiable', () {
    CompatTool tool({String? checksum, String? digest}) => CompatTool(
          name: 't',
          version: 't',
          toolType: 'ge-proton',
          downloadUrl: 'https://example/t.tar.gz',
          checksum: checksum,
          assetDigest: digest,
        );

    test('needs a checksum file or a GitHub digest', () {
      expect(tool().isVerifiable, isFalse);
      expect(
        tool(checksum: 'https://example/t.sha512sum').isVerifiable,
        isTrue,
      );
      expect(tool(digest: 'sha256:${'a' * 64}').isVerifiable, isTrue);
      expect(tool(checksum: '').isVerifiable, isFalse);
    });

    test(
        'downloadAndInstall refuses an unverifiable release before downloading',
        () async {
      final service = GitHubReleaseService();
      final ok = await service.downloadAndInstall(tool(), '/nonexistent');
      expect(ok, isFalse);
      expect(service.lastInstallError, contains("can't be verified"));
    });
  });

  group('tool list', () {
    test('offers only tools whose releases can be verified', () {
      final types = kToolSources.map((s) => s['type']).toList();
      expect(types, ['ge-proton', 'luxtorpeda']);
    });

    test('each tool is offered only for launchers it works with', () {
      expect(toolSupportsLauncher('ge-proton', 'steam'), isTrue);
      expect(toolSupportsLauncher('ge-proton', 'heroic'), isTrue);
      expect(toolSupportsLauncher('luxtorpeda', 'steam'), isTrue);
      expect(toolSupportsLauncher('luxtorpeda', 'heroic'), isFalse);
      expect(toolSupportsLauncher('ge-proton', 'lutris'), isFalse);
      expect(toolSupportsLauncher('unknown', 'steam'), isFalse);
    });
  });

  group('isSafeArchiveMember', () {
    test('accepts normal relative members', () {
      expect(
        GitHubReleaseService.isSafeArchiveMember('GE-Proton9-1/proton'),
        isTrue,
      );
      expect(
        GitHubReleaseService.isSafeArchiveMember('files/data.bin'),
        isTrue,
      );
    });

    test('rejects absolute paths and parent traversal', () {
      expect(GitHubReleaseService.isSafeArchiveMember('/etc/passwd'), isFalse);
      expect(GitHubReleaseService.isSafeArchiveMember('../evil'), isFalse);
      expect(GitHubReleaseService.isSafeArchiveMember('a/../../b'), isFalse);
    });
  });

  group('calculateChunkRanges', () {
    test('splits file size into balanced parallel byte ranges', () {
      final ranges =
          GitHubReleaseService.calculateChunkRanges(100, numChunks: 4);
      expect(ranges, [
        {'start': 0, 'end': 24},
        {'start': 25, 'end': 49},
        {'start': 50, 'end': 74},
        {'start': 75, 'end': 99},
      ]);
    });

    test('splits large file (>100MB) into 6 chunks correctly', () {
      const totalBytes = 150 * 1024 * 1024;
      final ranges = GitHubReleaseService.calculateChunkRanges(totalBytes);
      expect(ranges.length, 6);
      expect(ranges.first['start'], 0);
      expect(ranges.last['end'], totalBytes - 1);
      for (var i = 0; i < ranges.length - 1; i++) {
        expect(ranges[i]['end']! + 1, ranges[i + 1]['start']);
      }
    });

    test('handles small or zero total bytes gracefully', () {
      expect(GitHubReleaseService.calculateChunkRanges(0), isEmpty);
      expect(GitHubReleaseService.calculateChunkRanges(-100), isEmpty);
    });
  });
}
