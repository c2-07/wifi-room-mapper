import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../models/room_models.dart';
import '../theme/app_theme.dart';
import '../widgets/detail_sheets.dart';

class ScanTab extends StatefulWidget {
  final List<RoomRecord> rooms;
  final HierarchyLabels labels;
  final List<String> customPositions;
  final String? selectedRoomId;
  final ValueChanged<String?> onRoomSelected;
  final bool isScanning;
  final List<WiFiAccessPoint> liveAccessPoints;
  final String scanStatus;
  final int currentSessionProgress;
  final int targetSessionScans;
  final int scanIntervalSeconds;
  final String selectedPosition;
  final ValueChanged<String> onPositionChanged;
  final ValueChanged<int> onTargetScansChanged;
  final ValueChanged<int> onIntervalChanged;
  final VoidCallback onStartSession;
  final VoidCallback onStopSession;
  final VoidCallback onInspectOnly;
  final VoidCallback onShowAddRoomDialog;

  const ScanTab({
    super.key,
    required this.rooms,
    required this.labels,
    required this.customPositions,
    required this.selectedRoomId,
    required this.onRoomSelected,
    required this.isScanning,
    required this.liveAccessPoints,
    required this.scanStatus,
    required this.currentSessionProgress,
    required this.targetSessionScans,
    required this.scanIntervalSeconds,
    required this.selectedPosition,
    required this.onPositionChanged,
    required this.onTargetScansChanged,
    required this.onIntervalChanged,
    required this.onStartSession,
    required this.onStopSession,
    required this.onInspectOnly,
    required this.onShowAddRoomDialog,
  });

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> {
  String apSearchQuery = '';
  String apBandFilter = 'All';

  static const List<({int scans, int interval, String label})> _burstPresets = [
    (scans: 1, interval: 0, label: '1x'),
    (scans: 5, interval: 3, label: '5x · 3s'),
    (scans: 10, interval: 3, label: '10x · 3s'),
    (scans: 10, interval: 5, label: '10x · 5s'),
  ];

  String get _currentPresetLabel {
    for (final p in _burstPresets) {
      if (p.scans == widget.targetSessionScans &&
          (p.scans == 1 || p.interval == widget.scanIntervalSeconds)) {
        return p.label;
      }
    }
    return '${widget.targetSessionScans}x · ${widget.scanIntervalSeconds}s';
  }

  void _cycleBurstPreset() {
    int idx = _burstPresets.indexWhere(
      (p) =>
          p.scans == widget.targetSessionScans &&
          (p.scans == 1 || p.interval == widget.scanIntervalSeconds),
    );
    final nextIdx = (idx + 1) % _burstPresets.length;
    final next = _burstPresets[nextIdx];
    widget.onTargetScansChanged(next.scans);
    widget.onIntervalChanged(next.interval);
  }

  String _cleanBand(int freqMHz) {
    if (freqMHz >= 5925) return '6 GHz';
    if (freqMHz >= 4900) return '5 GHz';
    if (freqMHz >= 2400) return '2.4 GHz';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.darkSignalColors;

    final filteredAps = widget.liveAccessPoints.where((ap) {
      final band = _cleanBand(ap.frequency);
      if (apBandFilter == '2.4' && !band.contains('2.4')) return false;
      if (apBandFilter == '5' && !band.contains('5')) return false;
      if (apBandFilter == '6' && !band.contains('6')) return false;

      if (apSearchQuery.isNotEmpty) {
        final q = apSearchQuery.toLowerCase();
        return ap.ssid.toLowerCase().contains(q) ||
            ap.bssid.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    filteredAps.sort((a, b) => b.level.compareTo(a.level));

    final surfaceColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF6F6F6);
    final containerColor =
        isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEEEEEE);
    final dividerLineColor =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Compact Top Control Block
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Target Space Dropdown + Quick Add (+)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('target_room_${widget.selectedRoomId}'),
                      isExpanded: true,
                      initialValue: widget.rooms.any((r) => r.id == widget.selectedRoomId)
                          ? widget.selectedRoomId
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Select ${widget.labels.level4}...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      items: widget.rooms.map((r) {
                        final tag = r.isCorridorOrBoundary ? '[CORRIDOR] ' : '';
                        return DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(
                            '$tag${r.room} · ${r.building}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: widget.isScanning
                          ? null
                          : (val) => widget.onRoomSelected(val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.isScanning ? null : widget.onShowAddRoomDialog,
                        child: Icon(
                          Icons.add,
                          size: 20,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Horizontal Position Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final pos in widget.customPositions) ...[
                      GestureDetector(
                        onTap: widget.isScanning
                            ? null
                            : () => widget.onPositionChanged(pos),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.selectedPosition == pos
                                ? (isDark
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFF000000))
                                : containerColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pos,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.selectedPosition == pos
                                  ? (isDark
                                      ? const Color(0xFF000000)
                                      : const Color(0xFFFFFFFF))
                                  : (isDark
                                      ? const Color(0xFFFFFFFF)
                                      : const Color(0xFF000000)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Row 3: Burst Cycle + Record / Stop + Quick Refresh
              Row(
                children: [
                  // Burst Cycle Button
                  SizedBox(
                    height: 48,
                    child: Material(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.isScanning ? null : _cycleBurstPreset,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: Text(
                              _currentPresetLabel,
                              style: AppTheme.monoStyle(
                                context,
                                fontSize: 13,
                                weight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Center Record / Stop Button
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.isScanning
                                  ? const Color(0xFFE11900)
                                  : (isDark
                                      ? const Color(0xFFFFFFFF)
                                      : const Color(0xFF000000)),
                              foregroundColor: widget.isScanning
                                  ? const Color(0xFFFFFFFF)
                                  : (isDark
                                      ? const Color(0xFF000000)
                                      : const Color(0xFFFFFFFF)),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: widget.isScanning
                                ? widget.onStopSession
                                : widget.onStartSession,
                            child: Text(
                              widget.isScanning
                                  ? 'Stop (${widget.currentSessionProgress}/${widget.targetSessionScans})'
                                  : 'Record ${widget.targetSessionScans} Scans',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.isScanning)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(8),
                              ),
                              child: SizedBox(
                                height: 2,
                                child: LinearProgressIndicator(
                                  value: widget.targetSessionScans > 0
                                      ? (widget.currentSessionProgress /
                                              widget.targetSessionScans)
                                          .clamp(0.0, 1.0)
                                      : null,
                                  backgroundColor: Colors.white24,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Quick Refresh Button
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: widget.isScanning ? null : widget.onInspectOnly,
                        child: Center(
                          child: Icon(
                            Icons.refresh,
                            size: 22,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.scanStatus,
                style: AppTheme.monoStyle(
                  context,
                  fontSize: 11,
                  color: const Color(0xFF8E8E93),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter Strip (Search + Band Pills)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter SSID or BSSID',
                    prefixIcon: Icon(Icons.search, size: 18),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => apSearchQuery = v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                for (final band in ['All', '2.4', '5', '6'])
                  GestureDetector(
                    onTap: () => setState(() => apBandFilter = band),
                    child: Container(
                      height: 38,
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: apBandFilter == band
                            ? (isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF000000))
                            : containerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        band,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: apBandFilter == band
                              ? (isDark
                                  ? const Color(0xFF000000)
                                  : const Color(0xFFFFFFFF))
                              : (isDark
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF000000)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Flat Hairline Rows for APs
        if (filteredAps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                widget.liveAccessPoints.isEmpty
                    ? 'No live scans yet. Tap refresh or Record.'
                    : 'No matching access points found.',
                style: AppTheme.monoStyle(context, fontSize: 13),
              ),
            ),
          )
        else
          for (int i = 0; i < filteredAps.length; i++) ...[
            _buildFlatApRow(context, filteredAps[i], signalColors),
            Divider(color: dividerLineColor, height: 1),
          ],
      ],
    );
  }

  Widget _buildFlatApRow(
    BuildContext context,
    WiFiAccessPoint ap,
    SignalColors signalColors,
  ) {
    final band = _cleanBand(ap.frequency);
    final signalColor = signalColors.colorForRssi(ap.level);

    return InkWell(
      onTap: () => showApDetailsSheet(context, ap),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: 3px vertical color bar
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: signalColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 12),

            // Middle: SSID + 5GHz & Monospace details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ap.ssid.isEmpty ? '<Hidden SSID>' : ap.ssid,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        band,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ap.bssid} · ${ap.frequency} MHz · ${ap.channelWidth}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right: Large tabular monospace -50 with dBm underneath
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${ap.level}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: signalColor,
                  ),
                ),
                Text(
                  'dBm',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: signalColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
