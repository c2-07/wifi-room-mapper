import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'logic/storage_export.dart';
import 'models/room_models.dart';
import 'tabs/analysis_tab.dart';
import 'tabs/rooms_tab.dart';
import 'tabs/scan_tab.dart';
import 'tabs/settings_tab.dart';
import 'theme/app_theme.dart';
import 'widgets/detail_sheets.dart';

void main() {
  runApp(const RoomMapperApp());
}

class RoomMapperApp extends StatefulWidget {
  const RoomMapperApp({super.key});

  @override
  State<RoomMapperApp> createState() => _RoomMapperAppState();
}

class _RoomMapperAppState extends State<RoomMapperApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default: Dark Mode

  void _updateTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wi-Fi Room Mapper',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: MainShell(themeMode: _themeMode, onThemeChanged: _updateTheme),
    );
  }
}

class MainShell extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const MainShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final WiFiScan wifi = WiFiScan.instance;

  int currentTab = 0; // 0: Scan, 1: Spaces, 2: Verify, 3: System
  List<RoomRecord> rooms = [];
  String? selectedRoomId;

  // Taxonomy & Positions state
  HierarchyLabels labels = HierarchyLabels();
  List<String> customPositions = List<String>.from(StorageExportService.defaultPositions);

  // Scanner & Session state
  List<WiFiAccessPoint> liveAccessPoints = [];
  bool isScanning = false;
  bool cancelSessionRequested = false;
  int currentSessionProgress = 0;
  int targetSessionScans = 5;
  int scanIntervalSeconds = 3;
  String selectedPosition = 'Center';
  String scanStatus = 'Ready to scan.';
  String permissionStatus = 'Checking permissions...';

  // Spaces tab state
  final Set<String> selectedRoomIdsForBulk = {};

  // Verify tab state
  String? analysisRoomAId;
  String? analysisRoomBId;
  int knnKValue = 5;

  @override
  void initState() {
    super.initState();
    _initDataAndPermissions();
  }

  Future<void> _initDataAndPermissions() async {
    await _loadTaxonomy();
    await _loadDataset();
    await _checkPermissions();
  }

  Future<void> _loadTaxonomy() async {
    final loadedLabels = await StorageExportService.loadHierarchyLabels();
    final loadedPositions = await StorageExportService.loadCustomPositions();
    if (!mounted) return;
    setState(() {
      labels = loadedLabels;
      customPositions = loadedPositions;
      if (!customPositions.contains(selectedPosition)) {
        selectedPosition = customPositions.first;
      }
    });
  }

  Future<void> _checkPermissions() async {
    try {
      final canScan = await wifi.canStartScan(askPermissions: false);
      if (!mounted) return;
      setState(() {
        permissionStatus = canScan == CanStartScan.yes
            ? 'Ready (Wi-Fi & Location OK)'
            : 'Unavailable ($canScan) - tap Check to request';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => permissionStatus = 'Permission check error: $e');
    }
  }

  Future<void> _loadDataset() async {
    try {
      final loaded = await StorageExportService.loadDataset();
      if (!mounted) return;
      setState(() {
        rooms = loaded;
        if (rooms.isNotEmpty) {
          selectedRoomId ??= rooms.first.id;
          analysisRoomAId ??= rooms.first.id;
          if (rooms.length > 1) {
            analysisRoomBId ??= rooms[1].id;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => scanStatus = 'Failed to parse saved dataset: $e');
    }
  }

  Future<void> _saveDataset() async {
    await StorageExportService.saveDataset(rooms);
  }

  Future<void> _updateHierarchyLabels(HierarchyLabels newLabels) async {
    setState(() => labels = newLabels);
    await StorageExportService.saveHierarchyLabels(newLabels);
  }

  Future<void> _updateCustomPositions(List<String> newPositions) async {
    setState(() {
      customPositions = newPositions;
      if (!customPositions.contains(selectedPosition)) {
        selectedPosition = customPositions.first;
      }
    });
    await StorageExportService.saveCustomPositions(newPositions);
  }

  Future<List<WiFiAccessPoint>?> _performSingleScan() async {
    final permission = await wifi.canStartScan(askPermissions: true);
    if (permission != CanStartScan.yes) {
      throw Exception(
        'Cannot start scan ($permission). Check Location permission, '
        'Location Services, and Wi-Fi.',
      );
    }

    final resultFuture = wifi.onScannedResultsAvailable.first.timeout(
      const Duration(seconds: 12),
    );

    final started = await wifi.startScan();
    if (!started) {
      final canGet = await wifi.canGetScannedResults(askPermissions: true);
      if (canGet == CanGetScannedResults.yes) {
        return await wifi.getScannedResults();
      }
      throw Exception(
        'OS throttled scan request (Android 4-scans/2-min limit).',
      );
    }

    return await resultFuture;
  }

  Future<void> _runQuickScan() async {
    if (isScanning) return;
    setState(() {
      isScanning = true;
      scanStatus = 'Scanning nearby access points...';
    });

    try {
      final results = await _performSingleScan();
      if (results != null && mounted) {
        final sorted = [...results]..sort((a, b) => b.level.compareTo(a.level));
        setState(() {
          liveAccessPoints = sorted;
          scanStatus = 'Quick scan finished: ${sorted.length} APs visible.';
          permissionStatus = 'Ready (Wi-Fi & Location OK)';
        });
      }
    } on TimeoutException {
      if (mounted) setState(() => scanStatus = 'Scan timed out.');
    } catch (e) {
      if (mounted) setState(() => scanStatus = 'Scan failed: $e');
    } finally {
      if (mounted) setState(() => isScanning = false);
    }
  }

  Future<void> _runMultiScanSession() async {
    if (isScanning) return;
    final targetRoom = rooms.where((r) => r.id == selectedRoomId).firstOrNull;
    if (targetRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select or create a target ${labels.level4.toLowerCase()} first!')),
      );
      return;
    }

    setState(() {
      isScanning = true;
      cancelSessionRequested = false;
      currentSessionProgress = 0;
      scanStatus =
          'Starting session (0/$targetSessionScans) for ${targetRoom.room}...';
    });

    final List<ScanSnapshot> capturedSnapshots = [];
    final sessionStart = DateTime.now().toIso8601String();

    try {
      for (int i = 0; i < targetSessionScans; i++) {
        if (cancelSessionRequested) break;

        setState(() {
          scanStatus =
              'Scanning pass ${i + 1} of $targetSessionScans ($selectedPosition)...';
        });

        final results = await _performSingleScan();
        if (results != null && results.isNotEmpty) {
          final sorted = [...results]
            ..sort((a, b) => b.level.compareTo(a.level));
          final readings = sorted.map(ApReading.fromAccessPoint).toList();
          capturedSnapshots.add(
            ScanSnapshot(
              timestamp: DateTime.now().toIso8601String(),
              readings: readings,
            ),
          );

          if (mounted) {
            setState(() {
              liveAccessPoints = sorted;
              currentSessionProgress = i + 1;
            });
          }
        }

        if (i < targetSessionScans - 1 && !cancelSessionRequested) {
          for (int sec = scanIntervalSeconds; sec > 0; sec--) {
            if (cancelSessionRequested) break;
            if (mounted) {
              setState(() {
                scanStatus =
                    'Pass ${i + 1}/$targetSessionScans saved. Next scan in ${sec}s...';
              });
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      if (capturedSnapshots.isNotEmpty) {
        final session = ScanSession(
          id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          startedAt: sessionStart,
          position: selectedPosition,
          targetScanCount: targetSessionScans,
          intervalSeconds: scanIntervalSeconds,
          snapshots: capturedSnapshots,
        );

        targetRoom.sessions.add(session);
        await _saveDataset();

        if (mounted) {
          setState(() {
            scanStatus = cancelSessionRequested
                ? 'Session stopped early. Saved ${capturedSnapshots.length} scans to ${targetRoom.room}.'
                : 'Completed session! Saved ${capturedSnapshots.length} scans to ${targetRoom.room}.';
          });
        }
      } else {
        if (mounted) {
          setState(() => scanStatus = 'No snapshots captured.');
        }
      }
    } catch (e) {
      if (capturedSnapshots.isNotEmpty) {
        final partialSession = ScanSession(
          id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
          startedAt: sessionStart,
          position: selectedPosition,
          targetScanCount: targetSessionScans,
          intervalSeconds: scanIntervalSeconds,
          snapshots: capturedSnapshots,
        );
        targetRoom.sessions.add(partialSession);
        await _saveDataset();
      }
      if (mounted) {
        setState(() {
          scanStatus =
              'Session interrupted ($e). Saved ${capturedSnapshots.length} completed scans.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isScanning = false;
          cancelSessionRequested = false;
        });
      }
    }
  }

  // ==========================================================================
  // SPACE CRUD & MERGE OPERATIONS
  // ==========================================================================

  Future<void> _showAddOrEditRoomDialog({RoomRecord? existing}) async {
    final level1Ctrl = TextEditingController(
      text: existing?.campus ?? 'IIIT Nagpur',
    );
    final level2Ctrl = TextEditingController(
      text: existing?.building ?? 'Academic Block',
    );
    final level3Ctrl = TextEditingController(
      text: existing?.floor ?? 'Floor 2',
    );
    final spaceCtrl = TextEditingController(
      text: existing?.room ?? '',
    );
    final notesCtrl = TextEditingController(
      text: existing?.notes ?? '',
    );
    bool isCorridor = existing?.isCorridorOrBoundary ?? false;

    final existingLevel1 = rooms.map((r) => r.campus).toSet().toList();
    final existingLevel2 = rooms.map((r) => r.building).toSet().toList();
    final existingLevel3 = rooms.map((r) => r.floor).toSet().toList();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing == null ? 'Add ${labels.level4}' : 'Edit ${labels.level4}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHierarchyField(level1Ctrl, labels.level1, existingLevel1),
                const SizedBox(height: 10),
                _buildHierarchyField(level2Ctrl, labels.level2, existingLevel2),
                const SizedBox(height: 10),
                _buildHierarchyField(level3Ctrl, labels.level3, existingLevel3),
                const SizedBox(height: 10),
                TextField(
                  controller: spaceCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: '${labels.level4} Identifier (e.g. 443 / CSE-201)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (obstacles, routers, capacity)',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Corridor / Outside Boundary Zone'),
                  subtitle: const Text(
                    'Mark as an outside hallway so standing outside doors flags as Outside',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: isCorridor,
                  onChanged: (v) => setDlgState(() => isCorridor = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final c = level1Ctrl.text.trim();
                final b = level2Ctrl.text.trim();
                final f = level3Ctrl.text.trim();
                final r = spaceCtrl.text.trim();
                final n = notesCtrl.text.trim();

                if (c.isEmpty || b.isEmpty || f.isEmpty || r.isEmpty) {
                  return;
                }

                final duplicate = rooms.any(
                  (item) =>
                      item.id != existing?.id &&
                      item.campus.toLowerCase() == c.toLowerCase() &&
                      item.building.toLowerCase() == b.toLowerCase() &&
                      item.floor.toLowerCase() == f.toLowerCase() &&
                      item.room.toLowerCase() == r.toLowerCase(),
                );

                if (duplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'A ${labels.level4.toLowerCase()} with this exact path already exists.',
                      ),
                    ),
                  );
                  return;
                }

                setState(() {
                  if (existing == null) {
                    final newRoom = RoomRecord(
                      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
                      campus: c,
                      building: b,
                      floor: f,
                      room: r,
                      notes: n,
                      isCorridorOrBoundary: isCorridor,
                    );
                    rooms.add(newRoom);
                    selectedRoomId = newRoom.id;
                    analysisRoomAId ??= newRoom.id;
                  } else {
                    existing.campus = c;
                    existing.building = b;
                    existing.floor = f;
                    existing.room = r;
                    existing.notes = n;
                    existing.isCorridorOrBoundary = isCorridor;
                  }
                });

                await _saveDataset();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyField(
    TextEditingController controller,
    String label,
    List<String> suggestions,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suggestions.isEmpty
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (val) => controller.text = val,
                itemBuilder: (_) => suggestions
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
      ),
    );
  }

  Future<void> _deleteRooms(List<String> idsToDelete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${labels.pluralLevel4}?'),
        content: Text(
          'Are you sure you want to permanently delete ${idsToDelete.length} ${labels.pluralLevel4.toLowerCase()} and all scan sessions?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11900),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      rooms.removeWhere((r) => idsToDelete.contains(r.id));
      selectedRoomIdsForBulk.removeAll(idsToDelete);
      if (!rooms.any((r) => r.id == selectedRoomId)) {
        selectedRoomId = rooms.isNotEmpty ? rooms.first.id : null;
      }
      if (!rooms.any((r) => r.id == analysisRoomAId)) {
        analysisRoomAId = rooms.isNotEmpty ? rooms.first.id : null;
      }
      if (!rooms.any((r) => r.id == analysisRoomBId)) {
        analysisRoomBId = rooms.length > 1 ? rooms[1].id : null;
      }
    });
    await _saveDataset();
  }

  Future<void> _mergeSelectedRooms() async {
    if (selectedRoomIdsForBulk.length < 2) return;
    final selectedList = rooms
        .where((r) => selectedRoomIdsForBulk.contains(r.id))
        .toList();
    final primary = selectedList.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Merge ${labels.pluralLevel4}'),
        content: Text(
          'Merge ${selectedList.length} ${labels.pluralLevel4.toLowerCase()} into "${primary.room}" (${primary.building})?\n\n'
          'All scan sessions and notes will be combined without losing raw observations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      for (int i = 1; i < selectedList.length; i++) {
        final other = selectedList[i];
        primary.sessions.addAll(other.sessions);
        if (other.notes.isNotEmpty) {
          primary.notes = primary.notes.isEmpty
              ? other.notes
              : '${primary.notes}\n${other.notes}';
        }
        rooms.removeWhere((r) => r.id == other.id);
      }
      selectedRoomIdsForBulk.clear();
    });

    await _saveDataset();
  }

  Future<void> _exportJson(List<RoomRecord> targetRooms, String prefix) async {
    try {
      final name = await StorageExportService.exportJson(targetRooms, prefix);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $name.json to Downloads')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON export failed: $e')),
      );
    }
  }

  Future<void> _exportCsv(
    List<RoomRecord> targetRooms,
    String prefix, {
    HierarchyLabels? labels,
  }) async {
    try {
      final name = await StorageExportService.exportCsv(
        targetRooms,
        prefix,
        labels: labels,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported $name.csv to Downloads')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV export failed: $e')),
      );
    }
  }

  Future<void> _showImportDialog() async {
    final jsonCtrl = TextEditingController();
    String validationMsg = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Import & Restore JSON Backup'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paste exported JSON backup below. Existing ${labels.pluralLevel4.toLowerCase()} with matching paths will merge sessions without overwriting.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: jsonCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '{ "schemaVersion": 2, "rooms": [ ... ] }',
                  ),
                ),
                if (validationMsg.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    validationMsg,
                    style: const TextStyle(
                      color: Color(0xFFE11900),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final importedRooms =
                      StorageExportService.parseImportedJson(jsonCtrl.text);

                  int addedRooms = 0;
                  int mergedSessions = 0;

                  setState(() {
                    for (final incoming in importedRooms) {
                      final existing = rooms
                          .where(
                            (r) =>
                                r.campus.toLowerCase() ==
                                    incoming.campus.toLowerCase() &&
                                r.building.toLowerCase() ==
                                    incoming.building.toLowerCase() &&
                                r.floor.toLowerCase() ==
                                    incoming.floor.toLowerCase() &&
                                r.room.toLowerCase() ==
                                    incoming.room.toLowerCase(),
                          )
                          .firstOrNull;

                      if (existing == null) {
                        rooms.add(incoming);
                        addedRooms++;
                      } else {
                        final existingIds = existing.sessions
                            .map((s) => s.id)
                            .toSet();
                        for (final s in incoming.sessions) {
                          if (!existingIds.contains(s.id)) {
                            existing.sessions.add(s);
                            mergedSessions++;
                          }
                        }
                      }
                    }
                    if (rooms.isNotEmpty && selectedRoomId == null) {
                      selectedRoomId = rooms.first.id;
                    }
                  });

                  await _saveDataset();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Imported $addedRooms new ${labels.pluralLevel4.toLowerCase()} and merged $mergedSessions scan sessions.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    validationMsg = 'Parse error: $e';
                  });
                }
              },
              child: const Text('Validate & Import'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      ScanTab(
        rooms: rooms,
        labels: labels,
        customPositions: customPositions,
        selectedRoomId: selectedRoomId,
        onRoomSelected: (val) => setState(() => selectedRoomId = val),
        isScanning: isScanning,
        liveAccessPoints: liveAccessPoints,
        scanStatus: scanStatus,
        currentSessionProgress: currentSessionProgress,
        targetSessionScans: targetSessionScans,
        scanIntervalSeconds: scanIntervalSeconds,
        selectedPosition: selectedPosition,
        onPositionChanged: (pos) => setState(() => selectedPosition = pos),
        onTargetScansChanged: (cnt) => setState(() => targetSessionScans = cnt),
        onIntervalChanged: (sec) => setState(() => scanIntervalSeconds = sec),
        onStartSession: _runMultiScanSession,
        onStopSession: () => setState(() => cancelSessionRequested = true),
        onInspectOnly: _runQuickScan,
        onShowAddRoomDialog: () => _showAddOrEditRoomDialog(),
      ),
      RoomsTab(
        rooms: rooms,
        labels: labels,
        selectedRoomIdsForBulk: selectedRoomIdsForBulk,
        onToggleBulkSelection: (id, selected) {
          setState(() {
            if (selected) {
              selectedRoomIdsForBulk.add(id);
            } else {
              selectedRoomIdsForBulk.remove(id);
            }
          });
        },
        onClearBulkSelection: () =>
            setState(() => selectedRoomIdsForBulk.clear()),
        onMergeSelected: _mergeSelectedRooms,
        onDeleteRooms: _deleteRooms,
        onExportJson: _exportJson,
        onExportCsv: _exportCsv,
        onShowAddOrEditRoomDialog: _showAddOrEditRoomDialog,
        onScanInRoom: (roomId) {
          HapticFeedback.selectionClick();
          setState(() {
            selectedRoomId = roomId;
            currentTab = 0; // Navigate to Scan tab
          });
        },
        onShowRoomHistory: (room) => showRoomHistorySheet(
          context: context,
          room: room,
          labels: labels,
          onDatasetChanged: () {
            setState(() {});
            _saveDataset();
          },
          onExportJson: _exportJson,
          onExportCsv: _exportCsv,
        ),
      ),
      AnalysisTab(
        rooms: rooms,
        labels: labels,
        analysisRoomAId: analysisRoomAId,
        analysisRoomBId: analysisRoomBId,
        onRoomAChanged: (id) => setState(() => analysisRoomAId = id),
        onRoomBChanged: (id) => setState(() => analysisRoomBId = id),
        knnKValue: knnKValue,
        onKnnKChanged: (k) => setState(() => knnKValue = k),
        liveAccessPoints: liveAccessPoints,
        isScanning: isScanning,
        onRunQuickScan: _runQuickScan,
        onShowAddRoomDialog: () => _showAddOrEditRoomDialog(),
      ),
      SettingsTab(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeChanged,
        onExportJson: () => _exportJson(rooms, 'wifi_room_mapper_backup'),
        onExportCsv: () => _exportCsv(rooms, 'wifi_room_mapper_flat', labels: labels),
        onShowImportDialog: _showImportDialog,
        rooms: rooms,
        labels: labels,
        customPositions: customPositions,
        onLabelsChanged: _updateHierarchyLabels,
        onPositionsChanged: _updateCustomPositions,
      ),
    ];

    final hairlineColor = isDark ? const Color(0xFF222222) : const Color(0xFFE5E5E5);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Room Mapper'),
        centerTitle: false,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<int>(currentTab),
          child: pages[currentTab],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: hairlineColor, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: currentTab,
          indicatorColor: Colors.transparent,
          backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
          onDestinationSelected: (idx) {
            HapticFeedback.selectionClick();
            setState(() => currentTab = idx);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: const Icon(Icons.layers_outlined),
              selectedIcon: const Icon(Icons.layers),
              label: labels.pluralLevel4,
            ),
            const NavigationDestination(
              icon: Icon(Icons.compass_calibration_outlined),
              selectedIcon: Icon(Icons.compass_calibration),
              label: 'Verify',
            ),
            const NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
              label: 'System',
            ),
          ],
        ),
      ),
    );
  }
}
