import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../data/entry.dart';
import 'entries_list_screen.dart';

final _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  int? _mood; // 1 ~ 5 (optional)

  @override
  void dispose(){
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTapSave() async{
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final box = Hive.box<Entry>('entries');
    final now = DateTime.now();

    // date는 "오늘"의 의미만 남기기 위해 시/분/초 제거
    final today = DateTime(now.year, now.month, now.day);

    final entry = Entry(
      id: _uuid.v4(),
      date: today,
      text: text,
      mood: _mood,
      createdAt: now,
    );

    await box.put(entry.id, entry);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('조용히 남겨두었어요.')),
    );

    _controller.clear();
    setState(()=> _mood = null);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 마음'),
        actions: [
          IconButton(
            tooltip: '기록 목록',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EntriesListScreen()),
              );
            },
            icon: const Icon(Icons.list_alt_rounded),
          ),
          IconButton(
            tooltip: '음성 입력 (다음 단계)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('음성 입력은 다음 단계에서 연결해요.')),
              );
            },
            icon: const Icon(Icons.mic_none_rounded)
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GentleMessageCard(
              title: '오늘 기록하지 않아도 괜찮아요',
              body: '지금 떠오르는 한 문장만 남겨도 충분해요.',
            ),
            const SizedBox(height: 16),

            const Text('기분 (선택)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _MoodRow(
              selected: _mood,
              onSelect: (value) => setState(()=> _mood = value),
            ),
            const SizedBox(height: 16),

            const Text('오늘의 마음 (자유롭게)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '떠오르는 생각을 그대로 적어도 좋아요.',
              ),
              onChanged: (_) => setState((){}),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: canSave ? _onTapSave: null,
              icon: const Icon(Icons.check_rounded),
              label: const Text('조용히 남기기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GentleMessageCard extends StatelessWidget {
  final String title;
  final String body;

  const _GentleMessageCard({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}

class _MoodRow extends StatelessWidget {
  final int? selected;
  final void Function(int value) onSelect;

  const _MoodRow({
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
    return Row(
      children: _moods.entries.map((e) {
        final isSelected = selected == e.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelect(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    width: isSelected ? 2 : 1,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}