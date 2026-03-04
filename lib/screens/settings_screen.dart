// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter/material.dart';
import '../services/steam_service.dart';
import '../services/database_service.dart';
import '../services/github_release_service.dart';

class SettingsScreen extends StatefulWidget {
  final SteamService steamService;

  const SettingsScreen({super.key, required this.steamService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  String? _detectedSteamRoot;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final token = await _db.getSetting('github_token') ?? '';
    setState(() {
      _tokenController.text = token;
      _detectedSteamRoot = widget.steamService.getSteamRoot();
    });
  }

  Future<void> _saveToken() async {
    await _db.setSetting('github_token', _tokenController.text.trim());
    GitHubReleaseService().setGithubToken(_tokenController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('GitHub token saved.'),
          backgroundColor: Color(0xFF065F46)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Configure ProtoGNOME behaviour',
              style: TextStyle(color: Color(0xFF8888AA), fontSize: 14)),
          const SizedBox(height: 24),
          // Steam Installation Section
          _buildSection(
            icon: Icons.gamepad_outlined,
            title: 'Steam Installation',
            children: [
              _buildInfoTile(
                label: 'Detected Steam Root',
                value: _detectedSteamRoot ?? 'Not found',
                valueColor: _detectedSteamRoot != null
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
              _buildInfoTile(
                label: 'Config Directory',
                value: widget.steamService.getSteamConfigDir() ?? 'Not found',
              ),
              _buildInfoTile(
                label: 'Compatibility Tools Directory',
                value: widget.steamService.getCompatToolsDir() ?? 'Not found',
              ),
              _buildInfoTile(
                label: 'Installation Valid',
                value: widget.steamService.isValidSteamInstall() ? 'Yes ✓' : 'No ✗',
                valueColor: widget.steamService.isValidSteamInstall()
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // GitHub API Token Section
          _buildSection(
            icon: Icons.vpn_key_outlined,
            title: 'GitHub API Token',
            children: [
              const Text(
                'Optional: Add a GitHub Personal Access Token to avoid API rate limits when fetching release lists.',
                style: TextStyle(color: Color(0xFF8888AA), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                obscureText: _obscureToken,
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                  hintStyle:
                      const TextStyle(color: Color(0xFF6666AA), fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF2A2A4A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                            _obscureToken
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: const Color(0xFF8888AA)),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save_outlined,
                            color: Color(0xFF7C3AED)),
                        onPressed: _saveToken,
                        tooltip: 'Save token',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // About Section Link
          _buildSection(
            icon: Icons.info_outline_rounded,
            title: 'About ProtoGNOME',
            children: [
              const _InfoRow(label: 'Version', value: '1.0.0'),
              const _InfoRow(label: 'License', value: 'GNU GPL v3'),
              const _InfoRow(label: 'Author', value: 'ProtoGNOME Contributors'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7C3AED), size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF3A3A5A), height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
      {required String label, required String value, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8888AA), fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 13,
                  fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8888AA), fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}
