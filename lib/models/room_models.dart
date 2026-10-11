import 'package:wifi_scan/wifi_scan.dart';

class HierarchyLabels {
  String level1; // Default: 'Site' (e.g. IIIT Nagpur)
  String level2; // Default: 'Block' (e.g. Hostel Block A / Academic)
  String level3; // Default: 'Level' (e.g. Floor 4)
  String level4; // Default: 'Space' (e.g. 443 / CSE-201)

  HierarchyLabels({
    this.level1 = 'Site',
    this.level2 = 'Block',
    this.level3 = 'Level',
    this.level4 = 'Space',
  });

  String get pluralLevel4 => '${level4}s';

  Map<String, dynamic> toJson() => {
    'level1': level1,
    'level2': level2,
    'level3': level3,
    'level4': level4,
  };

  factory HierarchyLabels.fromJson(Map<String, dynamic> json) => HierarchyLabels(
    level1: (json['level1'] ?? 'Site') as String,
    level2: (json['level2'] ?? 'Block') as String,
    level3: (json['level3'] ?? 'Level') as String,
    level4: (json['level4'] ?? 'Space') as String,
  );
}

class ApReading {
  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency;
  final String capabilities;
  final String standard;
  final String channelWidth;
  final int timestampMicros;

  ApReading({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.capabilities,
    required this.standard,
    required this.channelWidth,
    required this.timestampMicros,
  });

  factory ApReading.fromAccessPoint(WiFiAccessPoint ap) {
    return ApReading(
      ssid: ap.ssid,
      bssid: ap.bssid,
      rssi: ap.level,
      frequency: ap.frequency,
      capabilities: ap.capabilities,
      standard: ap.standard.toString(),
      channelWidth: ap.channelWidth.toString(),
      timestampMicros: ap.timestamp ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'ssid': ssid,
    'bssid': bssid,
    'rssi': rssi,
    'frequency': frequency,
    'capabilities': capabilities,
    'standard': standard,
    'channelWidth': channelWidth,
    'timestampMicros': timestampMicros,
  };

  factory ApReading.fromJson(Map<String, dynamic> json) => ApReading(
    ssid: (json['ssid'] ?? '') as String,
    bssid: (json['bssid'] ?? '') as String,
    rssi: (json['rssi'] ?? json['rssiDbm'] ?? -100) as int,
    frequency: (json['frequency'] ?? json['frequencyMHz'] ?? 0) as int,
    capabilities: (json['capabilities'] ?? '') as String,
    standard: (json['standard'] ?? '') as String,
    channelWidth: (json['channelWidth'] ?? '') as String,
    timestampMicros: (json['timestampMicros'] ?? 0) as int,
  );
}

class ScanSnapshot {
  final String timestamp;
  final List<ApReading> readings;

  ScanSnapshot({required this.timestamp, required this.readings});

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'readings': readings.map((r) => r.toJson()).toList(),
  };

  factory ScanSnapshot.fromJson(Map<String, dynamic> json) => ScanSnapshot(
    timestamp: (json['timestamp'] ?? '') as String,
    readings: ((json['readings'] ?? []) as List)
        .map((item) => ApReading.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );
}

class ScanSession {
  final String id;
  final String startedAt;
  final String position; // Center, Entry, Window, Wall L, Wall R, Corridor
  final int targetScanCount;
  final int intervalSeconds;
  final List<ScanSnapshot> snapshots;

  ScanSession({
    required this.id,
    required this.startedAt,
    required this.position,
    required this.targetScanCount,
    required this.intervalSeconds,
    required this.snapshots,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt,
    'position': position,
    'targetScanCount': targetScanCount,
    'intervalSeconds': intervalSeconds,
    'snapshots': snapshots.map((s) => s.toJson()).toList(),
  };

  factory ScanSession.fromJson(Map<String, dynamic> json) => ScanSession(
    id: (json['id'] ?? '') as String,
    startedAt: (json['startedAt'] ?? '') as String,
    position: (json['position'] ?? 'Center') as String,
    targetScanCount: (json['targetScanCount'] ?? 1) as int,
    intervalSeconds: (json['intervalSeconds'] ?? 0) as int,
    snapshots: ((json['snapshots'] ?? []) as List)
        .map((item) => ScanSnapshot.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
  );
}

class RoomRecord {
  String id;
  String campus;
  String building;
  String floor;
  String room;
  String notes;
  bool isFavorite;
  bool isCorridorOrBoundary;
  List<ScanSession> sessions;

  RoomRecord({
    required this.id,
    required this.campus,
    required this.building,
    required this.floor,
    required this.room,
    this.notes = '',
    this.isFavorite = false,
    this.isCorridorOrBoundary = false,
    List<ScanSession>? sessions,
  }) : sessions = sessions ?? [];

  String get fullPath => '$campus → $building → $floor → $room';

  int get totalScans =>
      sessions.fold(0, (sum, session) => sum + session.snapshots.length);

  String get lastScannedAt {
    if (sessions.isEmpty) return 'Never';
    return sessions.last.startedAt.split('T').first;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'campus': campus,
    'building': building,
    'floor': floor,
    'room': room,
    'notes': notes,
    'isFavorite': isFavorite,
    'isCorridorOrBoundary': isCorridorOrBoundary,
    'sessions': sessions.map((s) => s.toJson()).toList(),
  };

  factory RoomRecord.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('accessPoints') && !json.containsKey('sessions')) {
      final legacyAps = (json['accessPoints'] as List)
          .map((e) => ApReading.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final savedAt =
          (json['savedAt'] ?? DateTime.now().toIso8601String()) as String;
      return RoomRecord(
        id: 'legacy_${savedAt.hashCode}',
        campus: 'IIIT Nagpur',
        building: 'Academic Block',
        floor: 'Floor 1',
        room: (json['room'] ?? 'Unknown') as String,
        isCorridorOrBoundary: false,
        sessions: [
          ScanSession(
            id: 'sess_${savedAt.hashCode}',
            startedAt: savedAt,
            position: 'Center',
            targetScanCount: 1,
            intervalSeconds: 0,
            snapshots: [ScanSnapshot(timestamp: savedAt, readings: legacyAps)],
          ),
        ],
      );
    }

    return RoomRecord(
      id: (json['id'] ?? '') as String,
      campus: (json['campus'] ?? 'IIIT Nagpur') as String,
      building: (json['building'] ?? 'Academic Block') as String,
      floor: (json['floor'] ?? 'Floor 1') as String,
      room: (json['room'] ?? '') as String,
      notes: (json['notes'] ?? '') as String,
      isFavorite: (json['isFavorite'] ?? false) as bool,
      isCorridorOrBoundary: (json['isCorridorOrBoundary'] ?? false) as bool,
      sessions: ((json['sessions'] ?? []) as List)
          .map((item) => ScanSession.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class BssidStats {
  final String bssid;
  final String ssid;
  final int frequency;
  final int count;
  final int totalSnapshots;
  final double mean;
  final double median;
  final int minRssi;
  final int maxRssi;
  final double stdDev;

  BssidStats({
    required this.bssid,
    required this.ssid,
    required this.frequency,
    required this.count,
    required this.totalSnapshots,
    required this.mean,
    required this.median,
    required this.minRssi,
    required this.maxRssi,
    required this.stdDev,
  });

  double get visibilityRatio =>
      totalSnapshots == 0 ? 0 : count / totalSnapshots;
}

class QualityReport {
  final int score;
  final String label;
  final List<String> warnings;

  QualityReport({
    required this.score,
    required this.label,
    required this.warnings,
  });
}

enum PredictionStatus {
  confidentInside,   // Definitely inside the matched space
  wallBoundary,      // Standing against a shared wall (top 2 spaces are too close to call)
  corridorOrOutside, // Standing outside in a mapped corridor OR signal is too weak/distant from all spaces
  noData,
}

class RoomPredictionMatch {
  final RoomRecord room;
  final String closestPosition; // Which sub-location matched best (e.g. 'Wall L', 'Center')
  final double weightedCosine;  // 0.0 .. 1.0 (5GHz-weighted similarity)
  final double weightedRmse;    // Weighted dBm error (blending closest snapshot + room centroid)
  final int matchedBssids;
  final int matched5GhzBssids;  // Count of shared 5GHz/6GHz APs
  final int knnVotes;

  RoomPredictionMatch({
    required this.room,
    required this.closestPosition,
    required this.weightedCosine,
    required this.weightedRmse,
    required this.matchedBssids,
    required this.matched5GhzBssids,
    required this.knnVotes,
  });

  // Backward-compatibility getters
  double get cosineSimilarity => weightedCosine;
  double get euclideanDistance => weightedRmse;
}

class PredictionVerdict {
  final PredictionStatus status;
  final String headline;
  final String explanation;
  final List<RoomPredictionMatch> rankedRooms;

  PredictionVerdict({
    required this.status,
    required this.headline,
    required this.explanation,
    required this.rankedRooms,
  });
}
