// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:protognome/services/install_location_service.dart';

void main() {
  test('a rebuilt location equals the earlier one with the same id and path',
      () {
    // The Tools screen rebuilds its location list on every reload; the
    // launcher dropdown needs the earlier selection to match the new entry.
    final before = InstallLocation(id: 'steam', name: 'Steam', path: '/s');
    final after = InstallLocation(id: 'steam', name: 'Steam', path: '/s');
    expect(after, before);
    expect(after.hashCode, before.hashCode);
    expect(
      InstallLocation(id: 'heroic', name: 'Heroic', path: '/h'),
      isNot(before),
    );
  });
}
