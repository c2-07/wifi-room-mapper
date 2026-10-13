import 'package:flutter_test/flutter_test.dart';
import 'package:room_mapper/logic/room_predictor.dart';
import 'package:room_mapper/models/room_models.dart';
import 'package:wifi_scan/wifi_scan.dart';

// Minimal mock WiFiAccessPoint for testing evaluateLivePosition
class TestAccessPoint implements WiFiAccessPoint {
  @override
  final String bssid;
  @override
  final String ssid;
  @override
  final int level;
  @override
  final int frequency;

  TestAccessPoint({
    required this.bssid,
    required this.ssid,
    required this.level,
    required this.frequency,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HierarchyLabels model tests', () {
    test('Default values and serialization', () {
      final labels = HierarchyLabels();
      expect(labels.level1, 'Site');
      expect(labels.level2, 'Block');
      expect(labels.level3, 'Level');
      expect(labels.level4, 'Space');
      expect(labels.pluralLevel4, 'Spaces');

      final json = labels.toJson();
      final fromJson = HierarchyLabels.fromJson(json);
      expect(fromJson.level1, 'Site');
      expect(fromJson.level4, 'Space');
    });

    test('Custom taxonomy values', () {
      final labels = HierarchyLabels(
        level1: 'Campus',
        level2: 'Wing',
        level3: 'Floor',
        level4: 'Room',
      );
      expect(labels.pluralLevel4, 'Rooms');
      final json = labels.toJson();
      final fromJson = HierarchyLabels.fromJson(json);
      expect(fromJson.level1, 'Campus');
      expect(fromJson.level4, 'Room');
    });
  });

  group('RoomRecord corridor flag test', () {
    test('isCorridorOrBoundary default and serialization', () {
      final room = RoomRecord(
        id: 'r1',
        campus: 'IIIT Nagpur',
        building: 'Block A',
        floor: 'Floor 1',
        room: 'Corridor 101',
        isCorridorOrBoundary: true,
      );
      expect(room.isCorridorOrBoundary, true);

      final json = room.toJson();
      expect(json['isCorridorOrBoundary'], true);

      final decoded = RoomRecord.fromJson(json);
      expect(decoded.isCorridorOrBoundary, true);
    });
  });

  group('Boundary-Aware Prediction Engine Tests', () {
    test('Returns noData when liveScan is empty or no valid rooms', () {
      final emptyScanVerdict = evaluateLivePosition([], []);
      expect(emptyScanVerdict.status, PredictionStatus.noData);
      expect(emptyScanVerdict.headline, 'Ready to Locate');
    });

    test('Gate B: Corridor / Hallway winner flags corridorOrOutside', () {
      final corridor = RoomRecord(
        id: 'corridor_1',
        campus: 'IIIT Nagpur',
        building: 'Block A',
        floor: 'Floor 4',
        room: 'Corridor 4F',
        isCorridorOrBoundary: true,
        sessions: [
          ScanSession(
            id: 's_corr',
            startedAt: '2026-10-14T05:00:00.000',
            position: 'Corridor',
            targetScanCount: 1,
            intervalSeconds: 0,
            snapshots: [
              ScanSnapshot(
                timestamp: '2026-10-14T05:00:00.000',
                readings: [
                  ApReading(
                    ssid: 'AP_Hallway_5G',
                    bssid: '11:22:33:44:55:01',
                    rssi: -52,
                    frequency: 5180,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                  ApReading(
                    ssid: 'AP_Hallway_2G',
                    bssid: '11:22:33:44:55:02',
                    rssi: -55,
                    frequency: 2412,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final liveScan = [
        TestAccessPoint(
          bssid: '11:22:33:44:55:01',
          ssid: 'AP_Hallway_5G',
          level: -51,
          frequency: 5180,
        ),
        TestAccessPoint(
          bssid: '11:22:33:44:55:02',
          ssid: 'AP_Hallway_2G',
          level: -54,
          frequency: 2412,
        ),
      ];

      final verdict = evaluateLivePosition(liveScan, [corridor]);
      expect(verdict.status, PredictionStatus.corridorOrOutside);
      expect(verdict.headline, contains('Corridor 4F'));
      expect(verdict.explanation, contains('Corridor / Boundary Zone'));
    });

    test('Gate D: Confident Inside Space Match with 5GHz weighting', () {
      final room443 = RoomRecord(
        id: 'room_443',
        campus: 'IIIT Nagpur',
        building: 'Hostel Block A',
        floor: 'Floor 4',
        room: '443',
        isCorridorOrBoundary: false,
        sessions: [
          ScanSession(
            id: 's_443',
            startedAt: '2026-10-14T05:00:00.000',
            position: 'Center',
            targetScanCount: 1,
            intervalSeconds: 0,
            snapshots: [
              ScanSnapshot(
                timestamp: '2026-10-14T05:00:00.000',
                readings: [
                  ApReading(
                    ssid: 'Room443_AP1_5G',
                    bssid: 'aa:bb:cc:dd:ee:01',
                    rssi: -45,
                    frequency: 5240,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                  ApReading(
                    ssid: 'Room443_AP2_5G',
                    bssid: 'aa:bb:cc:dd:ee:02',
                    rssi: -50,
                    frequency: 5745,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final liveScan = [
        TestAccessPoint(
          bssid: 'aa:bb:cc:dd:ee:01',
          ssid: 'Room443_AP1_5G',
          level: -44,
          frequency: 5240,
        ),
        TestAccessPoint(
          bssid: 'aa:bb:cc:dd:ee:02',
          ssid: 'Room443_AP2_5G',
          level: -49,
          frequency: 5745,
        ),
      ];

      final verdict = evaluateLivePosition(liveScan, [room443]);
      expect(verdict.status, PredictionStatus.confidentInside);
      expect(verdict.headline, contains('443 · Center'));
      expect(verdict.rankedRooms.first.matched5GhzBssids, 2);
    });

    test('Gate C: Shared wall boundary detected when top 2 spaces are close', () {
      final roomA = RoomRecord(
        id: 'room_A',
        campus: 'IIIT Nagpur',
        building: 'Block A',
        floor: 'Floor 4',
        room: '443',
        isCorridorOrBoundary: false,
        sessions: [
          ScanSession(
            id: 's_a',
            startedAt: '2026-10-14T05:00:00.000',
            position: 'Wall R',
            targetScanCount: 1,
            intervalSeconds: 0,
            snapshots: [
              ScanSnapshot(
                timestamp: '2026-10-14T05:00:00.000',
                readings: [
                  ApReading(
                    ssid: 'Shared_AP',
                    bssid: 'aa:bb:cc:11:22:33',
                    rssi: -60,
                    frequency: 2412,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                  ApReading(
                    ssid: 'Shared_AP_5G',
                    bssid: 'aa:bb:cc:11:22:34',
                    rssi: -65,
                    frequency: 5180,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final roomB = RoomRecord(
        id: 'room_B',
        campus: 'IIIT Nagpur',
        building: 'Block A',
        floor: 'Floor 4',
        room: '444',
        isCorridorOrBoundary: false,
        sessions: [
          ScanSession(
            id: 's_b',
            startedAt: '2026-10-14T05:00:00.000',
            position: 'Wall L',
            targetScanCount: 1,
            intervalSeconds: 0,
            snapshots: [
              ScanSnapshot(
                timestamp: '2026-10-14T05:00:00.000',
                readings: [
                  ApReading(
                    ssid: 'Shared_AP',
                    bssid: 'aa:bb:cc:11:22:33',
                    rssi: -61,
                    frequency: 2412,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                  ApReading(
                    ssid: 'Shared_AP_5G',
                    bssid: 'aa:bb:cc:11:22:34',
                    rssi: -66,
                    frequency: 5180,
                    capabilities: '',
                    standard: '',
                    channelWidth: '',
                    timestampMicros: 0,
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final liveScan = [
        TestAccessPoint(
          bssid: 'aa:bb:cc:11:22:33',
          ssid: 'Shared_AP',
          level: -60,
          frequency: 2412,
        ),
        TestAccessPoint(
          bssid: 'aa:bb:cc:11:22:34',
          ssid: 'Shared_AP_5G',
          level: -65,
          frequency: 5180,
        ),
      ];

      final verdict = evaluateLivePosition(liveScan, [roomA, roomB]);
      expect(verdict.status, PredictionStatus.wallBoundary);
      expect(verdict.headline, contains('443 / 444'));
      expect(verdict.explanation, contains('Wall boundary'));
    });
  });
}
