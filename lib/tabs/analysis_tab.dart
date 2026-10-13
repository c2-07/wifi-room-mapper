import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../logic/fingerprint_stats.dart';
import '../logic/room_predictor.dart';
import '../models/room_models.dart';
import '../theme/app_theme.dart';

class AnalysisTab extends StatefulWidget {
  final List<RoomRecord> rooms;
  final HierarchyLabels labels;
  final String? analysisRoomAId;
  final String? analysisRoomBId;
  final ValueChanged<String?> onRoomAChanged;
  final ValueChanged<String?> onRoomBChanged;
  final int knnKValue;
  final ValueChanged<int> onKnnKChanged;
  final List<WiFiAccessPoint> liveAccessPoints;
  final bool isScanning;
  final VoidCallback onRunQuickScan;
  final VoidCallback? onShowAddRoomDialog;

  const AnalysisTab({
    super.key,
    required this.rooms,
    required this.labels,
    required this.analysisRoomAId,
    required this.analysisRoomBId,
    required this.onRoomAChanged,
    required this.onRoomBChanged,
    required this.knnKValue,
    required this.onKnnKChanged,
    required this.liveAccessPoints,
    required this.isScanning,
    required this.onRunQuickScan,
    this.onShowAddRoomDialog,
  });

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  int _selectedSubTab = 0; // 0: Locate, 1: Stability, 2: Compare

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF121212) : const Color(0xFFF6F6F6);
    final selectedThumbColor =
        isDark ? const Color(0xFF262626) : const Color(0xFFFFFFFF);
    final textSecondary =
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF545454);
    final textPrimary = isDark ? Colors.white : Colors.black;

    final roomA = widget.rooms
            .where((r) => r.id == widget.analysisRoomAId)
            .firstOrNull ??
        (widget.rooms.isNotEmpty ? widget.rooms.first : null);
    final roomB = widget.rooms
        .where((r) => r.id == widget.analysisRoomBId)
        .firstOrNull;

    return Column(
      children: [
        // Top 3-way Flat Segmented Switcher
        Container(
          height: 38,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildSegmentPill('Locate', 0, selectedThumbColor, textPrimary, textSecondary),
              _buildSegmentPill('Stability', 1, selectedThumbColor, textPrimary, textSecondary),
              _buildSegmentPill('Compare', 2, selectedThumbColor, textPrimary, textSecondary),
            ],
          ),
        ),

        // Subviews
        Expanded(
          child: _selectedSubTab == 0
              ? _buildLocateSubView(context, isDark, surfaceColor, textSecondary, textPrimary)
              : _selectedSubTab == 1
                  ? _buildStabilitySubView(context, roomA, isDark, surfaceColor, textSecondary, textPrimary)
                  : _buildCompareSubView(context, roomA, roomB, isDark, surfaceColor, textSecondary, textPrimary),
        ),
      ],
    );
  }

  Widget _buildSegmentPill(
    String label,
    int index,
    Color selectedThumbColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isSelected = _selectedSubTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSubTab = index),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? selectedThumbColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? textPrimary : textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // SUB-VIEW 1: LOCATE (Boundary-Aware Live Predictor)
  // ==========================================================================
  Widget _buildLocateSubView(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color textSecondary,
    Color textPrimary,
  ) {
    final verdict = evaluateLivePosition(
      widget.liveAccessPoints,
      widget.rooms,
      k: widget.knnKValue,
    );

    final dividerColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5);
    final containerColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFEEEEEE);

    Color statusColor;
    String statusDot;
    String statusLabel;

    switch (verdict.status) {
      case PredictionStatus.confidentInside:
        statusColor = const Color(0xFF05944F);
        statusDot = '●';
        statusLabel = 'CONFIDENT INSIDE';
        break;
      case PredictionStatus.wallBoundary:
        statusColor = const Color(0xFFFFC043);
        statusDot = '▲';
        statusLabel = 'SHARED WALL BOUNDARY';
        break;
      case PredictionStatus.corridorOrOutside:
        statusColor = const Color(0xFFE11900);
        statusDot = '■';
        statusLabel = 'OUTSIDE / CORRIDOR';
        break;
      case PredictionStatus.noData:
        statusColor = const Color(0xFF8E8E93);
        statusDot = '○';
        statusLabel = 'READY TO LOCATE';
        break;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Top Hero Block (20px padding)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow Status Line
              Row(
                children: [
                  Text(
                    statusDot,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Headline (30px bold)
              Text(
                verdict.headline,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Monospace Telemetry
              Text(
                verdict.explanation,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action Row: Rectangular Scan & Locate Button + [k=3 | k=5 | k=7]
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: widget.isScanning ? null : widget.onRunQuickScan,
                  child: Text(
                    widget.isScanning ? 'Scanning...' : 'Scan & Locate',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Compact k-toggle
            Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  for (final k in [3, 5, 7])
                    GestureDetector(
                      onTap: () => widget.onKnnKChanged(k),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: widget.knnKValue == k
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'k=$k',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.knnKValue == k
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
        const SizedBox(height: 16),

        // Candidate List Section Header
        if (verdict.rankedRooms.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'CANDIDATE SPACES (${verdict.rankedRooms.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: textSecondary,
              ),
            ),
          ),
          for (int i = 0; i < verdict.rankedRooms.length; i++) ...[
            _buildCandidateRow(
              context,
              i + 1,
              verdict.rankedRooms[i],
              widget.knnKValue,
              isDark,
              containerColor,
              textSecondary,
              textPrimary,
            ),
            Divider(color: dividerColor, height: 1),
          ],
        ],
      ],
    );
  }

  Widget _buildCandidateRow(
    BuildContext context,
    int rank,
    RoomPredictionMatch match,
    int k,
    bool isDark,
    Color containerColor,
    Color textSecondary,
    Color textPrimary,
  ) {
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.darkSignalColors;
    final matchScore = (match.weightedCosine * 100).clamp(0.0, 100.0);
    final scoreColor = signalColors.colorForQuality(matchScore.round());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Rank + Room name + Closest Position
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#$rank  ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textSecondary,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${match.room.room} (Near ${match.closestPosition})',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '5GHz APs: ${match.matched5GhzBssids} · RMSE: ${match.weightedRmse.toStringAsFixed(1)} dB · Votes: ${match.knnVotes}/$k',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFF666666),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Right: Bold tabular monospace %
          Text(
            '${matchScore.toStringAsFixed(1)}%',
            style: TextStyle(
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUB-VIEW 2: STABILITY (Per-BSSID Range)
  // ==========================================================================
  Widget _buildStabilitySubView(
    BuildContext context,
    RoomRecord? roomA,
    bool isDark,
    Color surfaceColor,
    Color textSecondary,
    Color textPrimary,
  ) {
    if (roomA == null) {
      return Center(
        child: Text(
          'Select or create a ${widget.labels.level4.toLowerCase()} first.',
          style: AppTheme.monoStyle(context, fontSize: 13),
        ),
      );
    }

    final statsA = computeRoomStats(roomA);
    final qualityA = evaluateRoomQuality(roomA);
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.darkSignalColors;
    final dividerColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5);

    final positions = roomA.sessions.map((s) => s.position).toSet();
    final hasFewPositions = positions.length < 2 && roomA.sessions.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Top Flat Selector
        DropdownButtonFormField<String>(
          key: ValueKey('stability_space_${roomA.id}'),
          isExpanded: true,
          initialValue: widget.rooms.any((r) => r.id == roomA.id) ? roomA.id : null,
          decoration: InputDecoration(
            hintText: 'Inspect ${widget.labels.level4}...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            isDense: true,
          ),
          items: widget.rooms
              .map(
                (r) => DropdownMenuItem(
                  value: r.id,
                  child: Text(
                    '${r.room} · ${r.building} (${r.floor})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => widget.onRoomAChanged(v),
        ),
        const SizedBox(height: 10),

        // Inline Summary Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${qualityA.score}% Quality  ·  ${roomA.totalScans} Scans  ·  ${statsA.length} BSSIDs',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              if (hasFewPositions) ...[
                const SizedBox(height: 4),
                Text(
                  '⚠ Only 1 position sampled (${positions.first}). Capture more positions for boundary accuracy.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: signalColors.fair,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Compact Hairline BSSID Rows
        if (statsA.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No scan observations recorded for ${roomA.room} yet.',
                style: AppTheme.monoStyle(context, fontSize: 12),
              ),
            ),
          )
        else
          for (final s in statsA) ...[
            _buildBssidStabilityRow(context, s, signalColors, textSecondary, textPrimary),
            Divider(color: dividerColor, height: 1),
          ],
      ],
    );
  }

  Widget _buildBssidStabilityRow(
    BuildContext context,
    BssidStats s,
    SignalColors signalColors,
    Color textSecondary,
    Color textPrimary,
  ) {
    final meanColor = signalColors.colorForRssi(s.mean.round());
    // Normalize -100 to -30 dBm
    double norm(double v) => ((v - (-100.0)) / 70.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1: SSID (15px bold) + 22:39:54... (12px mono #666) + 100% vis
          Row(
            children: [
              Flexible(
                child: Text(
                  s.ssid.isEmpty ? '<Hidden SSID>' : s.ssid,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.bssid,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
              const Spacer(),
              Text(
                '${(s.visibilityRatio * 100).round()}%',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Line 2: Clean 4px track bar showing min..max range bar + mean dot, with -57.4 dBm (σ 2.7) right aligned
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    final leftPx = norm(s.minRssi.toDouble()) * barWidth;
                    final rightPx = norm(s.maxRssi.toDouble()) * barWidth;
                    final meanPx = (norm(s.mean) * barWidth).clamp(0.0, barWidth);
                    final spanWidth = (rightPx - leftPx).clamp(3.0, barWidth);

                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track
                        Container(
                          height: 4,
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Min-Max Span
                        Positioned(
                          left: leftPx,
                          child: Container(
                            height: 4,
                            width: spanWidth,
                            decoration: BoxDecoration(
                              color: meanColor.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Mean dot (6px)
                        Positioned(
                          left: (meanPx - 3).clamp(0.0, barWidth - 6),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: meanColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${s.mean.toStringAsFixed(1)} dBm (σ ${s.stdDev.toStringAsFixed(1)})',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: meanColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUB-VIEW 3: COMPARE (Space A vs Space B)
  // ==========================================================================
  Widget _buildCompareSubView(
    BuildContext context,
    RoomRecord? roomA,
    RoomRecord? roomB,
    bool isDark,
    Color surfaceColor,
    Color textSecondary,
    Color textPrimary,
  ) {
    if (widget.rooms.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Need at least 2 ${widget.labels.pluralLevel4.toLowerCase()} to compare.',
                style: AppTheme.monoStyle(context, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (widget.onShowAddRoomDialog != null)
                FilledButton(
                  onPressed: widget.onShowAddRoomDialog,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(140, 40),
                  ),
                  child: Text('+ Add ${widget.labels.level4}'),
                ),
            ],
          ),
        ),
      );
    }

    final mapA = roomA != null
        ? {for (final s in computeRoomStats(roomA)) s.bssid: s}
        : <String, BssidStats>{};
    final mapB = roomB != null
        ? {for (final s in computeRoomStats(roomB)) s.bssid: s}
        : <String, BssidStats>{};

    final sharedBssids = mapA.keys.where((k) => mapB.containsKey(k)).toList();
    final dividerColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5);
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.darkSignalColors;

    double meanAbsDiff = 0;
    if (sharedBssids.isNotEmpty) {
      double sum = 0;
      for (final b in sharedBssids) {
        sum += (mapA[b]!.mean - mapB[b]!.mean).abs();
      }
      meanAbsDiff = sum / sharedBssids.length;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Two flat side-by-side selectors
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('compare_a_${roomA?.id}'),
                isExpanded: true,
                initialValue: roomA?.id,
                decoration: InputDecoration(
                  hintText: '${widget.labels.level4} A',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: widget.rooms
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.room, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => widget.onRoomAChanged(v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('compare_b_${roomB?.id}'),
                isExpanded: true,
                initialValue: roomB?.id,
                decoration: InputDecoration(
                  hintText: 'Select...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                items: widget.rooms
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.room, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => widget.onRoomBChanged(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (roomA == null || roomB == null || roomA.id == roomB.id)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Select two different ${widget.labels.pluralLevel4.toLowerCase()} to compare.',
                style: AppTheme.monoStyle(context, fontSize: 13),
              ),
            ),
          )
        else ...[
          // Summary Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${sharedBssids.length} Shared APs · Mean Δ ${meanAbsDiff.toStringAsFixed(1)} dBm',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Shared BSSID Delta Rows
          for (final bssid in sharedBssids) ...[
            _buildDeltaRow(
              context,
              roomA.room,
              roomB.room,
              mapA[bssid]!,
              mapB[bssid]!,
              signalColors,
              textSecondary,
              textPrimary,
            ),
            Divider(color: dividerColor, height: 1),
          ],
        ],
      ],
    );
  }

  Widget _buildDeltaRow(
    BuildContext context,
    String labelA,
    String labelB,
    BssidStats a,
    BssidStats b,
    SignalColors signalColors,
    Color textSecondary,
    Color textPrimary,
  ) {
    final diff = (a.mean - b.mean).abs();
    final diffColor = diff >= 6.0 ? signalColors.excellent : signalColors.fair;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  a.ssid.isEmpty ? a.bssid : a.ssid,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Text(
                'Δ ${diff.toStringAsFixed(1)} dB',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: diffColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 14,
            runSpacing: 2,
            children: [
              Text(
                '$labelA: ${a.mean.toStringAsFixed(1)} dBm',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
              Text(
                '$labelB: ${b.mean.toStringAsFixed(1)} dBm',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
