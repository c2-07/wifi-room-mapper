import 'dart:math';
import '../models/room_models.dart';

List<BssidStats> computeRoomStats(RoomRecord room) {
  final Map<String, List<int>> rssiMap = {};
  final Map<String, String> ssidMap = {};
  final Map<String, int> freqMap = {};
  int totalSnapshots = 0;

  for (final session in room.sessions) {
    for (final snapshot in session.snapshots) {
      totalSnapshots++;
      for (final reading in snapshot.readings) {
        rssiMap.putIfAbsent(reading.bssid, () => []).add(reading.rssi);
        if (reading.ssid.isNotEmpty || !ssidMap.containsKey(reading.bssid)) {
          ssidMap[reading.bssid] = reading.ssid;
        }
        freqMap[reading.bssid] = reading.frequency;
      }
    }
  }

  final List<BssidStats> statsList = [];

  rssiMap.forEach((bssid, values) {
    values.sort();
    final count = values.length;
    final minVal = values.first;
    final maxVal = values.last;
    final sum = values.fold(0, (a, b) => a + b);
    final mean = sum / count;

    double median;
    if (count % 2 == 1) {
      median = values[count ~/ 2].toDouble();
    } else {
      median = (values[count ~/ 2 - 1] + values[count ~/ 2]) / 2.0;
    }

    double varianceSum = 0;
    for (final v in values) {
      varianceSum += (v - mean) * (v - mean);
    }
    final stdDev = count > 1 ? sqrt(varianceSum / count) : 0.0;

    statsList.add(
      BssidStats(
        bssid: bssid,
        ssid: ssidMap[bssid] ?? '',
        frequency: freqMap[bssid] ?? 0,
        count: count,
        totalSnapshots: totalSnapshots,
        mean: mean,
        median: median,
        minRssi: minVal,
        maxRssi: maxVal,
        stdDev: stdDev,
      ),
    );
  });

  statsList.sort((a, b) => b.mean.compareTo(a.mean));
  return statsList;
}

QualityReport evaluateRoomQuality(RoomRecord room) {
  final totalScans = room.totalScans;
  if (totalScans == 0) {
    return QualityReport(
      score: 0,
      label: 'No Data',
      warnings: ['No scan sessions recorded for this room yet.'],
    );
  }

  final stats = computeRoomStats(room);
  final warnings = <String>[];

  final scanScore = min(35, (totalScans / 10.0 * 35).round());
  if (totalScans < 5) {
    warnings.add('Too few scans ($totalScans). Capture at least 10 scans.');
  }

  final stableAps = stats.where((s) => s.visibilityRatio >= 0.7).toList();
  final apScore = min(35, (stableAps.length / 5.0 * 35).round());
  if (stableAps.length < 3) {
    warnings.add(
      'Only ${stableAps.length} BSSIDs appear consistently (>=70% of scans).',
    );
  }

  double avgStdDev = 0;
  if (stableAps.isNotEmpty) {
    avgStdDev =
        stableAps.fold(0.0, (sum, s) => sum + s.stdDev) / stableAps.length;
  } else if (stats.isNotEmpty) {
    avgStdDev = stats.fold(0.0, (sum, s) => sum + s.stdDev) / stats.length;
  }

  int stabilityScore = 30;
  if (avgStdDev > 2.0) {
    stabilityScore = max(0, (30 - (avgStdDev - 2.0) * 4).round());
  }
  if (avgStdDev > 5.0) {
    warnings.add(
      'High signal fluctuation (avg σ = ${avgStdDev.toStringAsFixed(1)} dBm).',
    );
  }

  final positions = room.sessions.map((s) => s.position).toSet();
  if (positions.length < 2) {
    warnings.add('Only 1 room position sampled (${positions.first}).');
  }

  final total = (scanScore + apScore + stabilityScore).clamp(0, 100);
  String label = 'Poor';
  if (total >= 80) {
    label = 'Excellent';
  } else if (total >= 60) {
    label = 'Good';
  } else if (total >= 40) {
    label = 'Fair';
  }

  return QualityReport(score: total, label: label, warnings: warnings);
}
