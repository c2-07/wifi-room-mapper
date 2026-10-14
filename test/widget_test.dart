import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:room_mapper/main.dart';
import 'package:room_mapper/models/room_models.dart';
import 'package:room_mapper/tabs/analysis_tab.dart';
import 'package:room_mapper/tabs/rooms_tab.dart';
import 'package:room_mapper/tabs/scan_tab.dart';
import 'package:room_mapper/tabs/settings_tab.dart';
import 'package:room_mapper/theme/app_theme.dart';

void main() {
  final testLabels = HierarchyLabels(
    level1: 'Site',
    level2: 'Block',
    level3: 'Level',
    level4: 'Space',
  );

  final testPositions = ['Center', 'Entry', 'Window', 'Wall L', 'Wall R', 'Corridor'];

  final sampleRooms = [
    RoomRecord(
      id: 'room_1',
      campus: 'IIIT Nagpur',
      building: 'Hostel Block A',
      floor: 'Floor 4',
      room: '443',
      notes: 'Near central window',
      isFavorite: true,
      isCorridorOrBoundary: false,
      sessions: [
        ScanSession(
          id: 's1',
          startedAt: '2026-10-14T05:00:00.000',
          position: 'Center',
          targetScanCount: 3,
          intervalSeconds: 3,
          snapshots: [
            ScanSnapshot(
              timestamp: '2026-10-14T05:00:01.000',
              readings: [
                ApReading(
                  ssid: 'IIITN_Staff_WiFi_Secure',
                  bssid: 'aa:bb:cc:dd:ee:01',
                  rssi: -58,
                  frequency: 5180,
                  capabilities: 'WPA2-PSK',
                  standard: 'WiFiStandard.ac',
                  channelWidth: 'WiFiChannelWidth.mhz80',
                  timestampMicros: 1000,
                ),
                ApReading(
                  ssid: 'IIITN_Student_Campus',
                  bssid: 'aa:bb:cc:dd:ee:02',
                  rssi: -72,
                  frequency: 2437,
                  capabilities: 'WPA2-PSK',
                  standard: 'WiFiStandard.n',
                  channelWidth: 'WiFiChannelWidth.mhz20',
                  timestampMicros: 1000,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    RoomRecord(
      id: 'room_2',
      campus: 'IIIT Nagpur',
      building: 'Hostel Block A',
      floor: 'Floor 4',
      room: 'Corridor 4F',
      notes: 'Hallway outside room 443',
      isCorridorOrBoundary: true,
      sessions: [
        ScanSession(
          id: 's2',
          startedAt: '2026-10-14T05:10:00.000',
          position: 'Corridor',
          targetScanCount: 3,
          intervalSeconds: 3,
          snapshots: [
            ScanSnapshot(
              timestamp: '2026-10-14T05:10:01.000',
              readings: [
                ApReading(
                  ssid: 'IIITN_Staff_WiFi_Secure',
                  bssid: 'aa:bb:cc:dd:ee:01',
                  rssi: -78,
                  frequency: 5180,
                  capabilities: 'WPA2-PSK',
                  standard: 'WiFiStandard.ac',
                  channelWidth: 'WiFiChannelWidth.mhz80',
                  timestampMicros: 1000,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  Widget buildTestWrapper(Widget child, {Size size = const Size(360, 640)}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('ScanTab renders without overflow on 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestWrapper(
        ScanTab(
          rooms: sampleRooms,
          labels: testLabels,
          customPositions: testPositions,
          selectedRoomId: 'room_1',
          onRoomSelected: (_) {},
          isScanning: false,
          liveAccessPoints: const [],
          scanStatus: 'Ready to scan.',
          currentSessionProgress: 0,
          targetSessionScans: 5,
          scanIntervalSeconds: 3,
          selectedPosition: 'Center',
          onPositionChanged: (_) {},
          onTargetScansChanged: (_) {},
          onIntervalChanged: (_) {},
          onStartSession: () {},
          onStopSession: () {},
          onInspectOnly: () {},
          onShowAddRoomDialog: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Record 5 Scans'), findsOneWidget);
    expect(find.text('5x · 3s'), findsOneWidget);
  });

  testWidgets('RoomsTab (Spaces) with bulk selection renders on 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestWrapper(
        RoomsTab(
          rooms: sampleRooms,
          labels: testLabels,
          selectedRoomIdsForBulk: {'room_1', 'room_2'},
          onToggleBulkSelection: (id, isSelected) {},
          onClearBulkSelection: () {},
          onMergeSelected: () {},
          onDeleteRooms: (_) {},
          onExportJson: (rooms, prefix) {},
          onExportCsv: (rooms, prefix) {},
          onShowAddOrEditRoomDialog: ({existing}) {},
          onScanInRoom: (_) {},
          onShowRoomHistory: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('443'), findsOneWidget);
    expect(find.text('BOUNDARY'), findsOneWidget);
  });

  testWidgets('AnalysisTab (Verify) with boundary predictor renders on 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestWrapper(
        AnalysisTab(
          rooms: sampleRooms,
          labels: testLabels,
          analysisRoomAId: 'room_1',
          analysisRoomBId: 'room_2',
          onRoomAChanged: (_) {},
          onRoomBChanged: (_) {},
          knnKValue: 5,
          onKnnKChanged: (_) {},
          liveAccessPoints: const [],
          isScanning: false,
          onRunQuickScan: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Locate sub-view
    expect(find.text('READY TO LOCATE'), findsOneWidget);
    expect(find.text('Scan & Locate'), findsOneWidget);

    // Switch to Stability sub-view
    await tester.tap(find.text('Stability'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quality'), findsOneWidget);

    // Switch to Compare sub-view
    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shared APs'), findsOneWidget);
  });

  testWidgets('SettingsTab (System) renders on 360px screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildTestWrapper(
        SettingsTab(
          themeMode: ThemeMode.dark,
          onThemeChanged: (_) {},
          onExportJson: () {},
          onExportCsv: () {},
          onShowImportDialog: () {},
          rooms: sampleRooms,
          labels: testLabels,
          customPositions: testPositions,
          onLabelsChanged: (_) {},
          onPositionsChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TAXONOMY & POSITIONS'), findsOneWidget);
    expect(find.text('Hierarchy Labels'), findsOneWidget);
    expect(find.text('Sampling Positions'), findsOneWidget);
    expect(find.text('Export JSON Backup'), findsOneWidget);
  });

  testWidgets('RoomMapperApp smoke test and navigation across 4 tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const RoomMapperApp());
    await tester.pumpAndSettle();

    expect(find.text('Wi-Fi Room Mapper'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Tab 0: Scan
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Filter SSID or BSSID'), findsOneWidget);

    // Tab 1: Spaces
    await tester.tap(find.byIcon(Icons.layers_outlined));
    await tester.pumpAndSettle();
    expect(find.text('+ New'), findsOneWidget);

    // Tab 2: Verify
    await tester.tap(find.byIcon(Icons.compass_calibration_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Locate'), findsOneWidget);
    expect(find.text('Stability'), findsOneWidget);
    expect(find.text('Compare'), findsOneWidget);

    // Tab 3: System
    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();
    expect(find.text('TAXONOMY & POSITIONS'), findsOneWidget);
    expect(find.text('DATASET'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
  });
}
