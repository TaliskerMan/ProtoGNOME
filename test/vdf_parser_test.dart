// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

// Tests for the VDF parser. Steam's libraryfolders.vdf / config.vdf format is
// fiddly, and a parse regression silently empties the game/library list, so
// these lock down the structure ProtoGNOME relies on.

import 'package:flutter_test/flutter_test.dart';
import 'package:protognome/services/vdf_parser.dart';

void main() {
  group('VdfParser.parse', () {
    test('parses nested libraryfolders structure', () {
      const vdf = '''
"libraryfolders"
{
	"0"
	{
		"path"		"/home/user/.steam/steam"
		"label"		""
		"apps"
		{
			"220"		"1500000"
			"440"		"900000"
		}
	}
	"1"
	{
		"path"		"/mnt/games/SteamLibrary"
	}
}
''';
      final result = VdfParser.parse(vdf);
      final lib = result['libraryfolders'] as Map<String, dynamic>;
      expect(lib.keys, containsAll(['0', '1']));
      final first = lib['0'] as Map<String, dynamic>;
      expect(first['path'], '/home/user/.steam/steam');
      final apps = first['apps'] as Map<String, dynamic>;
      expect(apps['220'], '1500000');
      expect((lib['1'] as Map)['path'], '/mnt/games/SteamLibrary');
    });

    test('handles escaped quotes and comment lines', () {
      const vdf = '''
"root"
{
	// this is a comment
	"name"	"He said \\"hi\\""
	"path"	"C:\\\\Games"
}
''';
      final result = VdfParser.parse(vdf);
      final root = result['root'] as Map<String, dynamic>;
      expect(root['name'], 'He said "hi"');
      expect(root['path'], r'C:\Games');
    });

    test('round-trips through dump/parse', () {
      final data = {
        'libraryfolders': {
          '0': {'path': '/a/b', 'label': ''},
        }
      };
      final dumped = VdfParser.dump(data);
      final reparsed = VdfParser.parse(dumped);
      expect((reparsed['libraryfolders'] as Map)['0']['path'], '/a/b');
    });
  });
}
