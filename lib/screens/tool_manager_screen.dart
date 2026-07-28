// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter/material.dart';
import 'package:protognome/models/compat_tool.dart';
import 'package:protognome/services/github_release_service.dart';
import 'package:protognome/services/install_location_service.dart';
import 'package:protognome/services/steam_service.dart';
import 'package:protognome/widgets/tool_card.dart';

/// Screen component displaying the list of available releases from GitHub
/// and allowing user tool installations, removals, or type queries.
class ToolManagerScreen extends StatefulWidget {
  const ToolManagerScreen({
    required this.steamService,
    required this.releaseService,
    super.key,
  });
  final SteamService steamService;
  final GitHubReleaseService releaseService;

  @override
  State<ToolManagerScreen> createState() => _ToolManagerScreenState();
}

class _ToolManagerScreenState extends State<ToolManagerScreen> {
  String _selectedToolType = 'ge-proton';
  List<CompatTool> _availableTools = [];
  List<String> _installedToolNames = [];
  List<InstallLocation> _availableLocations = [];
  InstallLocation? _selectedLocation;
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
      final steamDir = widget.steamService.getCompatToolsDir();
      _availableLocations =
          InstallLocationService().getAvailableLocations(steamDir);

      if (_selectedLocation == null && _availableLocations.isNotEmpty) {
        _selectedLocation = _availableLocations.first;
      }
      // If selected location became invalid or not in the list, default to first
      if (_selectedLocation != null &&
          !_availableLocations
              .any((loc) => loc.path == _selectedLocation!.path)) {
        _selectedLocation =
            _availableLocations.isNotEmpty ? _availableLocations.first : null;
      }

      final tools = await widget.releaseService.fetchAvailableReleases(
        _selectedToolType,
        forceRefresh: forceRefresh,
      );

      final installed = _selectedLocation != null &&
              !_selectedLocation!.name.contains('(Not Installed)')
          ? widget.steamService
              .getInstalledCompatTools(customDir: _selectedLocation!.path)
          : <String>[];

      setState(() {
        _availableTools = tools;
        _installedToolNames = installed;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _installTool(CompatTool tool) async {
    if (_selectedLocation == null ||
        _selectedLocation!.name.contains('(Not Installed)')) {
      _showError('Selected target is not available or not installed.');
      return;
    }
    final installDir = _selectedLocation!.path;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        tool: tool,
        installDir: installDir,
        releaseService: widget.releaseService,
        onComplete: (success) {
          if (!mounted) return;
          Navigator.of(context).pop();
          if (success) {
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${tool.name} installed successfully!'),
                backgroundColor: const Color(0xFF065F46),
              ),
            );
          } else {
            _showError(
              'Failed to install ${tool.name}. Check your internet connection.',
            );
          }
        },
      ),
    );
  }

  Future<void> _removeTool(String toolName) async {
    if (_selectedLocation == null ||
        _selectedLocation!.name.contains('(Not Installed)')) {
      return;
    }
    final installDir = _selectedLocation!.path;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E3A),
        title: const Text('Confirm Removal',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to completely remove $toolName from your system?',
          style: const TextStyle(color: Color(0xFFB0B0D0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = widget.releaseService.removeTool(toolName, installDir);
      if (success) {
        _loadData();
        if (!mounted) return;
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
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF7F1D1D)),
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
              if (_availableLocations.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<InstallLocation>(
                    dropdownColor: const Color(0xFF2A2A4A),
                    iconEnabledColor: const Color(0xFF8888AA),
                    value: _selectedLocation,
                    items: _availableLocations.map((loc) {
                      return DropdownMenuItem(
                        value: loc,
                        child: Text(
                          loc.name,
                          style: TextStyle(
                            color: loc.name.contains('(Not Installed)')
                                ? const Color(0xFF555577)
                                : Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newLoc) {
                      if (newLoc != null &&
                          !newLoc.name.contains('(Not Installed)')) {
                        setState(() => _selectedLocation = newLoc);
                        _loadData(); // reload installed tools for the new selection
                      }
                    },
                  ),
                ),
              const SizedBox(width: 8),
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
                      color:
                          isSelected ? Colors.white : const Color(0xFF8888AA),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
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
                  child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
                )
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            color: Color(0xFF8888AA),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xFF8888AA)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => _loadData(forceRefresh: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _availableTools.length,
                      itemBuilder: (context, index) {
                        final tool = _availableTools[index];
                        final isInstalled = _installedToolNames
                            .any((name) => name == tool.name);
                        return ToolCard(
                          tool: tool,
                          isInstalled: isInstalled,
                          onInstall: () => _installTool(tool),
                          onRemove:
                              isInstalled ? () => _removeTool(tool.name) : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// Modal dialog tracking the background download progress and extraction status.
class _DownloadProgressDialog extends StatefulWidget {
  const _DownloadProgressDialog({
    required this.tool,
    required this.installDir,
    required this.releaseService,
    required this.onComplete,
  });
  final CompatTool tool;
  final String installDir;
  final GitHubReleaseService releaseService;
  final void Function(bool success) onComplete;

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
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
          Text(
            _status,
            style: const TextStyle(color: Color(0xFF8888AA), fontSize: 13),
          ),
          if (_progress > 0)
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Color(0xFF7C3AED),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
