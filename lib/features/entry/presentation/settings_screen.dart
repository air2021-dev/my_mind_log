
import 'package:flutter/material.dart';

import 'package:my_mind_log/core/widgets/gradient_background.dart';
import 'package:my_mind_log/core/backup/backup_service.dart';

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
        const GradientBackground(),
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

                _WarmCard(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file_rounded),
                        title: const Text('내보내기'),
                        subtitle: const Text('백업 파일(JSON)을 공유해요.'),
                        onTap: () async {
                          try {
                            await BackupService.exportBackup();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('내보내기 실패: $e'))
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.backup_rounded),
                        title: const Text('가져오기'),
                        subtitle: const Text('백업 파일(JSON)을 불러와요.'),
                        onTap: () async {
                          final policy = await _askImportPolicy(context);
                          if(policy == null) return;
                          try{
                            final result = await BackupService.importBackup(policy: policy);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('가져오기 완료: 추가 ${result.added}, 덮어쓰기 ${result.overwritten}, 건너뜀 ${result.skipped}'))
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('가져오기 실패: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionHeader('도움말 / 정보'),

                _WarmCard(
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
                              backgroundColor: const Color(0xFFFFF8F1).withValues(alpha: 0.96),
                              surfaceTintColor: Colors.transparent,
                              elevation: 2,
                              shadowColor: const Color(0xFF000000).withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              title: const Text('도움말'),
                              content: const Text(
                                '오늘의 마음을 짧게라도 남겨보세요.\n\n'
                                '되돌아보기는 과거 기록 중 일부를 골라 보여줘요.\n\n'
                                '백업은 JSON 파일로 공유/가져오기 할 수 있어요.',
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

Future<BackupConflictPolicy?> _askImportPolicy(BuildContext context) {
  return showDialog<BackupConflictPolicy>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      var selected = BackupConflictPolicy.skip;

      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFFFF8F1).withValues(alpha: 0.96),
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shadowColor: const Color(0xFF000000).withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('가져오기 정책'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('중복 기록이 있을 때 어떻게 처리할까요?'),
                const SizedBox(height: 12),
                RadioGroup(
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v!),
                  child: RadioListTile<BackupConflictPolicy>(
                      value: BackupConflictPolicy.skip,
                      title: const Text('그냥 넘기기'),
                      subtitle: const Text('이미 있는 기록은 그대로 두고 추가하지 않아요.'),
                    ),
                ),
                RadioGroup(
                  groupValue: selected, 
                  onChanged: (v) => setState(() => selected = v!),
                  child: RadioListTile<BackupConflictPolicy>(
                      value: BackupConflictPolicy.overwrite,
                      title: const Text('덮어쓰기'),
                      subtitle: const Text('같은 ID의 기록이 있으면 백업 파일의 기록으로 덮어써요.'),
                    ),
                ),
                RadioGroup(
                  groupValue: selected, 
                  onChanged: (v) => setState(() => selected = v!),
                  child: RadioListTile<BackupConflictPolicy>(
                      value: BackupConflictPolicy.addNew,
                      title: const Text('새로운 기록으로 추가하기'),
                      subtitle: const Text('같은 ID의 기록이 있더라도 백업 파일의 기록을 새로운 ID로 추가해요.'),
                    ),
                ),
              ]
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('확인'),
              ),
            ],
          );
        },
      );
    },
  );
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
            color: const Color(0x00000000).withValues(alpha: 0.06),
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