// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over the platform secret store (on Linux this is the Secret
/// Service API via libsecret). Used to keep the optional GitHub PAT out of the
/// app's plaintext SQLite database.
class SecretService {
  factory SecretService() => _instance;
  SecretService._internal();
  static final SecretService _instance = SecretService._internal();

  static const _tokenKey = 'github_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Reads the stored GitHub token, or null if none is set.
  Future<String?> getGithubToken() => _storage.read(key: _tokenKey);

  /// Stores [token], or deletes the entry when [token] is empty.
  Future<void> setGithubToken(String token) async {
    if (token.isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }
}
