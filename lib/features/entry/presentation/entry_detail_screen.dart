import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../data/entry.dart';

class EntryDetailScreen extends StatelessWidget {
  final String entryId;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
  });

  @override 
  Widget build(BuildContext context) {
    final box = Hive.box<Entry>('entries');
    final entry = box.get(entryId);

    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: entry == null
        ? const Center(child: Text('기록을 찾을 수 없어요.'))
        : SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    _formatDate(entry.date),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (entry.mood != null) Text(_moodEmoji(entry.mood!),
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(entry.text),
              ),
            ],
          ),
        ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${_two(date.month)}.${_two(date.day)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _moodEmoji(int mood) {
    switch (mood) {
      case 1: return '😞';
      case 2: return '😕';
      case 3: return '😐';
      case 4: return '🙂';
      case 5: return '😄';
      default: return '';
    }
  }
}