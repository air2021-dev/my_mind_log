import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

    return Stack(
      children: [
        const Positioned.fill(child: _GradientBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('기록 상세'),
            actions: [
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('삭제할까요?'),
                      content: const Text('이 기록은 삭제하면 되돌릴 수 없어요.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('취소'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true) return;

                  // Try delete by key first (if you saved with key=entry.id)
                  if (box.containsKey(entryId)) {
                    await box.delete(entryId);
                  } else {
                    // Fallback: find the entry by id and delete by index
                    final idx = box.values.toList().indexWhere((e) => e.id == entryId);
                    if (idx >= 0) {
                      await box.deleteAt(idx);
                    }
                  }

                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<Entry> b, _) {
                final entry = _findEntry(b, entryId);

                if (entry == null) {
                  return const Center(child: Text('기록을 찾을 수 없어요.'));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDate(entry.date),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (entry.mood != null)
                          Text(
                            _moodEmoji(entry.mood!),
                            style: const TextStyle(fontSize: 22),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Text(
                          entry.text.trim().isEmpty ? '(내용 없음)' : entry.text,
                          style: const TextStyle(height: 1.45),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static Entry? _findEntry(Box<Entry> box, String id) {
    // Preferred: key == id
    final byKey = box.get(id);
    if (byKey != null) return byKey;

    // Fallback: search by field
    try {
      return box.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}.${two(date.month)}.${two(date.day)}';
  }

  static String _moodEmoji(int mood) {
    switch (mood) {
      case 1:
        return '😞';
      case 2:
        return '😕';
      case 3:
        return '😐';
      case 4:
        return '🙂';
      case 5:
        return '😄';
      default:
        return '';
    }
  }
}

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF7F0E6),
            Color(0xFFFFF3E6),
            Color(0xFFFFE2CF),
          ],
        ),
      ),
    );
  }
}