import 'package:flutter/material.dart';

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

  void _onTapSave() {
    // MVP  1단계: 아직 저장소 없음 -> 다음 단계에서 로컬DB 붙일 때 연결
    // 지금은 UX 흐름만 확인
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('오늘의 기록이 임시로 저장되었어요(다음 단계에서 DB 연결).')),
    );

    // 입력 초기화(취향)
    // _controller.clear();
    // setState(()=> _mood = null);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _controller.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 마음'),
        actions: [
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