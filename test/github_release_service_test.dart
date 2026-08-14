// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

// Tests for the pure logic in GitHubReleaseService: asset selection, checksum
// file parsing, and archive-member safety. These cover the download/integrity
// path without any network or filesystem access.

import 'package:flutter_test/flutter_test.dart';
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
          'aaaa  other.tar.gz\nbbbb1234  GE-Proton9-1.tar.gz\ncccc  more.tar.gz\n';
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
      expect(GitHubReleaseService.parseChecksumDigest(body, 'tool.tar.zst'),
          'abc123');
    });

    test('returns null when multiple entries and none match', () {
      const body = 'aaaa  one.tar.gz\nbbbb  two.tar.gz\n';
      expect(
          GitHubReleaseService.parseChecksumDigest(body, 'three.tar.gz'), isNull);
    });
  });

  group('isSafeArchiveMember', () {
    test('accepts normal relative members', () {
      expect(GitHubReleaseService.isSafeArchiveMember('GE-Proton9-1/proton'),
          isTrue);
      expect(GitHubReleaseService.isSafeArchiveMember('files/data.bin'), isTrue);
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

    test('handles small or zero total bytes gracefully', () {
      expect(GitHubReleaseService.calculateChunkRanges(0), isEmpty);
      expect(GitHubReleaseService.calculateChunkRanges(-100), isEmpty);
    });
  });
}
