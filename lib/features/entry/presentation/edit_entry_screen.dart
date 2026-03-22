import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:my_mind_log/core/widgets/gradient_background.dart';
import 'package:my_mind_log/features/entry/data/entry.dart';

class EditEntryScreen extends StatefulWidget {
  final String entryId;

  const EditEntryScreen({
    super.key,
    required this.entryId,
  });

  @override
  State<EditEntryScreen> createState() => _EditEntryScreenState();
}

class _EditEntryScreenState extends State<EditEntryScreen> {
  final _controller = TextEditingController();
  int? _mood;

  @override
  void initState() {
    super.initState();

    final box = Hive.box<Entry>('entries');
    final entry = _findEntry(box, widget.entryId);
    if (entry != null) {
      _controller.text = entry.text;
      _mood = entry.mood;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Entry>('entries');

    return Stack(
      children: [
        const Positioned.fill(child: GradientBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('수정'),
            leading: IconButton(
              tooltip: '뒤로가기',
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final canSave = value.text.trim().isNotEmpty;
                  return IconButton(
                    tooltip: '저장',
                    icon: const Icon(Icons.check_rounded),
                    onPressed: canSave
                        ? () async {
                            final entry = _findEntry(box, widget.entryId);
                            if (entry == null) return;

                            final updated = Entry(
                              id: entry.id,
                              date: entry.date,
                              text: _controller.text,
                              mood: _mood,
                              createdAt: entry.createdAt,
                            );

                            await box.put(updated.id, updated);

                            if (!mounted) return;
                            Navigator.of(context).pop();
                          }
                        : null,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<Entry> b, _) {
                final entry = _findEntry(b, widget.entryId);

                if (entry == null) {
                  return const Center(child: Text('기록을 찾을 수 없어요.'));
                }

                final canSave = _controller.text.trim().isNotEmpty;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
                  children: [
                    _WarmCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _formatDate(entry.date),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const Spacer(),
                                if (_mood != null)
                                  Text(
                                    _moodEmoji(_mood!),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const Text(
                              '오늘 기분',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            _MoodPicker(
                              selected: _mood,
                              onSelect: (v) => setState(() => _mood = v),
                            ),

                            const SizedBox(height: 18),
                            const Text(
                              '오늘의 마음',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),

                            // Soft inset-like input surface
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E6).withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withValues(alpha: 0.40),
                                      blurRadius: 18,
                                      spreadRadius: -10,
                                      offset: const Offset(-6, -6),
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF000000).withValues(alpha: 0.12),
                                      blurRadius: 18,
                                      spreadRadius: -10,
                                      offset: const Offset(6, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                                  child: TextField(
                                    controller: _controller,
                                    maxLines: 10,
                                    decoration: const InputDecoration(
                                      hintText: '내용을 수정해보세요.',
                                      filled: false,
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: canSave
                                  ? () async {
                                      final updated = Entry(
                                        id: entry.id,
                                        date: entry.date,
                                        text: _controller.text,
                                        mood: _mood,
                                        createdAt: entry.createdAt,
                                      );
                                      await b.put(updated.id, updated);
                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();
                                    }
                                  : null,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('저장하기'),
                            ),
                          ],
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
    final byKey = box.get(id);
    if (byKey != null) return byKey;

    try {
      return box.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}.${two(d.month)}.${two(d.day)}';
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

class _WarmCard extends StatelessWidget {
  final Widget child;

  const _WarmCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F1).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  final int? selected;
  final void Function(int v) onSelect;

  const _MoodPicker({
    required this.selected,
    required this.onSelect,
  });

  static const _moods = <int, String>{
    1: '😞',
    2: '😕',
    3: '😐',
    4: '🙂',
    5: '😄',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _moods.entries.map((e) {
        final isSelected = selected == e.key;

        // Tuned shadows for theme: idle has tight bottom-right shadow,
        // selected simulates pressed/inset feel.
        final shadows = isSelected
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: -6,
                  offset: const Offset(-3, -3),
                ),
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: -6,
                  offset: const Offset(3, 3),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.10),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(4, 6),
                ),
              ];

        return GestureDetector(
          onTap: () => onSelect(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (isSelected
                      ? const Color(0xFFFFEBDD)
                      : const Color(0xFFFFF3E6))
                  .withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(18),
              boxShadow: shadows,
            ),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 22,
                height: 1,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}