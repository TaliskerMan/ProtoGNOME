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
  String? _selectedTool; // For batch apply
  bool _selectAll = false;
  bool _applying = false;

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
      final games = await widget.steamService.getInstalledGames();
      final tools = widget.steamService.getInstalledCompatTools();

      // Cache to DB
      await _db.cacheGames(games);

      setState(() {
        _games = games;
        _installedTools = tools;
        if (tools.isNotEmpty) _selectedTool = tools.first;
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

  List<SteamGame> get _selectedGames =>
      _games.where((g) => g.isSelected).toList();

  void _toggleSelectAll(bool? val) {
    setState(() {
      _selectAll = val ?? false;
      for (final game in _filteredGames) {
        game.isSelected = _selectAll;
      }
    });
  }

  Future<void> _applyToSelected() async {
    if (_selectedTool == null) {
      _showSnack('Please select a Proton version first.', error: true);
      return;
    }
    final selected = _selectedGames;
    if (selected.isEmpty) {
      _showSnack('No games selected. Use "Select All" or check individual games.', error: true);
      return;
    }
    setState(() => _applying = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        title: const Text('Apply to Selected',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Apply "$_selectedTool" to ${selected.length} selected game(s)?\n\n'
          'Steam must be restarted for changes to take effect.',
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
      final success = await widget.steamService.applyCompatToolToAllGames(
          _selectedTool!, selected);
      if (success) {
        // Update local state
        for (final game in selected) {
          game.compatTool = _selectedTool;
          game.isSelected = false;
        }
        _selectAll = false;
        _showSnack(
            '${_selectedTool ?? ""} applied to ${selected.length} game(s)! Restart Steam to take effect.');
      } else {
        _showSnack('Failed to apply changes. config.vdf may be locked or corrupted.', error: true);
      }
    }

    setState(() => _applying = false);
  }

  Future<void> _applyToAll() async {
    setState(() {
      for (final game in _games) {
        game.isSelected = true;
      }
      _selectAll = true;
    });
    await _applyToSelected();
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
    final selectedCount = _selectedGames.length;

    return Column(
      children: [
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
        // Batch action bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3A3A5A), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Batch Apply Proton Version',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Tool dropdown
                  Expanded(
                    child: _installedTools.isEmpty
                        ? const Text(
                            'No tools installed. Go to Tools tab to install one.',
                            style: TextStyle(
                                color: Color(0xFF8888AA), fontSize: 13))
                        : DropdownButtonFormField<String>(
                            value: _selectedTool,
                            dropdownColor: const Color(0xFF2A2A4A),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF2A2A4A),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style:
                                const TextStyle(color: Colors.white, fontSize: 13),
                            items: _installedTools
                                .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t,
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedTool = v),
                          ),
                  ),
                  const SizedBox(width: 8),
                  // Apply to selected
                  ElevatedButton.icon(
                    onPressed: _applying ? null : _applyToSelected,
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
                    label: Text(
                        selectedCount > 0
                            ? 'Apply to $selectedCount selected'
                            : 'Apply to Selected',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  // Apply to ALL
                  ElevatedButton.icon(
                    onPressed: _applying ? null : _applyToAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      disabledBackgroundColor: const Color(0xFF3A3A6A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('Apply to ALL Games',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Search + select all bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Checkbox(
                value: _selectAll,
                tristate: true,
                onChanged: _toggleSelectAll,
                activeColor: const Color(0xFF7C3AED),
              ),
              const Text('Select All',
                  style: TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
              const SizedBox(width: 12),
              Expanded(
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
            ],
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
                              onToggleSelect: (val) {
                                setState(() {
                                  game.isSelected = val ?? false;
                                  _selectAll = _games.every((g) => g.isSelected);
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
  final void Function(bool?) onToggleSelect;

  const _GameListTile({
    required this.game,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustomTool = game.compatTool != null && game.compatTool!.isNotEmpty;

    return Card(
      color: game.isSelected
          ? const Color(0xFF2A1E4A)
          : const Color(0xFF1A1A2E),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: game.isSelected
              ? const Color(0xFF7C3AED).withOpacity(0.5)
              : Colors.transparent,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: game.isSelected,
          onChanged: onToggleSelect,
          activeColor: const Color(0xFF7C3AED),
        ),
        title: Text(game.gameName,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(
          hasCustomTool ? game.compatTool! : 'Default (Steam Runtime)',
          style: TextStyle(
            color: hasCustomTool
                ? const Color(0xFF818CF8)
                : const Color(0xFF6666AA),
            fontSize: 12,
          ),
        ),
        trailing: game.isShortcut
            ? const Tooltip(
                message: 'Non-Steam game shortcut',
                child: Icon(Icons.link, color: Color(0xFF8888AA), size: 16))
            : null,
      ),
    );
  }
}
