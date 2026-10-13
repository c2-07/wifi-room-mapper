import 'package:flutter/material.dart';

import '../logic/fingerprint_stats.dart';
import '../models/room_models.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_card.dart';

class HomeTab extends StatelessWidget {
  final List<RoomRecord> rooms;
  final String permissionStatus;
  final VoidCallback onRequestPermissions;
  final void Function(int tabIndex) onNavigateToTab;
  final void Function(String roomId) onSelectRoomForScan;
  final VoidCallback onShowAddRoomDialog;
  final VoidCallback onExportAllJson;
  final void Function(RoomRecord room) onShowRoomHistory;
  final void Function(RoomRecord room) onToggleFavorite;

  const HomeTab({
    super.key,
    required this.rooms,
    required this.permissionStatus,
    required this.onRequestPermissions,
    required this.onNavigateToTab,
    required this.onSelectRoomForScan,
    required this.onShowAddRoomDialog,
    required this.onExportAllJson,
    required this.onShowRoomHistory,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.lightSignalColors;
    final isReady = permissionStatus.startsWith('Ready');

    final campuses = rooms.map((r) => r.campus).toSet().length;
    final buildings =
        rooms.map((r) => '${r.campus}|${r.building}').toSet().length;
    final floors =
        rooms.map((r) => '${r.campus}|${r.building}|${r.floor}').toSet().length;
    final totalSessions = rooms.fold(0, (sum, r) => sum + r.sessions.length);
    final totalSnapshots = rooms.fold(0, (sum, r) => sum + r.totalScans);

    final favoriteRooms = rooms.where((r) => r.isFavorite).toList();
    final recentRooms = [...rooms]
      ..sort((a, b) => b.lastScannedAt.compareTo(a.lastScannedAt));

    final bannerBg = isReady
        ? signalColors.excellent.withValues(alpha: 0.1)
        : signalColors.fair.withValues(alpha: 0.1);
    final bannerIconColor =
        isReady ? signalColors.excellent : signalColors.fair;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Banner
        StaggeredEntry(
          index: 0,
          child: Card(
            color: bannerBg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: bannerIconColor.withValues(alpha: 0.2),
                    child: Icon(
                      isReady
                          ? Icons.security_update_good
                          : Icons.warning_amber_rounded,
                      color: bannerIconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System & Permission Status',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          permissionStatus,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRequestPermissions,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Check'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bento Grid Overview
        StaggeredEntry(
          index: 1,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Dataset Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${rooms.length} registered rooms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        StaggeredEntry(
          index: 2,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.92,
            children: [
              _bentoMetricCard(
                context,
                label: 'Campuses',
                value: campuses,
                icon: Icons.domain,
                color: Theme.of(context).colorScheme.primary,
              ),
              _bentoMetricCard(
                context,
                label: 'Buildings',
                value: buildings,
                icon: Icons.apartment,
                color: Theme.of(context).colorScheme.secondary,
              ),
              _bentoMetricCard(
                context,
                label: 'Floors',
                value: floors,
                icon: Icons.layers,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              _bentoMetricCard(
                context,
                label: 'Rooms',
                value: rooms.length,
                icon: Icons.meeting_room,
                color: signalColors.good,
              ),
              _bentoMetricCard(
                context,
                label: 'Sessions',
                value: totalSessions,
                icon: Icons.repeat,
                color: signalColors.band24Ghz,
              ),
              _bentoMetricCard(
                context,
                label: 'Total Scans',
                value: totalSnapshots,
                icon: Icons.radar,
                color: signalColors.band6Ghz,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Quick Actions
        StaggeredEntry(
          index: 3,
          child: Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        StaggeredEntry(
          index: 4,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onShowAddRoomDialog,
                icon: const Icon(Icons.add),
                label: const Text('New Room'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onNavigateToTab(1),
                icon: const Icon(Icons.wifi_find),
                label: const Text('Go to Scanner'),
              ),
              OutlinedButton.icon(
                onPressed: onExportAllJson,
                icon: const Icon(Icons.download),
                label: const Text('Export All JSON'),
              ),
            ],
          ),
        ),

        // Pinned Classrooms
        if (favoriteRooms.isNotEmpty) ...[
          const SizedBox(height: 24),
          StaggeredEntry(
            index: 5,
            child: Text(
              'Pinned Classrooms',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < favoriteRooms.length; i++)
            StaggeredEntry(
              index: 6 + i,
              child: _roomSummaryCard(context, favoriteRooms[i]),
            ),
        ],

        // Recent Rooms
        const SizedBox(height: 24),
        StaggeredEntry(
          index: 7,
          child: Text(
            'Recent Rooms',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (recentRooms.isEmpty)
          const StaggeredEntry(
            index: 8,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No rooms created yet. Tap "New Room" to start building your campus hierarchy.',
                  ),
                ),
              ),
            ),
          )
        else
          for (int i = 0; i < recentRooms.take(5).length; i++)
            StaggeredEntry(
              index: 8 + i,
              child: _roomSummaryCard(context, recentRooms[i]),
            ),
      ],
    );
  }

  Widget _bentoMetricCard(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return PressableCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: value.toDouble()),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, val, _) => Text(
                  '${val.round()}',
                  style: AppTheme.monoStyle(
                    context,
                    fontSize: 22,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roomSummaryCard(BuildContext context, RoomRecord r) {
    final quality = evaluateRoomQuality(r);
    final signalColors =
        Theme.of(context).extension<SignalColors>() ?? AppTheme.lightSignalColors;
    final qualityColor = signalColors.colorForQuality(quality.score);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => onShowRoomHistory(r),
        leading: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: quality.score / 100,
                strokeWidth: 3.5,
                backgroundColor: qualityColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(qualityColor),
              ),
              Text(
                '${quality.score}',
                style: AppTheme.monoStyle(
                  context,
                  fontSize: 10,
                  weight: FontWeight.bold,
                  color: qualityColor,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                r.room,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                r.isFavorite ? Icons.star : Icons.star_border,
                color: r.isFavorite ? Colors.amber : null,
                size: 20,
              ),
              onPressed: () => onToggleFavorite(r),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.building} · ${r.floor}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${r.sessions.length} sessions · ${r.totalScans} scans · Quality: ${quality.label}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () => onSelectRoomForScan(r.id),
          child: const Text('Scan Here'),
        ),
      ),
    );
  }
}
