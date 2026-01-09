import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/entry.dart';
import 'entry_detail_screen.dart';

class EntriesListScreen extends StatelessWidget {
  const EntriesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Entry>('entries');

    return Scaffold(
      appBar: AppBar(title: const Text('기록 목록')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Entry> b, _) {
          final entries = b.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (entries.isEmpty) {
            return const Center(
              child: Text('아직 남겨둔 기록이 없어요.')
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final e = entries[index];
              final dateText = _formatDate(e.date);
              final preview = e.text.replaceAll('\n', ' ').trim();
              final shortPreview = preview.length > 60
                ? '%${preview.substring(0, 60)}...'
                : preview;

              return Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  final ok = await showDialog<bool>(
                    context:context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('지울까요?'),
                      content: const Text('이 기록은 휴지통 없이 바로 사라져요.\n괜찮다면 지워둘게요.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('아니요.'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('지울게요.'),
                        ),
                      ],
                    ),
                  );
                  return ok ?? false;
                },
                background: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).dividerColor)
                  ),
                  child: const Icon(Icons.delete_outline_rounded),
                ),
                onDismissed: (_) async {
                  final deleted = e;
                  await b.delete(deleted.id);

                  if(!context.mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('조용히 지워두었어요'),
                      action: SnackBarAction(
                        label: '되돌리기',
                        onPressed: () async {
                          await b.put(deleted.id, deleted);
                        },
                      ),
                    ),
                  );
                },
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EntryDetailScreen(entryId: e.id),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(dateText, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (e.mood != null) Text(_moodEmoji(e.mood!)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(shortPreview),
                      ],
                    ),
                  ),
                )
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.year}.${_two(d.month)}.${_two(d.day)}';

  String _two(int n) => n.toString().padLeft(2, '0');

  String _moodEmoji(int mood) {
    switch(mood){
      case 1: return '😞';
      case 2: return '😕';
      case 3: return '😐';
      case 4: return '🙂';
      case 5: return '😄';
      default: return '';
    }
  }
}