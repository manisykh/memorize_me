import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/test_sheet_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'select_spreadsheet_screen.dart';

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
            Text('앱 설정', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildAppSettingSection(context),
          ],
        ),
      ),
    );
  }

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
        color: Colors.white,
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
                    Icon(CupertinoIcons.doc_text, size: 32, color: Colors.white.withOpacity(0.9)),
                    const SizedBox(height: 8),
                    Text('로컬 파일', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (manager.wordbooks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text("추가된 단어장이 없습니다.")),
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
                        icon: Icon(CupertinoIcons.trash, color: Colors.white.withOpacity(0.7)),
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
        const Divider(height: 20, color: Colors.white24),
        _buildExportOptionSelector(context),
        const SizedBox(height: 20),
        _buildExportButton(context),
      ],
    );
  }

  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final allWords = context.watch<WordListNotifier>().words;
    final settings = settingsNotifier.settings;

    // ▼▼▼ 수정된 부분 ▼▼▼
    // 단어장 변경 시, 설정된 단어 수가 최대값을 넘지 않도록 조정
    if (allWords.isNotEmpty && settings.wordCount > allWords.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          settingsNotifier.setWordCount(allWords.length);
        }
      });
    }
    // ▲▲▲

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('단어 수', style: theme.textTheme.bodyLarge),
            Row(
              children: [
                Text(
                  '${settings.wordCount.clamp(minValue, maxValue).toInt()}',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
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
        const Divider(color: Colors.white24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('시험 유형', style: theme.textTheme.bodyLarge),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(testTypeMap[settings.testType]!, style: theme.textTheme.bodyMedium),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
          onTap: () => _showTestTypePicker(context),
        ),
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
      contentPadding: EdgeInsets.zero,
      title: Text('내보내기 옵션', style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(exportOptionMap[settings.exportOption]!, style: theme.textTheme.bodyMedium),
          const Icon(Icons.arrow_drop_down, color: Colors.white),
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
              foregroundColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.white,
            ),
          ),
        );
  }

  Widget _buildAppSettingSection(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = context.watch<ThemeNotifier>();
    final currentModeText = themeNotifier.themeMode == ThemeMode.light ? "라이트 모드" : "다크 모드";
    return GlassmorphicCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(CupertinoIcons.moon_stars, color: Colors.white),
        title: Text('테마 변경', style: theme.textTheme.bodyLarge),
        trailing: Text(currentModeText, style: theme.textTheme.bodyMedium),
        onTap: () {
          final notifier = context.read<ThemeNotifier>();
          final newMode = notifier.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          notifier.setThemeMode(newMode);
        },
      ),
    );
  }

  Widget _getSourceIcon(WordbookSource source) {
    switch (source) {
      case WordbookSource.googleSheet:
        return Image.asset('assets/icons/google_sheet_icon.png', width: 24, height: 24);
      case WordbookSource.localCsv:
        return Icon(CupertinoIcons.doc_text_fill, size: 24, color: Colors.white.withOpacity(0.9));
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
                const Divider(height: 1, color: Colors.white24),
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
            icon: const Icon(Icons.save_alt, color: Colors.white),
            tooltip: '저장',
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleExport(type: exportType, share: true);
            },
            icon: const Icon(Icons.share, color: Colors.white),
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
