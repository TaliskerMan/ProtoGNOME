// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/compat_tool.dart';
import '../services/github_release_service.dart';
import '../services/steam_service.dart';
import '../widgets/tool_card.dart';

class ToolManagerScreen extends StatefulWidget {
  final SteamService steamService;
  final GitHubReleaseService releaseService;

  const ToolManagerScreen({
    super.key,
    required this.steamService,
    required this.releaseService,
  });

  @override
  State<ToolManagerScreen> createState() => _ToolManagerScreenState();
}

class _ToolManagerScreenState extends State<ToolManagerScreen> {
  String _selectedToolType = 'ge-proton';
  List<CompatTool> _availableTools = [];
  List<String> _installedToolNames = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tools = await widget.releaseService.fetchAvailableReleases(
          _selectedToolType,
          forceRefresh: forceRefresh);
      final installed = widget.steamService.getInstalledCompatTools();
      setState(() {
        _availableTools = tools;
        _installedToolNames = installed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _installTool(CompatTool tool) async {
    final installDir = widget.steamService.getCompatToolsDir();
    if (installDir == null) {
      _showError('Could not determine Steam compatibility tools directory.');
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        tool: tool,
        installDir: installDir,
        releaseService: widget.releaseService,
        onComplete: (success) {
          Navigator.of(ctx).pop();
          if (success) {
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${tool.name} installed successfully!'),
                backgroundColor: const Color(0xFF065F46),
              ),
            );
          } else {
            _showError('Failed to install ${tool.name}. Check your internet connection.');
          }
        },
      ),
    );
  }

  Future<void> _removeTool(String toolName) async {
    final installDir = widget.steamService.getCompatToolsDir();
    if (installDir == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        title: const Text('Remove Tool', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove $toolName?',
          style: const TextStyle(color: Color(0xFFB0B0D0)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = widget.releaseService.removeTool(toolName, installDir);
      if (success) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$toolName removed.'),
            backgroundColor: const Color(0xFF1E1E3A),
          ),
        );
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg), backgroundColor: const Color(0xFF7F1D1D)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compatibility Tools',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Install and manage Proton compatibility tools',
                    style: TextStyle(color: Color(0xFF8888AA), fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _loadData(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF8888AA),
                tooltip: 'Refresh release list',
              ),
            ],
          ),
        ),
        // Tool type selector
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kToolSources.map((source) {
                final type = source['type'] as String;
                final name = source['name'] as String;
                final isSelected = type == _selectedToolType;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(name),
                    onSelected: (_) {
                      setState(() => _selectedToolType = type);
                      _loadData();
                    },
                    selectedColor: const Color(0xFF7C3AED),
                    backgroundColor: const Color(0xFF2A2A4A),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF8888AA),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    checkmarkColor: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Tool list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off,
                              color: Color(0xFF8888AA), size: 48),
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFF8888AA))),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: () => _loadData(forceRefresh: true),
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _availableTools.length,
                      itemBuilder: (ctx, i) {
                        final tool = _availableTools[i];
                        final installed = _installedToolNames
                            .any((n) => n == tool.name);
                        return ToolCard(
                          tool: tool,
                          isInstalled: installed,
                          onInstall: () => _installTool(tool),
                          onRemove: installed
                              ? () => _removeTool(tool.name)
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final CompatTool tool;
  final String installDir;
  final GitHubReleaseService releaseService;
  final void Function(bool success) onComplete;

  const _DownloadProgressDialog({
    required this.tool,
    required this.installDir,
    required this.releaseService,
    required this.onComplete,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = 'Starting download...';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    setState(() => _status = 'Downloading ${widget.tool.name}...');
    final success = await widget.releaseService.downloadAndInstall(
      widget.tool,
      widget.installDir,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (mounted) {
      setState(() => _status = success ? 'Extracting...' : 'Failed!');
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onComplete(success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E3A),
      title: Text(
        'Installing ${widget.tool.name}',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            backgroundColor: const Color(0xFF2A2A4A),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
          ),
          const SizedBox(height: 12),
          Text(_status,
              style: const TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
          if (_progress > 0)
            Text('${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Color(0xFF7C3AED),
                    fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
