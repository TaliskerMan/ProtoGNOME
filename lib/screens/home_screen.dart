// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/compat_tool.dart';
import '../models/steam_game.dart';
import '../services/github_release_service.dart';
import '../services/steam_service.dart';
import '../services/database_service.dart';
import 'tool_manager_screen.dart';
import 'game_manager_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _steamRunning = false;
  String? _steamRoot;
  bool _validInstall = false;

  late final SteamService _steamService;
  late final GitHubReleaseService _releaseService;

  @override
  void initState() {
    super.initState();
    _steamService = SteamService();
    _releaseService = GitHubReleaseService();
    _releaseService.init();
    _checkSteam();
  }

  void _checkSteam() {
    setState(() {
      _steamRoot = _steamService.getSteamRoot();
      _validInstall = _steamService.isValidSteamInstall();
      _steamRunning = _steamService.isSteamRunning();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          NavigationRail(
            backgroundColor: const Color(0xFF1A1A2E),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            extended: false,
            indicatorColor: const Color(0xFF7C3AED),
            selectedIconTheme:
                const IconThemeData(color: Colors.white, size: 24),
            unselectedIconTheme:
                const IconThemeData(color: Color(0xFF8888AA), size: 22),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: Color(0xFF8888AA),
              fontSize: 12,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/icons/proto.png',
                          width: 44, height: 44, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                children: [
                  // Steam status indicator
                  Tooltip(
                    message: _steamRunning ? 'Steam is running' : 'Steam is not running',
                    child: Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _steamRunning
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        boxShadow: [
                          BoxShadow(
                            color: (_steamRunning
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444))
                                .withOpacity(0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.build_circle_outlined),
                selectedIcon: Icon(Icons.build_circle),
                label: Text('Tools'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: Text('Games'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline_rounded),
                selectedIcon: Icon(Icons.info_rounded),
                label: Text('About'),
              ),
            ],
          ),
          // Vertical divider
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFF2A2A4A)),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Status bar
                if (!_validInstall)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: const Color(0xFF7F1D1D),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFCA5A5), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _steamRoot == null
                              ? 'Steam installation not found. Please configure the install path in Settings.'
                              : 'Steam installation found but may be incomplete.',
                          style: const TextStyle(
                              color: Color(0xFFFCA5A5), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                if (_steamRunning)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    color: const Color(0xFF78350F),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Color(0xFFFDE68A), size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Steam is running. Please restart Steam after applying changes.',
                          style: TextStyle(
                              color: Color(0xFFFDE68A), fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _checkSteam,
                          icon: const Icon(Icons.refresh, size: 14,
                              color: Color(0xFFFDE68A)),
                          label: const Text('Refresh',
                              style: TextStyle(
                                  color: Color(0xFFFDE68A), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                // Screen content
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      ToolManagerScreen(
                          steamService: _steamService,
                          releaseService: _releaseService),
                      GameManagerScreen(steamService: _steamService),
                      SettingsScreen(steamService: _steamService),
                      const AboutScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
