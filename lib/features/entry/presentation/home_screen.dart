import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../data/entry.dart';
import 'entries_list_screen.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

final _uuid = Uuid();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  int? _mood; // 1 ~ 5 (optional)

  final SpeechToText _stt = SpeechToText();
  bool _speechReady = false;
  bool _isListening = false;

  String _voiceBaseText = '';
  TextSelection _voiceBaseSelection = const TextSelection.collapsed(offset: 0);

  DateTime? _listeningStartTime;

  @override
  void initState(){
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechReady = await _stt.initialize(
      onStatus: (status) {
        // status: listening, notListening, done 등
        if(status == 'notListening' || status == 'done'){
          setState(()=> _isListening = false);
        }
      },
      onError: (err) {
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('음성 인식 오류: ${err.errorMsg}')),
        );
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose(){
    _stt.stop();
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

  Future<void> _toggleListening() async {
    if (!_speechReady){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 기기에서 음성 인식을 사용할 수 없어요.')),
      );
      return;
    }

    if(_isListening) {
      await _stt.stop();
      if(mounted){
        setState(()=> _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('여기까지 조용히 받아 적었어요.')),
        );
      }
      return;
    }

    // 마이크 권한 요청
    final mic = await Permission.microphone.request();
    if(!mic.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마이크 권한이 필요해요.')),
      );
      return;
    }

    // 음성 입력 시작 시점의 텍스트/커서 위치를 베이스로 저장
    _voiceBaseText = _controller.text;
    _voiceBaseSelection = _controller.selection;

    _listeningStartTime = DateTime.now();

    if(mounted){
      setState(()=> _isListening = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('말해보세요. 천천히 들어볼게요.')),
      );
    }

    await _stt.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        onDevice: true,
        autoPunctuation: true,
        enableHapticFeedback: true,
      )
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    final base = _voiceBaseText;

    // 베이스 텍스트가 비어있지 않으면 ㅎ나 칸 띄워서 자연스럽게 붙이기
    final needsSpace = base.isNotEmpty && !base.endsWith(RegExp(r'\s').toString());
    
    final combined = words.isEmpty ? base : (needsSpace ? '$base $words' : '$base$words');

    _controller.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );

    if (result.finalResult) {
      _voiceBaseText = combined;
    }
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
            tooltip: _isListening ? '음성 입력 중지' : '음성 입력',
            onPressed: _toggleListening,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon( 
                _isListening 
                  ? Icons.mic 
                  : Icons.mic_none_rounded,
                key: ValueKey(_isListening),
              ),
            )
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

            if (_isListening) ...[
              const SizedBox(height:12),
              _ListeningBanner(
                startedAt: _listeningStartTime,
                onStop: _toggleListening,
              ),
              const SizedBox(height: 12),
            ],

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

class _ListeningBanner extends StatelessWidget {
  final DateTime? startedAt;
  final VoidCallback onStop;

  const _ListeningBanner({
    required this.startedAt,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = startedAt == null ? null : DateTime.now().difference(startedAt!).inSeconds;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.35).toInt())),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.hearing_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('듣고 있어요.', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('편하게 말해도 괜찮아요.\n잠시 멈추면 자연스럽게 마무리돼요.'),
                if(seconds != null) ...[
                  const SizedBox(height: 8),
                  Text('지금까지 ${seconds}s', style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onStop,
            child: const Text('멈추기'),
          )
        ],
      ),
    );
  }
}

