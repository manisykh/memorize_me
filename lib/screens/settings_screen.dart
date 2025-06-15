import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/test_sheet_service.dart';
import '../themes/app_theme.dart';
import '../widgets/enhanced_neumorphic_container.dart';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthSection(context),
          const SizedBox(height: 30),
          _buildLearningSettingsSection(context),
          const SizedBox(height: 30),
          _buildExportSection(context),
          const SizedBox(height: 30),
          _buildAppSettingSection(context),
        ],
      ),
    );
  }

  // 계정 및 단어장 관리 섹션
  Widget _buildAuthSection(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final manager = context.watch<WordbookManager>();
    final user = authProvider.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('계정 및 단어장 관리', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        if (authProvider.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (user != null)
          EnhancedNeumorphicContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GoogleUserCircleAvatar(identity: user),
              title: Text(user.displayName ?? 'No Name', style: theme.textTheme.bodyLarge),
              subtitle: Text(
                user.email,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.subTextLight),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.accentRed),
                onPressed: () => context.read<AuthProvider>().signOut(),
              ),
            ),
          )
        else
          EnhancedNeumorphicContainer(
            onTap: () => context.read<AuthProvider>().signIn(),
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 50,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icons/google_logo.png', height: 24, width: 24),
                    const SizedBox(width: 12),
                    Text('Google 계정으로 로그인', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: EnhancedNeumorphicContainer(
                onTap:
                    (user == null)
                        ? null
                        : () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen())),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    children: [
                      Image.asset('assets/icons/google_sheet_icon.png', height: 32, width: 32),
                      const SizedBox(height: 8),
                      Text('Google 시트', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: EnhancedNeumorphicContainer(
                onTap: () {
                  context.read<WordbookManager>().createNewWordbookFromCsv(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.doc_text, size: 32),
                      const SizedBox(height: 8),
                      Text('로컬 파일', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('내 단어장', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        if (manager.wordbooks.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("저장된 단어장이 없습니다.")))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 330),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: manager.wordbooks.length,
              itemBuilder: (context, index) {
                final wordbook = manager.wordbooks[index];
                final isActive = manager.activeWordbook?.id == wordbook.id;
                return Card(
                  elevation: isActive ? 4 : 1,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isActive ? theme.primaryColor : Colors.transparent,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: _getSourceIcon(wordbook.source),
                    title: Text(wordbook.name),
                    onTap: () => manager.setActiveWordbook(wordbook),
                    trailing: IconButton(
                      icon: const Icon(CupertinoIcons.trash, color: Colors.grey),
                      onPressed: () => _confirmDelete(context, manager, wordbook),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // 학습/시험 설정 섹션
  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final allWords = context.watch<WordListNotifier>().words;
    final settings = settingsNotifier.settings;
    final double minValue = allWords.isEmpty ? 1.0 : 1.0;
    final double maxValue = allWords.isEmpty ? 1.0 : allWords.length.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('학습/시험 설정', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        EnhancedNeumorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('단어 수', style: theme.textTheme.bodyLarge),
              Row(
                children: [
                  Text(
                    '${settings.wordCount.clamp(minValue, maxValue).toInt()}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
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
        const SizedBox(height: 20),
        EnhancedNeumorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: DropdownButton<TestType>(
            value: settings.testType,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: theme.scaffoldBackgroundColor,
            items: const [
              DropdownMenuItem(value: TestType.random, child: Text('랜덤')),
              DropdownMenuItem(value: TestType.wordToMeaning, child: Text('단어 → 뜻')),
              DropdownMenuItem(value: TestType.meaningToWord, child: Text('뜻 → 단어')),
              DropdownMenuItem(
                value: TestType.meaningToWordWithHint,
                child: Text('뜻 → 단어 (첫 글자 힌트)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) settingsNotifier.setTestType(value);
            },
          ),
        ),
      ],
    );
  }

  // 내보내기 섹션
  Widget _buildExportSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('시험지 내보내기', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        EnhancedNeumorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: DropdownButton<ExportOption>(
            value: settings.exportOption,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: theme.scaffoldBackgroundColor,
            items: const [
              DropdownMenuItem(value: ExportOption.both, child: Text('시험지와 답안지 모두')),
              DropdownMenuItem(value: ExportOption.testOnly, child: Text('시험지만')),
              DropdownMenuItem(value: ExportOption.answersOnly, child: Text('답안지만')),
            ],
            onChanged: (value) {
              if (value != null) settingsNotifier.setExportOption(value);
            },
          ),
        ),
        const SizedBox(height: 20),
        _isExporting
            ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
            : EnhancedNeumorphicContainer(
              padding: const EdgeInsets.all(4),
              onTap: _showExportOptions,
              child: SizedBox(
                height: 50,
                child: Center(child: Text('파일로 내보내기', style: theme.textTheme.titleMedium)),
              ),
            ),
      ],
    );
  }

  // 앱 설정 섹션
  Widget _buildAppSettingSection(BuildContext context) {
    final theme = Theme.of(context);
    final themeNotifier = context.watch<ThemeNotifier>();
    final currentMode = themeNotifier.themeMode == ThemeMode.dark ? '켜짐' : '꺼짐';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('앱 설정', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        EnhancedNeumorphicContainer(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ListTile(
            leading: const Icon(CupertinoIcons.moon_stars),
            title: Text('다크 모드', style: theme.textTheme.bodyLarge),
            trailing: Text(currentMode, style: theme.textTheme.bodySmall),
            onTap: () {
              final newMode =
                  themeNotifier.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              themeNotifier.setThemeMode(newMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _getSourceIcon(WordbookSource source) {
    switch (source) {
      case WordbookSource.googleSheet:
        return Image.asset('assets/icons/google_sheet_icon.png', width: 24, height: 24);
      case WordbookSource.localCsv:
        return const Icon(CupertinoIcons.doc_text_fill, size: 24);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('시험지 내보내기', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 20),
              _buildExportRow('PDF', exportType: 'pdf', ctx: ctx),
              const Divider(height: 30),
              _buildExportRow('Excel', exportType: 'excel', ctx: ctx),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportRow(String format, {required String exportType, required BuildContext ctx}) {
    final theme = Theme.of(ctx);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(format, style: theme.textTheme.titleMedium),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _handleExport(type: exportType, share: false);
              },
              icon: const Icon(Icons.save_alt, size: 20),
              label: const Text('저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _handleExport(type: exportType, share: true);
              },
              icon: const Icon(Icons.share, size: 20),
              label: const Text('공유'),
            ),
          ],
        ),
      ],
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
