// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2021-2024 DavidoTek (ProtonUp-Qt)
// Copyright (C) 2026 Chuck Talk <chuck@nordheim.online>, Nordheim Online, LLC
// CP-ChangeComments (2026-11-27, v1.0.16+10): Added buildNumber display
// (CP-AutoIncrement), hyperlinked Nordheim Online logo (CP-NordheimLogo),
// and explicit upstream + fork copyright attribution (CP-AboutPage).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Screen component showing system details, project forks, package parameters,
/// maintainer contact information, and license / copyright details.
class AboutScreen extends StatefulWidget {
  /// Creates the About screen.
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _nordheimUrl = 'https://nordheim.online';
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  /// Loads the installed semantic version and build number from PackageInfo.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final suffix = info.buildNumber.isNotEmpty ? '+${info.buildNumber}' : '';
      setState(() {
        _version = 'Version ${info.version}$suffix';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _version = 'Version Unknown';
      });
    }
  }

  /// Opens https://nordheim.online in the user's default desktop browser.
  Future<void> _openNordheimWebsite() async {
    try {
      if (Platform.isLinux) {
        await Process.run('xdg-open', const [_nordheimUrl]);
      }
    } on Object catch (_) {
      // Ignore browser launch errors on headless environments.
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/icons/protoGNOME.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ProtoGNOME',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _version,
                  style:
                      const TextStyle(color: Color(0xFF8888AA), fontSize: 15),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A native GNOME compatibility tool manager\n'
                  'for GE-Proton and Luxtorpeda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB0B0D0), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Tooltip(
                  message: _nordheimUrl,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openNordheimWebsite,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Image.asset(
                        'assets/icons/noln.png',
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildCard(
            children: const [
              _AboutRow(
                icon: Icons.code,
                label: 'Based on',
                value: 'ProtonUp-Qt by DavidoTek (GPL v3.0)',
              ),
              _AboutRow(
                icon: Icons.flutter_dash,
                label: 'Built with',
                value: 'Flutter + Dart (GTK 3 Linux)',
              ),
              _AboutRow(
                icon: Icons.storage_outlined,
                label: 'Backend',
                value: 'SQLite via sqflite_common_ffi',
              ),
              _AboutRow(
                icon: Icons.gavel_outlined,
                label: 'License',
                value: 'GNU General Public License v3.0',
              ),
              _AboutRow(
                icon: Icons.people_outline,
                label: 'Maintainer',
                value: 'Chuck Talk <chuck@nordheim.online>',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            children: const [
              Text(
                'Copyright & Acknowledgements',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Original work: ProtonUp-Qt © 2021-2024 DavidoTek, '
                'licensed under the GNU General Public License v3.0.\n\n'
                'ProtoGNOME fork: © 2026 Chuck Talk (chuck@nordheim.online), '
                'Nordheim Online, LLC, licensed under the GNU General Public '
                'License v3.0.\n\n'
                'Original contributors: DavidoTek and the ProtonUp-Qt '
                'contributors.\n\n'
                'This program is free software: you can redistribute it '
                'and/or modify it under the terms of the GNU General Public '
                'License as published by the Free Software Foundation, either '
                'version 3 of the License, or (at your option) any later '
                'version.\n\n'
                'GE-Proton is © GloriousEggroll. Luxtorpeda is © '
                'luxtorpeda-dev. Steam is © Valve Corporation. This project '
                'is not affiliated with or endorsed by Valve.',
                style: TextStyle(
                  color: Color(0xFF8888AA),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A5A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Renders a single detail row on the About screen page.
class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED), size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8888AA),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
