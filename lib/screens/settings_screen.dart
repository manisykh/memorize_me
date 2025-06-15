import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../services/sheets_service.dart';
import '../services/test_sheet_service.dart';
import '../themes/app_theme.dart';
import '../widgets/enhanced_neumorphic_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isSyncing = false;

  void _showExportOptions() {
    final allWords = context.read<WordListNotifier>().words;
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('단어를 먼저 추가해주세요.')));
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('시험지 내보내기', style: theme.textTheme.titleLarge),
              const SizedBox(height: 20),
              _buildExportRow('PDF', exportType: 'pdf'),
              const Divider(height: 30),
              _buildExportRow('Excel', exportType: 'excel'),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportRow(String format, {required String exportType}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(format, style: theme.textTheme.titleMedium),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
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
                Navigator.pop(context);
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
    } catch (e, s) {
      debugPrint('파일 생성/공유 중 오류: $e');
      debugPrint('Stack trace: $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('작업 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // 구글 시트 동기화를 처리하는 새로운 메서드
  Future<void> _syncFromGoogleSheets() async {
    setState(() => _isSyncing = true);

    const String spreadsheetId = '1DzZb0pyVBAwfIY2XQMaXmJ1wzmyxk83b_mM7SVOrnps';
    const String sheetName = 'Sheet1'; // 데이터를 가져올 시트 이름

    try {
      final sheetsService = context.read<SheetsService>();
      final wordListNotifier = context.read<WordListNotifier>();

      final List<Word>? newWords = await sheetsService.getWordsFromSheet(spreadsheetId, sheetName);

      if (newWords != null && mounted) {
        // 가져온 단어들로 교체 (혹은 추가, 옵션 제공 가능)
        await wordListNotifier.deleteAllWords();
        for (final word in newWords) {
          await wordListNotifier.addWord(word);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${newWords.length}개의 단어를 성공적으로 가져왔습니다.')));
      } else if (mounted) {
        throw Exception('시트에서 단어를 가져오지 못했습니다.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('동기화 오류: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // 로그인/로그아웃 상태를 표시하는 위젯
  Widget _buildAuthSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    if (authProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final user = authProvider.currentUser;

    if (user != null) {
      // 로그인된 상태 UI
      return Column(
        children: [
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
                tooltip: '로그아웃',
              ),
            ),
          ),
          const SizedBox(height: 15),
          // 동기화 버튼 추가
          if (_isSyncing)
            const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
          else
            EnhancedNeumorphicContainer(
              onTap: _syncFromGoogleSheets,
              padding: const EdgeInsets.all(4),
              child: SizedBox(
                height: 50,
                child: Center(
                  child: Text('Google Sheets에서 단어 가져오기', style: theme.textTheme.titleMedium),
                ),
              ),
            ),
        ],
      );
    } else {
      // 로그아웃된 상태 UI
      return EnhancedNeumorphicContainer(
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsNotifier = context.watch<SettingsNotifier>();
    final allWords = context.watch<WordListNotifier>().words;
    final themeNotifier = context.watch<ThemeNotifier>();

    final settings = settingsNotifier.settings;
    final double minValue = 1.0;
    final double maxValue = allWords.isEmpty ? 1.0 : allWords.length.toDouble();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('학습/시험 설정', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
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
          ),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: DropdownButton<TestType>(
                value: settings.testType,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: theme.scaffoldBackgroundColor,
                items: [
                  DropdownMenuItem(
                    value: TestType.random,
                    child: Text('랜덤', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: TestType.wordToMeaning,
                    child: Text('단어 → 뜻', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: TestType.meaningToWord,
                    child: Text('뜻 → 단어', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: TestType.meaningToWordWithHint,
                    child: Text('뜻 → 단어 (첫 글자 힌트)', style: theme.textTheme.bodyMedium),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setTestType(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text('내보내기', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: DropdownButton<ExportOption>(
                value: settings.exportOption,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: theme.scaffoldBackgroundColor,
                items: [
                  DropdownMenuItem(
                    value: ExportOption.both,
                    child: Text('시험지와 답안지 모두', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: ExportOption.testOnly,
                    child: Text('시험지만', style: theme.textTheme.bodyMedium),
                  ),
                  DropdownMenuItem(
                    value: ExportOption.answersOnly,
                    child: Text('답안지만', style: theme.textTheme.bodyMedium),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settingsNotifier.setExportOption(value);
                  }
                },
              ),
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
                  child: Center(child: Text('시험지 내보내기', style: theme.textTheme.titleMedium)),
                ),
              ),
          const SizedBox(height: 30),
          Text('계정 연동', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          _buildAuthSection(context),
          const SizedBox(height: 30),
          Text('앱 설정', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: EnhancedNeumorphicContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('다크 모드', style: theme.textTheme.bodyLarge),
                  Switch(
                    value: themeNotifier.themeMode == ThemeMode.dark,
                    onChanged:
                        (value) =>
                            themeNotifier.setThemeMode(value ? ThemeMode.dark : ThemeMode.light),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              '총 ${allWords.length}개의 단어가 저장되어 있습니다.',
              style: TextStyle(
                color:
                    theme.brightness == Brightness.light
                        ? AppTheme.subTextLight
                        : AppTheme.subTextDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
