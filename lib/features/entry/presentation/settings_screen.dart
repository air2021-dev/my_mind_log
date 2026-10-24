import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:my_mind_log/features/entry/data/entry.dart';

import 'package:my_mind_log/core/widgets/gradient_background.dart';
import 'package:my_mind_log/core/widgets/ad_banner.dart';
import 'package:my_mind_log/core/backup/backup_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

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
                _WarmCard(
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
                          try {
                            final picked = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['json'],
                              withData: true,
                            );
                            if (picked == null || picked.files.isEmpty) return;

                            final bytes = picked.files.first.bytes;
                            final path = picked.files.first.path;
                            if (bytes == null && path == null) {
                              throw '파일을 읽을 수 없어요.';
                            }

                            final content = bytes != null
                                ? utf8.decode(bytes)
                                : await File(path!).readAsString();

                            final box = Hive.box<Entry>('entries');
                            final preview = BackupService.previewFromJson(content, box);

                            final policy = await _askImportPolicy(
                              context,
                              conflicts: preview.conflicts,
                              total: preview.total,
                              invalid: preview.invalid,
                            );
                            if (policy == null) return;

                            final result = await BackupService.importFromJson(
                              content,
                              policy: policy,
                            );

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '가져오기 완료: 추가 ${result.added}, 덮어쓰기 ${result.overwritten}, 건너뜀 ${result.skipped}',
                                ),
                              ),
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
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HelpScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('정보'),
                        subtitle: const Text('앱 버전, 라이선스, 약관을 확인해요.'),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const InfoScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const AdBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<BackupConflictPolicy?> _askImportPolicy(
  BuildContext context, {
  required int conflicts,
  required int total,
  required int invalid,
}) {
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
                if(invalid > 0) ...[
                  Text(
                    '총 $total개 중 $invalid개는\n형식이 올바르지 않아 제외돼요.', 
                    style: const TextStyle(fontSize: 13, height: 1.25)
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '중복 ID가 $conflicts개 있어요.\n어떻게 처리할까요?',
                  style: const TextStyle(fontSize: 13, height: 1.25),
                ),
                const SizedBox(height: 12),

                RadioListTile<BackupConflictPolicy>(
                  value: BackupConflictPolicy.skip,
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v!),
                  title: const Text('그냥 넘기기'),
                  subtitle: const Text(
                    '이미 있는 기록은 그대로 두고 건너뛰어요.',
                    style: TextStyle(fontSize: 12.5, height: 1.2),
                  ),
                  dense: true,
                ),
                RadioListTile<BackupConflictPolicy>(
                  value: BackupConflictPolicy.overwrite,
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v!),
                  title: const Text('덮어쓰기'),
                  subtitle: const Text(
                    '같은 ID가 있으면 백업 내용으로 바꿔요.',
                    style: TextStyle(fontSize: 12.5, height: 1.2),
                  ),
                  dense: true,
                ),
                RadioListTile<BackupConflictPolicy>(
                  value: BackupConflictPolicy.addNew,
                  groupValue: selected,
                  onChanged: (v) => setState(() => selected = v!),
                  title: const Text('추가하기'),
                  subtitle: const Text('같은 ID가 있어도 새 ID로 바꿔 모두 추가해요.'),
                  dense: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('취소'),
              ),
              FilledButton(
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

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GradientBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('도움말'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
              children: const [
                _SectionHeader('기록하기'),
                _WarmCard(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '• 오늘의 마음을 한 줄이라도 남겨보세요.\n'
                      '• 기분(이모지)은 선택 사항이에요.\n'
                      '• “조용히 남기기”를 누르면 기록이 저장돼요.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                _SectionHeader('음성 입력'),
                _WarmCard(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '• 마이크 버튼을 누르면 음성 입력을 시작해요.\n'
                      '• iOS는 마이크/음성 인식 권한이 필요해요.\n'
                      '• 권한을 거부했다면 설정에서 다시 켤 수 있어요.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                _SectionHeader('되돌아보기'),
                _WarmCard(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '• 되돌아보기는 과거 기록 중 일부를 골라 보여줘요.\n'
                      '• “주간 회고 초기화”를 누르면 이번 주에 본 회고를 취소하고 다시 볼 수 있어요.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                _SectionHeader('백업 / 가져오기'),
                _WarmCard(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '• 내보내기: 백업 파일(JSON)을 공유해 저장할 수 있어요.\n'
                      '• 가져오기: 백업 파일(JSON)을 불러와 복원할 수 있어요.\n'
                      '• 중복 기록이 있을 경우, 정책(넘김/덮어쓰기/추가하기)을 선택할 수 있어요.',
                      style: TextStyle(height: 1.45),
                    ),
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

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<PackageInfo> _loadInfo() => PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GradientBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('정보'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
              children: [
                const _SectionHeader('앱'),
                _WarmCard(
                  child: FutureBuilder<PackageInfo>(
                    future: _loadInfo(),
                    builder: (context, snapshot) {
                      final appName = snapshot.data?.appName ?? '내 마음 기록';
                      final version = snapshot.data?.version;
                      final buildNumber = snapshot.data?.buildNumber;

                      return Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.apps_rounded),
                            title: Text(appName),
                            subtitle: Text(
                              version == null
                                  ? '버전 정보를 불러오는 중…'
                                  : '버전 $version ($buildNumber)',
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: const Text('이용약관'),
                            subtitle: const Text('추후 링크/문서로 제공할 예정이에요.'),
                            onTap: () {
                              // showDialog(
                              //   context: context,
                              //   builder: (ctx) => AlertDialog(
                              //     backgroundColor: const Color(0xFFFFF8F1)
                              //         .withValues(alpha: 0.96),
                              //     surfaceTintColor: Colors.transparent,
                              //     shape: RoundedRectangleBorder(
                              //       borderRadius: BorderRadius.circular(18),
                              //     ),
                              //     title: const Text('이용약관'),
                              //     content: const Text('현재는 내부 테스트 단계예요.\n정식 출시 전에 약관을 추가할게요.'),
                              //     actions: [
                              //       TextButton(
                              //         onPressed: () => Navigator.of(ctx).pop(),
                              //         child: const Text('닫기'),
                              //       ),
                              //     ],
                              //   ),
                              // );
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LegalDocumentScreen(
                                  title: '이용약관',
                                  assetPath: 'assets/legal/terms_ko.md',
                                )),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.privacy_tip_outlined),
                            title: const Text('개인정보처리방침'),
                            subtitle: const Text('추후 링크/문서로 제공할 예정이에요.'),
                            onTap: () {
                            //   showDialog(
                            //     context: context,
                            //     builder: (ctx) => AlertDialog(
                            //       backgroundColor: const Color(0xFFFFF8F1)
                            //           .withValues(alpha: 0.96),
                            //       surfaceTintColor: Colors.transparent,
                            //       shape: RoundedRectangleBorder(
                            //         borderRadius: BorderRadius.circular(18),
                            //       ),
                            //       title: const Text('개인정보처리방침'),
                            //       content: const Text(
                            //         '현재는 내부 테스트 단계예요.\n정식 출시 전에 방침을 추가할게요.',
                            //       ),
                            //       actions: [
                            //         TextButton(
                            //           onPressed: () => Navigator.of(ctx).pop(),
                            //           child: const Text('닫기'),
                            //         ),
                            //       ],
                            //     ),
                            //   );
                            // },
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LegalDocumentScreen(
                                  title: '개인정보처리방침',
                                  assetPath: 'assets/legal/privacy_ko.md',
                                )),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.code_rounded),
                            title: const Text('오픈소스 라이선스'),
                            subtitle: const Text('사용 중인 오픈소스 목록을 확인해요.'),
                            onTap: () {
                              showLicensePage(
                                context: context,
                                applicationName: appName,
                                applicationVersion:
                                    version == null ? null : '버전 $version',
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),
                const _SectionHeader('저작권'),
                const _WarmCard(
                  child: ListTile(
                    leading: Icon(Icons.copyright_rounded),
                    title: Text('© Air2021'),
                    subtitle: Text('All rights reserved.'),
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
class LegalDocumentScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final Future<String> _doc;

  @override
  void initState() {
    super.initState();
    _doc = rootBundle.loadString(widget.assetPath).then((s){
      debugPrint('Loaded ${widget.assetPath}: ${s.length} chars');
      return s;
    }).catchError((e){
      debugPrint('Failed to load ${widget.assetPath}: $e');
      throw e;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const GradientBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
              children: [
                _WarmCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: 
                    FutureBuilder<String>(
                      future: _doc,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Text('불러오는 중…');
                        }
                        if (snapshot.hasError) {
                          return Text('문서를 불러올 수 없어요.\n${snapshot.error}');
                        }
                        // return SelectableText(
                        //   snapshot.data ?? '',
                        //   style: const TextStyle(height: 1.55),
                        // );
                        return MarkdownBody(
                          data: stripFrontmatter(snapshot.data ?? ''),
                          selectable: true,
                          onTapLink: (text, href, title) async {
                            if (href == null) return;
                            final uri = Uri.tryParse(href);
                            if (uri == null) return;
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          styleSheet: _legalMarkdownStyle(context),
                        );
                      },
                    ),
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
String stripFrontmatter(String input) {
  final s = input.replaceAll('\r\n', '\n'); // 줄바꿈 통일
  if (!s.startsWith('---\n')) return input;

  final end = s.indexOf('\n---\n', 4);
  if (end == -1) return input; // 못 찾으면 원문 반환(절대 비우지 않음)

  return s.substring(end + '\n---\n'.length);
}

MarkdownStyleSheet _legalMarkdownStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  
  return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(    
    p: const TextStyle(height: 1.6, fontSize: 14),
    h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.25),
    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.25),
    h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25),
    blockquoteDecoration: BoxDecoration(
      color: const Color(0xFFFFF3E6).withValues(alpha: 0.60),
      borderRadius: BorderRadius.circular(12),
    ),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFFFFF3E6).withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
    ),
    a: TextStyle(
      color: cs.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    ),
    listBullet: const TextStyle(height: 1.6),
  );
}