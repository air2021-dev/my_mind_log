import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:my_mind_log/core/widgets/gradient_background.dart';

import '../data/entry.dart';
import 'entry_detail_screen.dart';

class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
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
            title: const Text('기록 목록'),
          ),
          body: SafeArea(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<Entry> b, _) {
                final entries = b.values.toList()
                  ..sort((a, c) => c.createdAt.compareTo(a.createdAt));

                final q = _query.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? entries
                    : entries.where((e) {
                        final text = e.text.toLowerCase();
                        final date = _formatDate(e.date).toLowerCase();
                        final mood = e.mood != null ? _moodEmoji(e.mood!).toLowerCase() : '';
                        return text.contains(q) || date.contains(q) || mood.contains(q);
                      }).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  children: [
                    _SearchBar(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      onClear: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const SizedBox(height: 8),

                    if (entries.isEmpty) ...[
                      const SizedBox(height: 24),
                      const Center(child: Text('아직 남겨둔 기록이 없어요.')),
                    ] else if (filtered.isEmpty) ...[
                      const SizedBox(height: 24),
                      const Center(child: Text('검색 결과가 없어요.')),
                    ] else ...[
                      for (final e in filtered) ...[
                        _EntryTile(
                          entry: e,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EntryDetailScreen(entryId: e.id),
                              ),
                            );
                          },
                          onDelete: () async {
                            final ok = await _confirmDelete(context);
                            if (ok != true) return;

                            final deleted = e;
                            await b.delete(deleted.id);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('조용히 지워두었어요'),
                                action: SnackBarAction(
                                  label: '되돌리기',
                                  onPressed: () async {
                                    await b.put(deleted.id, deleted);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0xFF000000).withOpacity(0.25),
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F1).withOpacity(0.96),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: const Color(0xFF000000).withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
  }

  static String _formatDate(DateTime d) => '${d.year}.${_two(d.month)}.${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _preview(String text) {
    final t = text.replaceAll('\n', ' ').trim();
    if (t.isEmpty) return '(내용 없음)';
    return t.length > 60 ? '${t.substring(0, 60)}…' : t;
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

class _EntryTile extends StatelessWidget {
  final Entry entry;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = _EntriesListScreenState._formatDate(entry.date);
    final preview = _EntriesListScreenState._preview(entry.text);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onDelete();
        // We already handled deletion inside onDelete, so tell Dismissible not to auto-remove.
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE2CF).withOpacity(0.80),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.delete_outline_rounded),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F1).withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(dateText, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (entry.mood != null)
                    Text(
                      _EntriesListScreenState._moodEmoji(entry.mood!),
                      style: const TextStyle(fontSize: 18),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E6).withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.40),
              blurRadius: 18,
              spreadRadius: -10,
              offset: const Offset(-6, -6),
            ),
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.12),
              blurRadius: 18,
              spreadRadius: -10,
              offset: const Offset(6, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '검색 (내용, 날짜, 기분)',
              filled: false,
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: '지우기',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClear,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}