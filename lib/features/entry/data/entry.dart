import 'package:hive/hive.dart';

part 'entry.g.dart';

@HiveType(typeId: 0)
class Entry extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime date; // 날짜 (일 단위 의미)

  @HiveField(2)
  final String text;

  @HiveField(3)
  final int? mood; // 1~5 (optional)
  
  @HiveField(4)
  final DateTime createdAt;

  Entry({
    required this.id,
    required this.date,
    required this.text,
    this.mood,
    required this.createdAt,
  });
}