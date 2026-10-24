import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:my_mind_log/features/entry/data/entry.dart';

enum BackupConflictPolicy {
  skip,
  overwrite,
  addNew,
}

class ImportResult {
  final int added;
  final int overwritten;
  final int skipped;

  const ImportResult({
    required this.added,
    required this.overwritten,
    required this.skipped,
  });
}

class ImportPreview {
  /// Total items in the backup entries array.
  final int total;

  /// Number of entries successfully parsed into `Entry`.
  final int parsed;

  /// Number of invalid/unparsable items.
  final int invalid;

  /// Number of parsed entries whose id already exists in the current box.
  final int conflicts;

  const ImportPreview({
    required this.total,
    required this.parsed,
    required this.invalid,
    required this.conflicts,
  });
}

class BackupService {
  static const _uuid = Uuid();

  /// Export all entries to a JSON file and share it.
  static Future<void> exportBackup() async {
    final box = Hive.box<Entry>('entries');
    final entries = box.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'app': 'my_mind_log',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'deviceTimeZone': DateTime.now().timeZoneName,
      'entries': entries.map(_entryToJson).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final filename =
        'my_mind_log_backup_${stamp.year}${two(stamp.month)}${two(stamp.day)}.json';

    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: '내 마음 기록 백업',
      text: '내 마음 기록 백업 파일이에요. ($filename)',
    );
  }

  /// Parse a backup JSON string and return a preview (counts + conflicts).
  ///
  /// This does NOT write anything to Hive.
  static ImportPreview previewFromJson(String json, Box<Entry> box) {
    final parsedBackup = _parseBackup(json);

    int conflicts = 0;
    for (final e in parsedBackup.entries) {
      if (box.containsKey(e.id)) conflicts++;
    }

    return ImportPreview(
      total: parsedBackup.total,
      parsed: parsedBackup.entries.length,
      invalid: parsedBackup.invalid,
      conflicts: conflicts,
    );
  }

  /// Import entries from a backup JSON string into the Hive box.
  static Future<ImportResult> importFromJson(
    String json, {
    required BackupConflictPolicy policy,
  }) async {
    final parsedBackup = _parseBackup(json);
    final box = Hive.box<Entry>('entries');

    int added = 0;
    int overwritten = 0;
    int skipped = 0;

    for (final e in parsedBackup.entries) {
      final exists = box.containsKey(e.id);

      if (!exists) {
        await box.put(e.id, e);
        added++;
        continue;
      }

      switch (policy) {
        case BackupConflictPolicy.skip:
          skipped++;
          break;
        case BackupConflictPolicy.overwrite:
          await box.put(e.id, e);
          overwritten++;
          break;
        case BackupConflictPolicy.addNew:
          final newEntry = Entry(
            id: _uuid.v4(),
            date: e.date,
            text: e.text,
            mood: e.mood,
            createdAt: e.createdAt,
          );
          await box.put(newEntry.id, newEntry);
          added++;
          break;
      }
    }

    return ImportResult(added: added, overwritten: overwritten, skipped: skipped);
  }

  static _ParsedBackup _parseBackup(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw '올바른 백업 형식이 아니에요.';
    }

    final list = decoded['entries'];
    if (list is! List) {
      throw '백업에 entries가 없어요.';
    }

    final entries = <Entry>[];
    int invalid = 0;

    for (final item in list) {
      if (item is! Map) {
        invalid++;
        continue;
      }

      try {
        final m = item.cast<String, dynamic>();
        final e = _entryFromJson(m);
        entries.add(e);
      } catch (_) {
        invalid++;
      }
    }

    return _ParsedBackup(
      total: list.length,
      invalid: invalid,
      entries: entries,
    );
  }

  static Map<String, dynamic> _entryToJson(Entry e) {
    String two(int n) => n.toString().padLeft(2, '0');
    final d = e.date;
    final dateStr = '${d.year}-${two(d.month)}-${two(d.day)}';

    return {
      'id': e.id,
      'date': dateStr,
      'text': e.text,
      'createdAt': e.createdAt.toUtc().toIso8601String(),
      if (e.mood != null) 'mood': e.mood,
    };
  }

  static Entry _entryFromJson(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final text = (m['text'] ?? '').toString();

    final dateRaw = (m['date'] ?? '').toString();
    final parts = dateRaw.split('-');
    final date = (parts.length == 3)
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();

    final createdAtRaw = (m['createdAt'] ?? '').toString();
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(createdAtRaw);
    } catch (_) {
      createdAt = DateTime.now();
    }

    final moodRaw = m['mood'];
    final mood = moodRaw is int ? moodRaw : int.tryParse(moodRaw?.toString() ?? '');

    return Entry(
      id: id.isEmpty ? _uuid.v4() : id,
      date: DateTime(date.year, date.month, date.day),
      text: text,
      mood: mood,
      createdAt: createdAt,
    );
  }
}

class _ParsedBackup {
  final int total;
  final int invalid;
  final List<Entry> entries;

  const _ParsedBackup({
    required this.total,
    required this.invalid,
    required this.entries,
  });
}