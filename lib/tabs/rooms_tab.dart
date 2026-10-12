import 'package:flutter/material.dart';

import '../logic/fingerprint_stats.dart';
import '../models/room_models.dart';
import '../theme/app_theme.dart';

class RoomsTab extends StatefulWidget {
  final List<RoomRecord> rooms;
  final HierarchyLabels labels;
  final Set<String> selectedRoomIdsForBulk;
  final void Function(String id, bool selected) onToggleBulkSelection;
  final VoidCallback onClearBulkSelection;
  final VoidCallback onMergeSelected;
  final void Function(List<String> ids) onDeleteRooms;
  final void Function(List<RoomRecord> targetRooms, String prefix) onExportJson;
  final void Function(List<RoomRecord> targetRooms, String prefix) onExportCsv;
  final void Function({RoomRecord? existing}) onShowAddOrEditRoomDialog;
  final void Function(String roomId) onScanInRoom;
  final void Function(RoomRecord room) onShowRoomHistory;

  const RoomsTab({
    super.key,
    required this.rooms,
    required this.labels,
    required this.selectedRoomIdsForBulk,
    required this.onToggleBulkSelection,
    required this.onClearBulkSelection,
    required this.onMergeSelected,
    required this.onDeleteRooms,
    required this.onExportJson,
    required this.onExportCsv,
    required this.onShowAddOrEditRoomDialog,
    required this.onScanInRoom,
    required this.onShowRoomHistory,
  });

  @override
  State<RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<RoomsTab> {
  String spaceFilterQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF6F6F6);
    final containerColor =
        isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEEEEEE);
    final textSecondary =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF545454);
    final textPrimary = isDark ? Colors.white : Colors.black;

    final filtered = widget.rooms.where((r) {
      if (spaceFilterQuery.isEmpty) return true;
      final q = spaceFilterQuery.toLowerCase();
      return r.fullPath.toLowerCase().contains(q) ||
          r.notes.toLowerCase().contains(q);
    }).toList();

    // Grouping by building and floor
    final Map<String, List<RoomRecord>> grouped = {};
    for (final r in filtered) {
      final groupKey = '${r.building.toUpperCase()}  /  ${r.floor.toUpperCase()}';
      grouped.putIfAbsent(groupKey, () => []).add(r);
    }

    // Telemetry computations
    final sites = widget.rooms.map((r) => r.campus).toSet().length;
    final blocks = widget.rooms.map((r) => '${r.campus}|${r.building}').toSet().length;
    final totalScans = widget.rooms.fold(0, (sum, r) => sum + r.totalScans);

    final isMultiSelectMode = widget.selectedRoomIdsForBulk.isNotEmpty;

    return Column(
      children: [
        // Top Inline Telemetry Strip
        Container(
          height: 48,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 11,
                        color: textSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: '$sites ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '${widget.labels.level1.toUpperCase()}  ·  ',
                        ),
                        TextSpan(
                          text: '$blocks ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '${widget.labels.level2.toUpperCase()}  ·  ',
                        ),
                        TextSpan(
                          text: '${widget.rooms.length} ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: '${widget.labels.pluralLevel4.toUpperCase()}  ·  ',
                        ),
                        TextSpan(
                          text: '$totalScans ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const TextSpan(text: 'SCANS'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: Material(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => widget.onShowAddOrEditRoomDialog(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Center(
                        child: Text(
                          '+ New',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Multi-select bulk action bar
        if (isMultiSelectMode)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  '${widget.selectedRoomIdsForBulk.length} selected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.selectedRoomIdsForBulk.length >= 2) ...[
                          TextButton(
                            onPressed: widget.onMergeSelected,
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Merge'),
                          ),
                          const SizedBox(width: 4),
                        ],
                        TextButton(
                          onPressed: () {
                            final subset = widget.rooms
                                .where(
                                  (r) => widget.selectedRoomIdsForBulk.contains(r.id),
                                )
                                .toList();
                            widget.onExportJson(subset, 'selected_spaces');
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Export'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => widget.onDeleteRooms(
                            widget.selectedRoomIdsForBulk.toList(),
                          ),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFFE11900),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Delete'),
                        ),
                        IconButton(
                          onPressed: widget.onClearBulkSelection,
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search ${widget.labels.level1.toLowerCase()}, ${widget.labels.level2.toLowerCase()}, ${widget.labels.level4.toLowerCase()}...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                isDense: true,
              ),
              onChanged: (v) => setState(() => spaceFilterQuery = v),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Space Groups List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      widget.rooms.isEmpty
                          ? 'No ${widget.labels.pluralLevel4.toLowerCase()} registered yet.\nTap "+ New" above to create one.'
                          : 'No matching ${widget.labels.pluralLevel4.toLowerCase()} found.',
                      textAlign: TextAlign.center,
                      style: AppTheme.monoStyle(context, fontSize: 13),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, groupIdx) {
                    final groupKey = grouped.keys.elementAt(groupIdx);
                    final groupRooms = grouped[groupKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group header: HOSTEL BLOCK A  /  FLOOR 4
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  groupKey,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                    color: textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => widget.onExportJson(
                                  groupRooms,
                                  groupKey.replaceAll(' ', '_'),
                                ),
                                child: Text(
                                  'Export',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Space Rows
                        for (final r in groupRooms)
                          _buildSpaceRow(
                            context,
                            r,
                            isDark,
                            surfaceColor,
                            containerColor,
                            textSecondary,
                            textPrimary,
                            isMultiSelectMode,
                          ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSpaceRow(
    BuildContext context,
    RoomRecord r,
    bool isDark,
    Color surfaceColor,
    Color containerColor,
    Color textSecondary,
    Color textPrimary,
    bool isMultiSelectMode,
  ) {
    final quality = evaluateRoomQuality(r);
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.darkSignalColors;
    final qualityColor = signalColors.colorForQuality(quality.score);
    final isSelected = widget.selectedRoomIdsForBulk.contains(r.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (isMultiSelectMode) {
              widget.onToggleBulkSelection(r.id, !isSelected);
            } else {
              widget.onShowRoomHistory(r);
            }
          },
          onLongPress: () {
            widget.onToggleBulkSelection(r.id, !isSelected);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (isMultiSelectMode) ...[
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        widget.onToggleBulkSelection(r.id, val == true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Space Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row: 443 + note + BOUNDARY tag
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              r.room,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (r.notes.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                r.notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          if (r.isCorridorOrBoundary) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: containerColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'BOUNDARY',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Subtitle: 1 session · 5 scans · ● 82%
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  '${r.sessions.length} ${r.sessions.length == 1 ? "session" : "sessions"} · ${r.totalScans} scans · ',
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: qualityColor,
                                ),
                              ),
                            ),
                            TextSpan(
                              text: '${quality.score}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Compact Scan Button
                SizedBox(
                  height: 30,
                  child: Material(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => widget.onScanInRoom(r.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                          child: Text(
                            'Scan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),

                // Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: textSecondary),
                  color: surfaceColor,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onSelected: (action) {
                    switch (action) {
                      case 'scan':
                        widget.onScanInRoom(r.id);
                        break;
                      case 'edit':
                        widget.onShowAddOrEditRoomDialog(existing: r);
                        break;
                      case 'history':
                        widget.onShowRoomHistory(r);
                        break;
                      case 'export_json':
                        widget.onExportJson([r], r.room);
                        break;
                      case 'export_csv':
                        widget.onExportCsv([r], r.room);
                        break;
                      case 'delete':
                        widget.onDeleteRooms([r.id]);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'scan',
                      child: Text('Scan in ${widget.labels.level4}'),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit ${widget.labels.level4}'),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('History & Sessions'),
                    ),
                    const PopupMenuItem(
                      value: 'export_json',
                      child: Text('Export JSON'),
                    ),
                    const PopupMenuItem(
                      value: 'export_csv',
                      child: Text('Export CSV'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Color(0xFFE11900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
