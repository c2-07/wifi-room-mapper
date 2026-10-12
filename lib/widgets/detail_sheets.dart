import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../logic/fingerprint_stats.dart';
import '../models/room_models.dart';
import '../theme/app_theme.dart';

String getBandLabel(int freqMHz) {
  if (freqMHz >= 5925) return '6 GHz';
  if (freqMHz >= 4900) return '5 GHz';
  if (freqMHz >= 2400) return '2.4 GHz';
  return 'Other';
}

String getSignalLabel(int rssi) {
  if (rssi >= -60) return 'Excellent';
  if (rssi >= -70) return 'Good';
  if (rssi >= -80) return 'Fair';
  return 'Weak';
}

void showApDetailsSheet(BuildContext context, WiFiAccessPoint ap) {
  final signalColors =
      Theme.of(context).extension<SignalColors>() ?? AppTheme.darkSignalColors;
  final band = getBandLabel(ap.frequency);
  final signalColor = signalColors.colorForRssi(ap.level);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ap.ssid.isEmpty ? '<Hidden SSID>' : ap.ssid,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                band,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(
            ctx,
            'BSSID',
            ap.bssid,
            isMono: true,
          ),
          _detailRow(
            ctx,
            'Signal Strength',
            '${ap.level} dBm (${getSignalLabel(ap.level)})',
            valueColor: signalColor,
            isMono: true,
          ),
          _detailRow(
            ctx,
            'Frequency',
            '${ap.frequency} MHz ($band)',
            isMono: true,
          ),
          _detailRow(ctx, 'Channel Width', '${ap.channelWidth}'),
          _detailRow(ctx, 'Wi-Fi Standard', '${ap.standard}'),
          _detailRow(ctx, 'Capabilities', ap.capabilities),
          _detailRow(
            ctx,
            'Center Frequency 0',
            '${ap.centerFrequency0 ?? "Unknown"} MHz',
            isMono: true,
          ),
          _detailRow(
            ctx,
            'Center Frequency 1',
            '${ap.centerFrequency1 ?? "Unknown"} MHz',
            isMono: true,
          ),
          _detailRow(ctx, 'Passpoint', '${ap.isPasspoint}'),
          _detailRow(ctx, 'Venue', ap.venueName ?? 'Unknown'),
          _detailRow(ctx, 'Operator', ap.operatorFriendlyName ?? 'Unknown'),
        ],
      ),
    ),
  );
}

Widget _detailRow(
  BuildContext context,
  String label,
  String value, {
  bool isMono = false,
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: isMono
                ? AppTheme.monoStyle(
                    context,
                    fontSize: 13,
                    weight: FontWeight.w600,
                    color: valueColor,
                  )
                : TextStyle(color: valueColor),
          ),
        ),
      ],
    ),
  );
}

void showRoomHistorySheet({
  required BuildContext context,
  required RoomRecord room,
  HierarchyLabels? labels,
  required VoidCallback onDatasetChanged,
  required void Function(List<RoomRecord> rooms, String prefix) onExportJson,
  required void Function(List<RoomRecord> rooms, String prefix) onExportCsv,
}) {
  final l4 = labels?.level4 ?? 'Space';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final quality = evaluateRoomQuality(room);
        final signalColors =
            Theme.of(ctx).extension<SignalColors>() ?? AppTheme.darkSignalColors;
        final qualityColor = signalColors.colorForQuality(quality.score);

        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (_, scrollCtrl) => ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                room.room,
                                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (room.isCorridorOrBoundary) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'BOUNDARY',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            room.fullPath,
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: qualityColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${quality.score}% · ${quality.label}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: qualityColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (room.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Notes: ${room.notes}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (quality.warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF222222),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in quality.warnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $w',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFFFC043),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Scan Sessions (${room.sessions.length})',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () => onExportJson([room], room.room),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(60, 32),
                          ),
                          child: const Text('JSON'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.tonal(
                          onPressed: () => onExportCsv([room], room.room),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(60, 32),
                          ),
                          child: const Text('CSV'),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (room.sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No sessions recorded for this ${l4.toLowerCase()} yet.',
                        style: AppTheme.monoStyle(ctx, fontSize: 13),
                      ),
                    ),
                  ),
                for (final s in room.sessions.reversed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: Text(
                        'Position: ${s.position} · ${s.snapshots.length} scan(s)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Started: ${s.startedAt.replaceFirst('T', ' ').split('.').first}',
                        style: AppTheme.monoStyle(ctx, fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: const Color(0xFFE11900),
                        onPressed: () {
                          room.sessions.removeWhere((x) => x.id == s.id);
                          setSheetState(() {});
                          onDatasetChanged();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
