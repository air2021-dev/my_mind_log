
import 'package:flutter/material.dart';

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
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
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