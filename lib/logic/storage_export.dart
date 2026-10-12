import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/room_models.dart';

class StorageExportService {
  static const String storageKey = 'room_mapper_dataset_v2';
  static const String legacyStorageKey = 'room_fingerprints';
  static const String hierarchyLabelsKey = 'hierarchy_labels_v1';
  static const String customPositionsKey = 'custom_positions_v1';

  static const List<String> defaultPositions = [
    'Center',
    'Entry',
    'Window',
    'Wall L',
    'Wall R',
    'Corridor',
  ];

  static Future<List<RoomRecord>> loadDataset() async {
    final prefs = await SharedPreferences.getInstance();
    String? raw = prefs.getString(storageKey);
    raw ??= prefs.getString(legacyStorageKey);

    if (raw == null) return [];

    final decoded = jsonDecode(raw) as List;
    final loaded = decoded
        .map((item) => RoomRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    // Migrate if needed
    if (!prefs.containsKey(storageKey)) {
      await saveDataset(loaded);
    }

    return loaded;
  }

  static Future<void> saveDataset(List<RoomRecord> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(rooms.map((r) => r.toJson()).toList());
    await prefs.setString(storageKey, encoded);
  }

  static Future<HierarchyLabels> loadHierarchyLabels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(hierarchyLabelsKey);
    if (raw == null) return HierarchyLabels();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return HierarchyLabels.fromJson(decoded);
    } catch (_) {
      return HierarchyLabels();
    }
  }

  static Future<void> saveHierarchyLabels(HierarchyLabels labels) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(hierarchyLabelsKey, jsonEncode(labels.toJson()));
  }

  static Future<List<String>> loadCustomPositions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(customPositionsKey);
    if (list == null || list.isEmpty) {
      return List<String>.from(defaultPositions);
    }
    return list;
  }

  static Future<void> saveCustomPositions(List<String> positions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(customPositionsKey, positions);
  }

  static Future<String> exportJson(
    List<RoomRecord> targetRooms,
    String prefix,
  ) async {
    if (targetRooms.isEmpty) {
      throw Exception('No spaces to export.');
    }

    final payload = {
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'roomCount': targetRooms.length,
      'rooms': targetRooms.map((r) => r.toJson()).toList(),
    };

    final cleanName = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = '${cleanName}_${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    await FileSaver.instance.saveToDownloads(
      name: fileName,
      bytes: bytes,
      fileExtension: 'json',
      mimeType: MimeType.json,
    );

    return cleanName;
  }

  static Future<String> exportCsv(
    List<RoomRecord> targetRooms,
    String prefix, {
    HierarchyLabels? labels,
  }) async {
    if (targetRooms.isEmpty) {
      throw Exception('No spaces to export.');
    }

    final l1 = labels?.level1 ?? 'Site';
    final l2 = labels?.level2 ?? 'Block';
    final l3 = labels?.level3 ?? 'Level';
    final l4 = labels?.level4 ?? 'Space';

    final buffer = StringBuffer();
    buffer.writeln(
      '$l1,$l2,$l3,$l4,IsCorridor,SessionID,Position,SnapshotTimestamp,SSID,BSSID,RSSI_dBm,Frequency_MHz,Standard,ChannelWidth',
    );

    String esc(String val) => '"${val.replaceAll('"', '""')}"';

    for (final r in targetRooms) {
      for (final s in r.sessions) {
        for (final snap in s.snapshots) {
          for (final ap in snap.readings) {
            buffer.writeln(
              '${esc(r.campus)},${esc(r.building)},${esc(r.floor)},${esc(r.room)},'
              '${r.isCorridorOrBoundary},'
              '${esc(s.id)},${esc(s.position)},${esc(snap.timestamp)},'
              '${esc(ap.ssid)},${esc(ap.bssid)},${ap.rssi},${ap.frequency},'
              '${esc(ap.standard)},${esc(ap.channelWidth)}',
            );
          }
        }
      }
    }

    final cleanName = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = '${cleanName}_${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(buffer.toString());

    await FileSaver.instance.saveToDownloads(
      name: fileName,
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );

    return cleanName;
  }

  static List<RoomRecord> parseImportedJson(String rawJson) {
    final decoded = jsonDecode(rawJson.trim());
    List rawList = [];
    if (decoded is Map && decoded['rooms'] is List) {
      rawList = decoded['rooms'] as List;
    } else if (decoded is List) {
      rawList = decoded;
    } else {
      throw const FormatException(
        'Invalid JSON structure: expected a "rooms" array or list of space objects.',
      );
    }

    final importedRooms = rawList
        .map((e) => RoomRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (importedRooms.isEmpty) {
      throw const FormatException('No valid space records found in JSON.');
    }

    return importedRooms;
  }
}
