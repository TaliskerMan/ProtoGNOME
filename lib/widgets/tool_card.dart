// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 ProtoGNOME Contributors

import 'package:flutter/material.dart';
import '../models/compat_tool.dart';

class ToolCard extends StatelessWidget {
  final CompatTool tool;
  final bool isInstalled;
  final VoidCallback? onInstall;
  final VoidCallback? onRemove;

  const ToolCard({
    super.key,
    required this.tool,
    required this.isInstalled,
    this.onInstall,
    this.onRemove,
  });

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E1E3A),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isInstalled
              ? const Color(0xFF7C3AED).withOpacity(0.4)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Installed indicator
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isInstalled
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF3A3A5A),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tool.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      if (isInstalled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Installed',
                              style: TextStyle(
                                  color: Color(0xFFA78BFA),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (tool.releaseDate != null) ...[
                        const Icon(Icons.calendar_today_outlined,
                            size: 11, color: Color(0xFF6666AA)),
                        const SizedBox(width: 3),
                        Text(tool.releaseDate!,
                            style: const TextStyle(
                                color: Color(0xFF6666AA), fontSize: 11)),
                        const SizedBox(width: 10),
                      ],
                      if (tool.downloadSize != null) ...[
                        const Icon(Icons.download_outlined,
                            size: 11, color: Color(0xFF6666AA)),
                        const SizedBox(width: 3),
                        Text(_formatSize(tool.downloadSize),
                            style: const TextStyle(
                                color: Color(0xFF6666AA), fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            if (isInstalled && onRemove != null)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: const Color(0xFFEF4444),
                tooltip: 'Remove',
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2A1A1A)),
              )
            else if (!isInstalled && onInstall != null)
              ElevatedButton.icon(
                onPressed: onInstall,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.download_outlined, size: 15),
                label: const Text('Install',
                    style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
