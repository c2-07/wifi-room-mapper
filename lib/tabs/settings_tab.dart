import 'package:flutter/material.dart';

import '../models/room_models.dart';

class SettingsTab extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback onExportJson;
  final VoidCallback onExportCsv;
  final VoidCallback onShowImportDialog;
  final List<RoomRecord> rooms;
  final HierarchyLabels labels;
  final List<String> customPositions;
  final ValueChanged<HierarchyLabels> onLabelsChanged;
  final ValueChanged<List<String>> onPositionsChanged;

  const SettingsTab({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onExportJson,
    required this.onExportCsv,
    required this.onShowImportDialog,
    required this.rooms,
    required this.labels,
    required this.customPositions,
    required this.onLabelsChanged,
    required this.onPositionsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF545454);
    final textPrimary = isDark ? Colors.white : Colors.black;
    final surfaceContainer =
        isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEEEEEE);
    final dividerColor =
        isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // TAXONOMY & POSITIONS
        _buildSectionHeader('TAXONOMY & POSITIONS', textSecondary),
        const SizedBox(height: 6),
        _buildListRow(
          context,
          title: 'Hierarchy Labels',
          trailingText:
              '${labels.level1} → ${labels.level2} → ${labels.level3} → ${labels.level4}',
          onTap: () => _showEditHierarchySheet(context),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        Divider(color: dividerColor, height: 1),
        _buildListRow(
          context,
          title: 'Sampling Positions',
          trailingText: '${customPositions.length} positions',
          onTap: () => _showEditPositionsSheet(context),
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 24),

        // DATASET
        _buildSectionHeader('DATASET', textSecondary),
        const SizedBox(height: 6),
        _buildListRow(
          context,
          title: 'Export JSON Backup',
          trailingText: '${rooms.length} ${labels.pluralLevel4.toLowerCase()}',
          onTap: onExportJson,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        Divider(color: dividerColor, height: 1),
        _buildListRow(
          context,
          title: 'Export CSV Matrix',
          trailingText: 'Tabular',
          onTap: onExportCsv,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        Divider(color: dividerColor, height: 1),
        _buildListRow(
          context,
          title: 'Import & Merge Backup',
          trailingText: 'JSON v2',
          onTap: onShowImportDialog,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
        const SizedBox(height: 24),

        // APPEARANCE
        _buildSectionHeader('APPEARANCE', textSecondary),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              Container(
                height: 34,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: surfaceContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final mode in [
                      ThemeMode.system,
                      ThemeMode.light,
                      ThemeMode.dark,
                    ])
                      GestureDetector(
                        onTap: () => onThemeChanged(mode),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: themeMode == mode
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            mode == ThemeMode.system
                                ? 'Auto'
                                : mode == ThemeMode.light
                                    ? 'Light'
                                    : 'Dark',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: themeMode == mode
                                  ? (isDark ? Colors.black : Colors.white)
                                  : textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color textSecondary) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: textSecondary,
      ),
    );
  }

  Widget _buildListRow(
    BuildContext context, {
    required String title,
    required String trailingText,
    required VoidCallback onTap,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                trailingText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }

  void _showEditHierarchySheet(BuildContext context) {
    final l1Ctrl = TextEditingController(text: labels.level1);
    final l2Ctrl = TextEditingController(text: labels.level2);
    final l3Ctrl = TextEditingController(text: labels.level3);
    final l4Ctrl = TextEditingController(text: labels.level4);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rename Hierarchy Labels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: l1Ctrl,
                decoration: const InputDecoration(labelText: 'Level 1 (e.g. Site)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: l2Ctrl,
                decoration: const InputDecoration(labelText: 'Level 2 (e.g. Block)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: l3Ctrl,
                decoration: const InputDecoration(labelText: 'Level 3 (e.g. Level)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: l4Ctrl,
                decoration: const InputDecoration(labelText: 'Level 4 (e.g. Space)'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  final l1 = l1Ctrl.text.trim();
                  final l2 = l2Ctrl.text.trim();
                  final l3 = l3Ctrl.text.trim();
                  final l4 = l4Ctrl.text.trim();
                  if (l1.isNotEmpty && l2.isNotEmpty && l3.isNotEmpty && l4.isNotEmpty) {
                    onLabelsChanged(
                      HierarchyLabels(
                        level1: l1,
                        level2: l2,
                        level3: l3,
                        level4: l4,
                      ),
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Labels'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPositionsSheet(BuildContext context) {
    final positionsList = List<String>.from(customPositions);
    final newPosCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Sampling Positions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < positionsList.length; i++)
                    Chip(
                      label: Text(positionsList[i]),
                      onDeleted: positionsList.length > 1
                          ? () {
                              setSheetState(() => positionsList.removeAt(i));
                              onPositionsChanged(positionsList);
                            }
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newPosCtrl,
                      decoration: const InputDecoration(
                        hintText: 'New position (e.g. Balcony)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final val = newPosCtrl.text.trim();
                      if (val.isNotEmpty && !positionsList.contains(val)) {
                        setSheetState(() => positionsList.add(val));
                        onPositionsChanged(positionsList);
                        newPosCtrl.clear();
                      }
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(80, 48),
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
