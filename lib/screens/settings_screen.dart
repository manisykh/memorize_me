// screens/settings_screen.dart (수정 후)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/test_sheet_service.dart';
import '../themes/app_theme.dart';
import '../widgets/glassmorphic_card.dart';
import 'select_spreadsheet_screen.dart';
import 'manage_words_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('계정 및 단어장 관리', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildAuthSection(context),
            const SizedBox(height: 24),
            Text('내 단어장', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            _buildWordbookList(context),
            const SizedBox(height: 24),
            Text('학습 및 시험지 만들기', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            GlassmorphicCard(child: _buildSettingsAndExportSection(context)),
            const SizedBox(height: 24),
            // '앱 설정' -> '테마 설정'으로 헤더 텍스트 변경
            Text('테마 설정', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildThemeSettingsSection(context),
          ],
        ),
      ),
    );
  }

  // 단어 수를 직접 입력받는 다이얼로그 표시
  void _showWordCountInputDialog(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    final words = context.read<WordListNotifier>().words;
    final maxCount = words.isNotEmpty ? words.length : 1;
    final controller = TextEditingController(text: settingsNotifier.settings.wordCount.toString());

    showCupertinoDialog(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: Text('단어 수 입력 (최대: $maxCount)'),
            content: Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: CupertinoTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('확인'),
                onPressed: () {
                  final int? newCount = int.tryParse(controller.text);
                  if (newCount != null) {
                    // 입력값이 1과 최대값 사이인지 확인 후 적용
                    settingsNotifier.setWordCount(newCount.clamp(1, maxCount));
                  }
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
    );
  }

  // 테마 설정 섹션 UI (슬라이더 포함)
  Widget _buildThemeSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = context.watch<ThemeNotifier>();

    final String currentThemeName;
    final IconData currentIcon;

    if (themeNotifier.currentTheme == AppThemeType.eyeCare) {
      currentThemeName = "시력 보호 테마";
      currentIcon = CupertinoIcons.eyeglasses;
    } else {
      currentThemeName = "기본 테마";
      currentIcon = CupertinoIcons.sun_max_fill;
    }

    return GlassmorphicCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            leading: Icon(currentIcon, color: theme.primaryColor),
            // '테마 변경' -> 현재 테마 이름으로 변경
            title: Text(currentThemeName, style: theme.textTheme.bodyLarge),
            onTap: () {
              final newTheme =
                  themeNotifier.currentTheme == AppThemeType.basic
                      ? AppThemeType.eyeCare
                      : AppThemeType.basic;
              themeNotifier.setTheme(newTheme);
            },
          ),
          // '시력 보호 테마'일 때만 농도 조절 슬라이더 표시
          if (themeNotifier.currentTheme == AppThemeType.eyeCare)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
              child: Row(
                children: [
                  Text("배경 농도", style: theme.textTheme.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: themeNotifier.eyeCareLevel.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      label: "Level ${themeNotifier.eyeCareLevel}",
                      onChanged: (value) {
                        themeNotifier.setEyeCareLevel(value.toInt());
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 단어 수 설정 섹션 UI (숫자 탭 기능 추가)
  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final allWords = context.watch<WordListNotifier>().words;
    final settings = settingsNotifier.settings;

    final double minValue = allWords.isEmpty ? 1.0 : 1.0;
    final double maxValue = allWords.isEmpty ? 1.0 : allWords.length.toDouble();

    const testTypeMap = {
      TestType.random: '랜덤',
      TestType.wordToMeaning: '단어 → 뜻',
      TestType.meaningToWord: '뜻 → 단어',
      TestType.meaningToWordWithHint: '뜻 → 단어 (첫 글자 힌트)',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('단어 수', style: theme.textTheme.bodyLarge),
              Row(
                children: [
                  // 숫자를 탭하여 직접 입력할 수 있도록 InkWell로 감싸기
                  InkWell(
                    onTap: () => _showWordCountInputDialog(context),
                    child: Text(
                      '${settings.wordCount.clamp(minValue, maxValue).toInt()}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.wordCount.toDouble().clamp(minValue, maxValue),
                      min: minValue,
                      max: maxValue,
                      divisions:
                          allWords.isEmpty
                              ? 1
                              : (maxValue > minValue ? (maxValue - minValue).toInt() : 1),
                      onChanged: (value) => settingsNotifier.setWordCount(value.toInt()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.2)),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
          title: Text('시험 유형', style: theme.textTheme.bodyLarge),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(testTypeMap[settings.testType]!, style: theme.textTheme.bodyMedium),
              Icon(Icons.arrow_drop_down, color: theme.textTheme.bodyLarge?.color),
            ],
          ),
          onTap: () => _showTestTypePicker(context),
        ),
      ],
    );
  }

  // --- 이하 다른 메소드들은 기존과 동일 ---
  Widget _buildAuthSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    if (authProvider.isLoading) return const Center(child: CircularProgressIndicator());
    return GlassmorphicCard(
      child: user != null ? _buildLoggedInUser(context, user) : _buildLoginButton(context),
    );
  }

  Widget _buildLoggedInUser(BuildContext context, GoogleSignInAccount user) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GoogleUserCircleAvatar(identity: user),
      title: Text(
        user.displayName ?? 'No Name',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(user.email, style: theme.textTheme.bodyMedium),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => context.read<AuthProvider>().signOut(),
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.read<AuthProvider>().signIn(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/google_logo.png', height: 24, width: 24),
            const SizedBox(width: 12),
            Text('Google 계정으로 로그인', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildWordbookList(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final user = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GlassmorphicCard(
                onTap:
                    user == null
                        ? null
                        : () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen())),
                child: Column(
                  children: [
                    Image.asset('assets/icons/google_sheet_icon.png', height: 32, width: 32),
                    const SizedBox(height: 8),
                    Text('Google 시트', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GlassmorphicCard(
                onTap: () => context.read<WordbookManager>().createNewWordbookFromCsv(context),
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.doc_text,
                      size: 32,
                      color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9),
                    ),
                    const SizedBox(height: 8),
                    Text('로컬 파일', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GlassmorphicCard(
                onTap: () {
                  // '단어 관리' 버튼을 눌렀을 때의 동작
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const ManageWordsScreen()));
                },
                child: Column(
                  children: [
                    Icon(
                      CupertinoIcons.book_fill,
                      size: 32,
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
                    ),
                    const SizedBox(height: 8),
                    Text('단어 관리', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (manager.wordbooks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text("추가된 단어장이 없습니다.", style: theme.textTheme.bodyMedium)),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: manager.wordbooks.length,
              itemBuilder: (context, index) {
                final wordbook = manager.wordbooks[index];
                final isActive = manager.activeWordbook?.id == wordbook.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: GlassmorphicCard(
                    isActive: isActive,
                    onTap: () => manager.setActiveWordbook(wordbook),
                    padding: const EdgeInsets.only(left: 8),
                    child: ListTile(
                      dense: true,
                      leading: _getSourceIcon(wordbook.source),
                      title: Text(
                        wordbook.name,
                        style:
                            isActive
                                ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)
                                : theme.textTheme.bodyLarge,
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          CupertinoIcons.trash,
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                        ),
                        onPressed: () => _confirmDelete(context, manager, wordbook),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsAndExportSection(BuildContext context) {
    return Column(
      children: [
        _buildLearningSettingsSection(context),
        Divider(height: 1, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.2)),
        _buildExportOptionSelector(context),
        const SizedBox(height: 20),
        _buildExportButton(context),
      ],
    );
  }

  Widget _buildExportOptionSelector(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;

    const exportOptionMap = {
      ExportOption.both: '시험지와 답안지 모두',
      ExportOption.testOnly: '시험지만',
      ExportOption.answersOnly: '답안지만',
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      title: Text('내보내기 옵션', style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(exportOptionMap[settings.exportOption]!, style: theme.textTheme.bodyMedium),
          Icon(Icons.arrow_drop_down, color: theme.textTheme.bodyLarge?.color),
        ],
      ),
      onTap: () => _showExportOptionPicker(context),
    );
  }

  Widget _buildExportButton(BuildContext context) {
    return _isExporting
        ? const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: CircularProgressIndicator(),
          ),
        )
        : Center(
          child: ElevatedButton.icon(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.download),
            label: const Text('파일로 내보내기'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
        );
  }

  Widget _getSourceIcon(WordbookSource source) {
    switch (source) {
      case WordbookSource.googleSheet:
        return Image.asset('assets/icons/google_sheet_icon.png', width: 24, height: 24);
      case WordbookSource.localCsv:
        return Icon(
          CupertinoIcons.doc_text_fill,
          size: 24,
          color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.9),
        );
    }
  }

  void _confirmDelete(BuildContext context, WordbookManager manager, Wordbook wordbook) {
    showCupertinoDialog(
      context: context,
      builder:
          (_) => CupertinoAlertDialog(
            title: const Text('단어장 삭제'),
            content: Text("'${wordbook.name}' 단어장을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다."),
            actions: [
              CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('삭제'),
                onPressed: () {
                  manager.deleteWordbook(wordbook);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
    );
  }

  void _showExportOptions() {
    final allWords = context.read<WordListNotifier>().words;
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('활성화된 단어장에 단어가 없습니다.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GlassmorphicCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
                  child: Text('시험지 파일 형식 선택', style: Theme.of(ctx).textTheme.titleLarge),
                ),
                _buildExportRow('PDF', exportType: 'pdf', ctx: ctx),
                Divider(
                  height: 1,
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.2),
                ),
                _buildExportRow('Excel', exportType: 'excel', ctx: ctx),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportRow(String format, {required String exportType, required BuildContext ctx}) {
    final theme = Theme.of(ctx);
    return ListTile(
      title: Text(format, style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleExport(type: exportType, share: false);
            },
            icon: Icon(Icons.save_alt, color: theme.textTheme.bodyLarge?.color),
            tooltip: '저장',
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleExport(type: exportType, share: true);
            },
            icon: Icon(Icons.share, color: theme.textTheme.bodyLarge?.color),
            tooltip: '공유',
          ),
        ],
      ),
    );
  }

  void _showTestTypePicker(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    const testTypeMap = {
      TestType.random: '랜덤',
      TestType.wordToMeaning: '단어 → 뜻',
      TestType.meaningToWord: '뜻 → 단어',
      TestType.meaningToWordWithHint: '뜻 → 단어 (첫 글자 힌트)',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    testTypeMap.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        onTap: () {
                          settingsNotifier.setTestType(entry.key);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }

  void _showExportOptionPicker(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    const exportOptionMap = {
      ExportOption.both: '시험지와 답안지 모두',
      ExportOption.testOnly: '시험지만',
      ExportOption.answersOnly: '답안지만',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    exportOptionMap.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        onTap: () {
                          settingsNotifier.setExportOption(entry.key);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }

  Future<void> _handleExport({required String type, required bool share}) async {
    if (!mounted) return;
    setState(() => _isExporting = true);

    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    final service = context.read<TestSheetService>();

    try {
      if (type == 'pdf') {
        await service.exportPdf(allWords, settings, share: share);
      } else {
        await service.exportExcel(allWords, settings, share: share);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('작업 중 오류 발생: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
