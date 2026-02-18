import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../data/entry.dart';
import 'entries_list_screen.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'entry_detail_screen.dart';


final _uuid = Uuid();

enum _HomeMenuAction {
  openHistory,
  showReflection,
  openSettings,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _prefsKeyWeeklyReflection = 'weekly_reflection_shown_key';

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
    // _initSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _maybeShowWeeklyReflection();
    });
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
    await _initSpeech();
    
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

    // 권한 요청 (iOS는 speech 권한도 필요)
    final mic = await Permission.microphone.request();
    final speech = await Permission.speech.request();

    if (!mic.isGranted || !speech.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 입력을 위해 마이크/음성 인식 권한이 필요해요.')),
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

    return Stack(
      children: [
        const _GradientBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('내 마음 기록'),
            actions: [
              PopupMenuButton<_HomeMenuAction>(
                onSelected: (action) async {
                  switch (action) {
                    case _HomeMenuAction.openHistory:
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EntriesListScreen()),
                      );
                      break;
                    case _HomeMenuAction.showReflection:
                      await _showReflection(manual: true);
                      break;
                    case _HomeMenuAction.openSettings:
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SettingsScreen(
                            onResetWeeklyReflection: _resetWeeklyReflection,
                          ),
                        ),
                      );
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _HomeMenuAction.openHistory,
                    child: Text('기록 목록'),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.showReflection,
                    child: Text('되돌아보기'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: _HomeMenuAction.openSettings,
                    child: Text('설정'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
              children: [
                const _GentleMessageCard(
                  title: '오늘 기록하지 않아도 괜찮아요',
                  body: '지금 떠오르는 한 문장만 남겨도 충분해요.',
                  icon: Icons.auto_awesome_rounded,
                ),
                const SizedBox(height: 16),

                const Text('오늘 기분', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _MoodRow(
                      selected: _mood,
                      onSelect: (value) => setState(() => _mood = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('오늘의 마음 (자유롭게)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: TextField(
                      controller: _controller,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        hintText: '떠오르는 생각을 그대로 적어도 좋아요.',
                        filled: false,
                        border: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
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

                FilledButton.icon(
                  onPressed: canSave ? _onTapSave : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('조용히 남기기'),
                ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Future<void> _maybeShowWeeklyReflection() async {

    // 자동: 주 1회 / 과거 기록만 / 조용히 1회 노출
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final weekKey = _weekKeyMonday(now);
    final lastShown = prefs.getString(_prefsKeyWeeklyReflection);
    
    // 이번 주에 이미 보여줬으면 종료
    if (lastShown == weekKey) return;
    
    final picked = _pickReflectionEntry(onlyPast: true);
    if (picked == null) return;

    await prefs.setString(_prefsKeyWeeklyReflection, weekKey);
    if (_isListening) return;

    await _showReflectionDialog(picked, isAuto: true);

  }

  // 수동: 언제든 여러 번 볼 수 있게.
  // 과거가 없으면 테스트/사용성을 위해 "오늘 기록"이라도 보여줌(안내 문구 포함);
  Future<void> _showReflection({required bool manual}) async {
    final picked = _pickReflectionEntry(onlyPast: !manual);

    if(!mounted) return;

    if (picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 되돌아볼 기록이 없어요.')),
      );
      return;
    }

    await _showReflectionDialog(
      picked,
      isAuto: !manual,
      manualFallbackToToday: manual,
    );
  }

  // onlyPast=true이면 오늘 제외(과거만)
  Entry? _pickReflectionEntry({required bool onlyPast}) {
    final box = Hive.box<Entry>('entries');
    if(box.isEmpty) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final candidates = box.values.where((e) {
      if (onlyPast) return e.date.isBefore(today);
      return true;
    }).toList();

    // 수동인데 과거 기록이 0개 라면 -> 오늘 포함 후보로 다시 시도
    if (candidates.isEmpty && !onlyPast) {
      final all = box.values.toList();
      if(all.isEmpty) return null;
      return _weightedPickRecent(all);
    }

    if (candidates.isEmpty) return null;

    // "최근 기록 우선" 가중치 랜덤
    return _weightedPickRecent(candidates);
  }

  // 최근일수록 높은 확률로 뽑는 가중치 랜덤.
  // 1/(index+1) 형태로 간단하지만 효과 좋음.
  Entry _weightedPickRecent(List<Entry> list) {
    final sorted = list.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    double total = 0;
    final weights = <double>[];

    for (int i = 0; i < sorted.length; i++){
      final w = 1.0 / (i + 1); // 가장 최근(0)이 가장 큼
      weights.add(w);
      total += w;
    }

    final r = Random().nextDouble() * total;
    double acc = 0;

    for (int i = 0; i < sorted.length; i++) {
      acc += weights[i];
      if (r <= acc) return sorted[i];
    }

    return sorted.first;
  }

  Future<void> _showReflectionDialog(
    Entry picked, {
      required bool isAuto,
      bool manualFallbackToToday = false,
    }
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = picked.date.isAtSameMomentAs(today);

    final moodEmoji = picked.mood == null ? '' : _moodEmoji(picked.mood!);
    final dateText = _formatDate(picked.date);

    final title = isAuto ? '이번 주, 다시 만난 기록' : '되돌아보기';

    final subtitle = (!isAuto && manualFallbackToToday && isToday)
      ? '아직 지난 기록이 없어서 오늘 기록을 보여드릴게요.'
      : '원하면, 그냥 닫아도 괜찮아요.';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 340),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateText ${moodEmoji.isEmpty ? '' : moodEmoji}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(picked.text),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: TextStyle(color: Theme.of(ctx).hintColor),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('조용히 닫기'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: picked.id)),
              );
            },
            child: const Text('전체 보기'),
          ),
        ],
      ),
    )  ;
  }
  
  Future<void> _resetWeeklyReflection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyWeeklyReflection);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이번 주 되돌아보기 상태를 초기화했어요.')),
    );
  }

  // 이번 주(월요일 시작)를 키로 사용: yyyyMMdd 형태
  String _weekKeyMonday(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return '${monday.year}${_two(monday.month)}${_two(monday.day)}';
  }

  String _formatDate(DateTime d) => '${d.year}.${_two(d.month)}.${_two(d.day)}';
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

class _GentleMessageCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;

  const _GentleMessageCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF8F1).withValues(alpha: 0.92),
      elevation: 2,
      shadowColor: const Color(0xFF000000).withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.92)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _moods.entries.map((e) {
        final isSelected = selected == e.key;
        return ChoiceChip(
          label: Text(e.value, style: const TextStyle(fontSize: 20)),
          selected: isSelected,
          elevation: 1,
          onSelected: (_) => onSelect(e.key),
          shadowColor: const Color(0xFF000000).withValues(alpha: 0.06),
          labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
          backgroundColor: const Color(0xFFFFF8F1).withValues(alpha: 0.92),
          // side: BorderSide(
          //   color: isSelected
          //       ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
          //       : Theme.of(context).dividerColor.withValues(alpha: 0.8),
          //   width: isSelected ? 1.5 : 1,
          // ),
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
        color: const Color(0xFFFFF8F1).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
        // border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha((255 * 0.35).toInt())),
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
            Color(0xFFF7F0E6), // very light beige
            Color(0xFFFFF3E6), // warm off-white
            Color(0xFFFFE2CF), // soft peach (slightly orange)
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final Future<void> Function() onResetWeeklyReflection;

  const SettingsScreen({
    super.key,
    required this.onResetWeeklyReflection,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _GradientBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('설정'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 96, 16, 16),
              children: [
                const _SectionHeader('되돌아보기'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.refresh_rounded),
                        title: const Text('주간 회고 초기화'),
                        subtitle: const Text('이번 주에 보여준 되돌아보기를 취소하고 다시 볼 수 있어요.'),
                        onTap: () async {
                          await onResetWeeklyReflection();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('이번 주 되돌아보기 상태를 초기화했어요.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const _SectionHeader('내보내기 / 백업'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file_rounded),
                        title: const Text('내보내기'),
                        subtitle: const Text('기록을 파일로 저장해요.'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('내보내기는 곧 추가할게요.')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.backup_rounded),
                        title: const Text('백업'),
                        subtitle: const Text('기기 간 이동을 위해 백업해요.'),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('백업은 곧 추가할게요.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const _SectionHeader('도움말 / 정보'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.help_outline_rounded),
                        title: const Text('도움말'),
                        subtitle: const Text('간단한 사용법을 확인해요.'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('도움말'),
                              content: const Text(
                                '오늘의 마음을 짧게라도 남겨보세요.\n\n되돌아보기는 과거 기록 중 일부를 골라 보여줘요.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('정보'),
                        subtitle: const Text('앱 버전, 라이선스, 약관을 확인해요.'),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: '내 마음 기록',
                            applicationVersion: 'dev',
                            applicationLegalese: '© Dear.o',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
  }
}