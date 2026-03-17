// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter/material.dart';
import '../models/steam_game.dart';
import '../services/steam_service.dart';
import '../services/database_service.dart';

class GameManagerScreen extends StatefulWidget {
  final SteamService steamService;

  const GameManagerScreen({super.key, required this.steamService});

  @override
  State<GameManagerScreen> createState() => _GameManagerScreenState();
}

class _GameManagerScreenState extends State<GameManagerScreen> {
  List<SteamGame> _games = [];
  List<String> _installedTools = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  bool _applying = false;
  bool _isSteamRunning = false;

  // Map of appId to selected tool name (or null for default)
  final Map<int, String?> _selectedTools = {};

  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isRunning = widget.steamService.isSteamRunning();
      final games = await widget.steamService.getInstalledGames();
      final tools = widget.steamService.getInstalledCompatTools();

      // Cache to DB
      await _db.cacheGames(games);

      final Map<int, String?> initialSelections = {};
      for (final game in games) {
        initialSelections[game.appId] = game.compatTool;
      }

      setState(() {
        _isSteamRunning = isRunning;
        _games = games;
        _installedTools = tools;
        _selectedTools.clear();
        _selectedTools.addAll(initialSelections);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<SteamGame> get _filteredGames {
    if (_searchQuery.isEmpty) return _games;
    return _games
        .where((g) =>
            g.gameName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  Map<int, String?> get _pendingChanges {
    final Map<int, String?> changes = {};
    for (final game in _games) {
      final selected = _selectedTools[game.appId];
      if (selected != game.compatTool) {
        changes[game.appId] = selected;
      }
    }
    return changes;
  }

  Future<void> _applyChanges() async {
    final changes = _pendingChanges;
    if (changes.isEmpty) {
      _showSnack('No changes to apply.');
      return;
    }

    // Re-check Steam status just in case
    final isRunningNow = widget.steamService.isSteamRunning();
    if (isRunningNow) {
      setState(() => _isSteamRunning = true);
      _showSnack('Steam is running. Please close Steam before applying changes.', error: true);
      return;
    }

    setState(() => _applying = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        title: const Text('Apply Changes',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Apply compatibility tool changes to ${changes.length} game(s)?\n\n'
          'IMPORTANT: Steam must not be running. You will need to start Steam afterward to see the changes.',
          style: const TextStyle(color: Color(0xFFB0B0D0)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.steamService.updateCompatTools(changes);
      if (success) {
        _showSnack('Tools updated for ${changes.length} game(s)!');
        await _loadGames();
      } else {
        _showSnack('Failed to apply changes. config.vdf may be locked or corrupted.', error: true);
      }
    }

    setState(() => _applying = false);
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error
            ? const Color(0xFF7F1D1D)
            : const Color(0xFF065F46),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGames;
    final changesCount = _pendingChanges.length;

    return Column(
      children: [
        // Steam running warning
        if (_isSteamRunning)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: const Color(0xFF7F1D1D),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Steam is currently running. You must close Steam before applying changes.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Game Manager',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    '${_games.length} games found',
                    style:
                        const TextStyle(color: Color(0xFF8888AA), fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadGames,
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF8888AA),
                tooltip: 'Refresh game list',
              ),
            ],
          ),
        ),
        // Action bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A5A), width: 1),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending Changes',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$changesCount game(s) modified',
                    style: const TextStyle(color: Color(0xFF8888AA), fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (changesCount > 0 && !_applying && !_isSteamRunning) ? _applyChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  disabledBackgroundColor: const Color(0xFF4A3A5A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: _applying
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Apply Changes', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search games...',
              hintStyle: const TextStyle(color: Color(0xFF6666AA)),
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF6666AA), size: 18),
              filled: true,
              fillColor: const Color(0xFF1E1E3A),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        // Game list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFF8888AA), size: 48),
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFF8888AA))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _loadGames,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sports_esports_outlined,
                                  color: Color(0xFF8888AA), size: 64),
                              SizedBox(height: 12),
                              Text('No games found',
                                  style: TextStyle(
                                      color: Color(0xFF8888AA),
                                      fontSize: 16)),
                              SizedBox(height: 4),
                              Text(
                                'Make sure Steam is installed and you have games in your library.',
                                style: TextStyle(
                                    color: Color(0xFF6666AA), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final game = filtered[i];
                            return _GameListTile(
                              game: game,
                              installedTools: _installedTools,
                              selectedTool: _selectedTools[game.appId],
                              isChanged: _selectedTools[game.appId] != game.compatTool,
                              onToolChanged: (val) {
                                setState(() {
                                  _selectedTools[game.appId] = val;
                                });
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _GameListTile extends StatelessWidget {
  final SteamGame game;
  final List<String> installedTools;
  final String? selectedTool;
  final bool isChanged;
  final void Function(String?) onToolChanged;

  const _GameListTile({
    required this.game,
    required this.installedTools,
    required this.selectedTool,
    required this.isChanged,
    required this.onToolChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isChanged
          ? const Color(0xFF2A1E4A)
          : const Color(0xFF1A1A2E),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isChanged
              ? const Color(0xFF7C3AED).withOpacity(0.5)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (game.isShortcut)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: 'Non-Steam game shortcut',
                  child: Icon(Icons.link, color: Color(0xFF8888AA), size: 20)
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.gameName,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.compatTool != null && game.compatTool!.isNotEmpty 
                        ? 'Current: ${game.compatTool}' 
                        : 'Current: Default (Steam Runtime)',
                    style: const TextStyle(color: Color(0xFF6666AA), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                value: selectedTool,
                dropdownColor: const Color(0xFF2A2A4A),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1E1E3A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: const Color(0xFF3A3A5A), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: const Color(0xFF3A3A5A), width: 1),
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Default (Steam Runtime)'),
                  ),
                  ...installedTools.map((t) => DropdownMenuItem<String?>(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: onToolChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
