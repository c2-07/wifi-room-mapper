import 'dart:math';
import 'package:wifi_scan/wifi_scan.dart';

import '../models/room_models.dart';
import 'fingerprint_stats.dart';

double _bandWeight(int freqMHz) {
  if (freqMHz >= 5925) return 1.8; // 6 GHz drops sharply across walls
  if (freqMHz >= 4900) return 1.6; // 5 GHz drops 12-18 dB across brick walls
  return 1.0;                      // 2.4 GHz bleeds through walls
}

double _clampRssi(double rssi) => rssi < -88.0 ? -90.0 : rssi.clamp(-90.0, -30.0);

double _toPositiveWeight(double rssi) => (_clampRssi(rssi) + 90.0).clamp(0.0, 60.0);

PredictionVerdict evaluateLivePosition(
  List<WiFiAccessPoint> liveScan,
  List<RoomRecord> rooms, {
  int k = 5,
}) {
  final validRooms = rooms.where((r) => r.totalScans > 0).toList();
  if (liveScan.isEmpty || validRooms.isEmpty) {
    return PredictionVerdict(
      status: PredictionStatus.noData,
      headline: 'Ready to Locate',
      explanation: 'Run a scan to match against recorded spaces.',
      rankedRooms: const [],
    );
  }

  final Map<String, double> liveRssi = {};
  final Map<String, int> bssidFreq = {};
  for (final ap in liveScan) {
    if (ap.level >= -88) {
      liveRssi[ap.bssid] = _clampRssi(ap.level.toDouble());
      bssidFreq[ap.bssid] = ap.frequency;
    }
  }

  // 1. Snapshot-level weighted k-NN (preserves wall/corner sub-clusters)
  final List<({RoomRecord room, String position, double weightedRmse})> allSnapshots = [];

  for (final room in validRooms) {
    final statsList = computeRoomStats(room);
    final Map<String, BssidStats> roomStatMap = {
      for (final s in statsList) s.bssid: s,
    };
    for (final s in statsList) {
      bssidFreq.putIfAbsent(s.bssid, () => s.frequency);
    }

    for (final session in room.sessions) {
      for (final snap in session.snapshots) {
        if (snap.readings.isEmpty) continue;

        final Map<String, double> snapRssi = {};
        for (final r in snap.readings) {
          if (r.rssi >= -88) {
            snapRssi[r.bssid] = _clampRssi(r.rssi.toDouble());
            bssidFreq.putIfAbsent(r.bssid, () => r.frequency);
          }
        }

        final unionBssids = {...liveRssi.keys, ...snapRssi.keys};
        if (unionBssids.isEmpty) continue;

        double weightedSqSum = 0.0;
        double totalWeight = 0.0;

        for (final bssid in unionBssids) {
          final a = liveRssi[bssid] ?? -90.0;
          final b = snapRssi[bssid] ?? -90.0;
          if (a <= -89.0 && b <= -89.0) continue;

          final freq = bssidFreq[bssid] ?? 2412;
          double w = _bandWeight(freq);

          final stat = roomStatMap[bssid];
          if (stat != null && stat.stdDev > 4.0) {
            w *= (4.0 / stat.stdDev).clamp(0.5, 1.0);
          }

          double diff = (a - b).abs();
          if ((a <= -89.0 && b >= -68.0) || (b <= -89.0 && a >= -68.0)) {
            diff *= 1.25; // Penalty when a strong room AP is missing
          }

          weightedSqSum += w * diff * diff;
          totalWeight += w;
        }

        if (totalWeight > 0) {
          allSnapshots.add((
            room: room,
            position: session.position,
            weightedRmse: sqrt(weightedSqSum / totalWeight),
          ));
        }
      }
    }
  }

  allSnapshots.sort((a, b) => a.weightedRmse.compareTo(b.weightedRmse));
  final topK = allSnapshots.take(k).toList();

  final Map<String, int> knnVotes = {};
  final Map<String, String> bestPositionForRoom = {};
  final Map<String, double> bestSnapRmseForRoom = {};

  for (final snap in allSnapshots) {
    bestPositionForRoom.putIfAbsent(snap.room.id, () => snap.position);
    bestSnapRmseForRoom.putIfAbsent(snap.room.id, () => snap.weightedRmse);
  }
  for (final winner in topK) {
    knnVotes[winner.room.id] = (knnVotes[winner.room.id] ?? 0) + 1;
  }

  // 2. Room-level 5GHz-weighted Cosine Similarity & blended RMSE
  final List<RoomPredictionMatch> ranked = [];

  for (final room in validRooms) {
    final stats = computeRoomStats(room);
    if (stats.isEmpty) continue;

    final reliableStats = stats.where((s) => s.visibilityRatio >= 0.25 && s.mean >= -88.0).toList();
    final roomMap = {for (final s in reliableStats) s.bssid: _clampRssi(s.mean)};
    for (final s in reliableStats) {
      bssidFreq.putIfAbsent(s.bssid, () => s.frequency);
    }

    final unionBssids = {...liveRssi.keys, ...roomMap.keys};
    if (unionBssids.isEmpty) continue;

    int sharedCount = 0;
    int shared5GhzCount = 0;
    double dot = 0.0;
    double normLive = 0.0;
    double normRoom = 0.0;
    double weightedSqDiff = 0.0;
    double weightSum = 0.0;

    for (final bssid in unionBssids) {
      final rawLive = liveRssi[bssid] ?? -90.0;
      final rawRoom = roomMap[bssid] ?? -90.0;
      final freq = bssidFreq[bssid] ?? 2412;
      final w = _bandWeight(freq);

      if (liveRssi.containsKey(bssid) && roomMap.containsKey(bssid)) {
        sharedCount++;
        if (freq >= 4900) shared5GhzCount++;
      }

      final posLive = _toPositiveWeight(rawLive);
      final posRoom = _toPositiveWeight(rawRoom);

      dot += w * posLive * posRoom;
      normLive += w * posLive * posLive;
      normRoom += w * posRoom * posRoom;

      final diff = rawLive - rawRoom;
      weightedSqDiff += w * diff * diff;
      weightSum += w;
    }

    final weightedCosine = (normLive > 0 && normRoom > 0)
        ? (dot / (sqrt(normLive) * sqrt(normRoom))).clamp(0.0, 1.0)
        : 0.0;

    final centroidRmse = weightSum > 0 ? sqrt(weightedSqDiff / weightSum) : 99.0;
    final minSnapRmse = bestSnapRmseForRoom[room.id] ?? centroidRmse;
    // 60% closest position snapshot + 40% room centroid so standing against a wall isn't penalized
    final effectiveRmse = (0.6 * minSnapRmse) + (0.4 * centroidRmse);

    ranked.add(
      RoomPredictionMatch(
        room: room,
        closestPosition: bestPositionForRoom[room.id] ?? 'Center',
        weightedCosine: weightedCosine,
        weightedRmse: effectiveRmse,
        matchedBssids: sharedCount,
        matched5GhzBssids: shared5GhzCount,
        knnVotes: knnVotes[room.id] ?? 0,
      ),
    );
  }

  ranked.sort((a, b) {
    if (b.knnVotes != a.knnVotes) return b.knnVotes.compareTo(a.knnVotes);
    final cosCmp = b.weightedCosine.compareTo(a.weightedCosine);
    if (cosCmp.abs() > 0.01) return cosCmp;
    return a.weightedRmse.compareTo(b.weightedRmse);
  });

  if (ranked.isEmpty) {
    return PredictionVerdict(
      status: PredictionStatus.noData,
      headline: 'No Matching Access Points',
      explanation: 'Zero visible BSSIDs overlap with saved spaces.',
      rankedRooms: const [],
    );
  }

  // 3. Boundary, Shared-Wall & Corridor/Outside Decision Gates
  final best = ranked.first;
  final second = ranked.length > 1 ? ranked[1] : null;

  // Gate A: Hard Outside / Unmapped Area Rejection
  if (best.matchedBssids < 2 || best.weightedCosine < 0.72 || best.weightedRmse > 10.5) {
    return PredictionVerdict(
      status: PredictionStatus.corridorOrOutside,
      headline: 'Outside Mapped Spaces',
      explanation:
          'Closest: ${best.room.room} · ${(best.weightedCosine * 100).toStringAsFixed(0)}% match · ${best.weightedRmse.toStringAsFixed(1)} dB RMSE',
      rankedRooms: ranked,
    );
  }

  // Gate B: Mapped Corridor / Hallway Winner
  if (best.room.isCorridorOrBoundary) {
    return PredictionVerdict(
      status: PredictionStatus.corridorOrOutside,
      headline: '${best.room.room} (${best.closestPosition})',
      explanation:
          '${(best.weightedCosine * 100).toStringAsFixed(1)}% match · ${best.knnVotes}/$k k-NN · Corridor / Boundary Zone',
      rankedRooms: ranked,
    );
  }

  // Gate C: Shared Wall / Boundary Ambiguity Between Top 2 Spaces
  if (second != null) {
    final cosineGap = best.weightedCosine - second.weightedCosine;
    final rmseGap = (second.weightedRmse - best.weightedRmse).abs();
    final splitVotes = (best.knnVotes - second.knnVotes).abs() <= 1;

    if ((cosineGap < 0.035 && rmseGap < 1.8) || (splitVotes && cosineGap < 0.05)) {
      return PredictionVerdict(
        status: PredictionStatus.wallBoundary,
        headline: '${best.room.room} / ${second.room.room}',
        explanation:
            'Wall boundary (${best.closestPosition} vs ${second.closestPosition}) · Δ ${rmseGap.toStringAsFixed(1)} dB · Votes ${best.knnVotes}:${second.knnVotes}',
        rankedRooms: ranked,
      );
    }
  }

  // Gate D: Confident Inside Space Match
  return PredictionVerdict(
    status: PredictionStatus.confidentInside,
    headline: '${best.room.room} · ${best.closestPosition}',
    explanation:
        '${(best.weightedCosine * 100).toStringAsFixed(1)}% match · ${best.knnVotes}/$k k-NN · ${best.matched5GhzBssids} 5GHz APs · ${best.weightedRmse.toStringAsFixed(1)} dB RMSE',
    rankedRooms: ranked,
  );
}

List<RoomPredictionMatch> predictRoomFromLiveScan(
  List<WiFiAccessPoint> liveScan,
  List<RoomRecord> rooms, {
  int k = 5,
}) {
  return evaluateLivePosition(liveScan, rooms, k: k).rankedRooms;
}
