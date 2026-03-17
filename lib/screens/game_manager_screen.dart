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
  bool _loading = false;
  String? _error;
  String _searchQuery = '';

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

      // Cache to DB
      await _db.cacheGames(games);

      setState(() {
        _games = games;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredGames;

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
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                            return _GameListTile(game: game);
                          },
                        ),
        ),
      ],
    );
  }
}

class _GameListTile extends StatelessWidget {
  final SteamGame game;

  const _GameListTile({
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.transparent),
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
          ],
        ),
      ),
    );
  }
}

