
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:my_mind_log/features/entry/data/entry.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

enum BackupConflictPolicy {
  skip,
  overwrite,
  addNew,
}
class ImportResult {
  final int added;
  final int overwritten;
  final int skipped;

  ImportResult({
    required this.added,
    required this.overwritten,
    required this.skipped,
  });
}

class BackupService {
  static const _uuid = Uuid();

  static Future<void> exportBackup() async {
    final box = Hive.box<Entry>('entries');
    final entries = box.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    final payload = {
      'version': 1,
      'app': 'MyMindLog',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'deviceTimeZone': DateTime.now().timeZoneName,
      'entries': entries.map(_entryToJson).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now();
    String tow(int n) => n.toString().padLeft(2, '0');
    final filename = 'mymindlog_backup_${stamp.year}${tow(stamp.month)}${tow(stamp.day)}.json';
    
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType:'application/json')],
      subject: 'My_Mind_Log_Backup',
      text: 'MyMindLog Backup - $filename',
    );
  }

  /// SettingsScreen에서 policy를 받은 뒤 호출하는 형태가 깔끔함
  static Future<ImportResult> importBackup({
    required BackupConflictPolicy policy,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return ImportResult(added: 0, overwritten: 0, skipped: 0);
    }

    final bytes = result.files.first.bytes;
    final path = result.files.first.path;
    if(bytes == null && path == null) {
      throw '파일을 읽을 수 없어요.';
    }
    
    final content = bytes != null ? utf8.decode(bytes) : await File(path!).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) throw '올바른 백업 형식이 아니에요.';

    final list = decoded['entries'];
    if (list is! List) throw '백업에 entries가 없어요.';

    final box = Hive.box<Entry>('entries');

    int added = 0, overwritten = 0, skipped = 0;

    for (final item in list) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final e = _entryFromJson(m);

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

  /// UI에서 "정책 선택 다이얼로그 띄우기" 전에 conflicts 수만 알고 싶을 때
  static Future<int> peekConflictsInPickedFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return 0;
    }

    final bytes = result.files.first.bytes;
    final path = result.files.first.path;
    if(bytes == null && path == null) {
      throw '파일을 읽을 수 없어요.';
    }
    
    final content = bytes != null ? utf8.decode(bytes) : await File(path!).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) throw '올바른 백업 형식이 아니에요.';

    final list = decoded['entries'];
    if (list is! List) throw '백업에 entries가 없어요.';

    final box = Hive.box<Entry>('entries');

    int conflicts = 0;

    for (final item in list) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty && box.containsKey(id)) conflicts++;
    }

    return conflicts;
  }
  
  static Map<String, dynamic> _entryToJson(Entry e) {
    String tow(int n) => n.toString().padLeft(2, '0');
    final d = e.date;
    final dateStr = '${d.year}-${tow(d.month)}-${tow(d.day)}';

    return {
      'id': e.id,
      'date': dateStr,
      'text': e.text,
      'createdAt': e.createdAt.toUtc().toIso8601String(),
      if(e.mood != null) 'mood': e.mood,
    };
  }

  static Entry _entryFromJson(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final text = (m['text'] ?? '').toString();
    
    final dateRaw = (m['date'] ?? '').toString();
    final parts = dateRaw.split('-');
    final date = (parts.length == 3) ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])) : DateTime.now();
    
    final createdAtRaw = (m['createdAt'] ?? '').toString();
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(createdAtRaw);
    }catch (_) {
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