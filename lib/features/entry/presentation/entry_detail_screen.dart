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
      appBar: AppBar(
        title: const Text('기록'),
        actions: [
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>( 
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('지울까요?'),
                  content: const Text('이 기록은 바로 사라져요.\n괜찮다면 지워둘게요.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니요.')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지울게요.')),
                  ],
                ),
              );

              if(ok != true) return;              
              final box = Hive.box<Entry>('entries');
              await box.delete(entryId);

              if(!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("조용히 지워두었어요.")),
              );
            },
          ),
        ],
      ),
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