import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/analytics_service.dart';
import '../services/sheets_service.dart';
import '../services/word_data_parser.dart';
import '../themes/memorize_identity.dart';
import '../widgets/word_import_mapping_dialog.dart';

const String selectSheetImportResultDone = 'imported';
const String selectSheetImportResultStartStudy = 'startStudy';

class SelectSheetScreen extends StatefulWidget {
  final String spreadsheetId;
  final String spreadsheetName;

  const SelectSheetScreen({
    super.key,
    required this.spreadsheetId,
    required this.spreadsheetName,
  });

  @override
  State<SelectSheetScreen> createState() => _SelectSheetScreenState();
}

class _SelectSheetScreenState extends State<SelectSheetScreen> {
  late Future<List<sheets.Sheet>> _sheetsFuture;
  final Set<sheets.Sheet> _selectedSheets = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sheetsFuture = context.read<SheetsService>().getSheetInfo(
      widget.spreadsheetId,
    );
  }

  Future<void> _importSelectedSheets() async {
    if (_selectedSheets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가져올 시트를 1개 이상 선택해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    final sheetsService = context.read<SheetsService>();
    final preparedSheets = <sheets.Sheet, List<Word>>{};
    try {
      for (final sheet in _selectedSheets) {
        final sheetName = sheet.properties?.title;
        if (sheetName == null || sheetName.isEmpty) continue;
        final rows = await sheetsService.getRowsFromSheet(
          widget.spreadsheetId,
          sheetName,
        );
        if (!mounted) return;
        final selection = await showWordImportMappingDialog(
          context,
          sheets: {sheetName: rows},
          title: '"$sheetName" 데이터 확인',
        );
        if (selection == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
        final mapping = selection.mapping;
        final words = WordDataParser.parseMappedRows(
          rows,
          wordColumn: mapping.wordColumn,
          primaryMeaningColumn: mapping.primaryMeaningColumn,
          additionalMeaningColumns: mapping.additionalMeaningColumns,
          skipHeader: mapping.skipHeader,
        );
        if (words.isNotEmpty) preparedSheets[sheet] = words;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시트 데이터를 확인하는 중 오류가 발생했습니다: $error')),
      );
      return;
    }

    if (!mounted) return;
    final manager = context.read<WordbookManager>();
    final importedWordbooks = await manager.createMultipleWordbooksFromSheets(
      preparedSheets,
      widget.spreadsheetId,
    );
    if (importedWordbooks.isNotEmpty && mounted) {
      context.read<AnalyticsService>().logWordbookImported(
        source: 'google_sheets',
        wordbookCount: importedWordbooks.length,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('단어장을 가져왔습니다'),
              content: Text(
                importedWordbooks.isEmpty
                    ? '선택한 시트에서 새 단어장을 만들지 못했습니다. 시트 이름과 단어 데이터를 확인해주세요.'
                    : '${importedWordbooks.length}개의 단어장을 만들었습니다.\n첫 단어장 "${importedWordbooks.first.name}"을(를) 바로 학습할 수 있습니다.',
              ),
              actions: [
                TextButton(
                  onPressed:
                      () => Navigator.of(
                        dialogContext,
                      ).pop(selectSheetImportResultDone),
                  child: const Text('단어장 관리로 이동'),
                ),
                FilledButton(
                  onPressed:
                      importedWordbooks.isEmpty
                          ? null
                          : () => Navigator.of(
                            dialogContext,
                          ).pop(selectSheetImportResultStartStudy),
                  child: const Text('바로 학습하기'),
                ),
              ],
            ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(result ?? selectSheetImportResultDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canImport = !_isLoading && _selectedSheets.isNotEmpty;
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(
        title: Text(
          widget.spreadsheetName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: canImport ? _importSelectedSheets : null,
            child: Text(_isLoading ? '처리 중' : '가져오기'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<sheets.Sheet>>(
          future: _sheetsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('시트 정보를 불러오는 중 오류 발생:\n${snapshot.error}'),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('파일에 시트가 없습니다.'));
            }

            final sheetItems = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: identity.softContext,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        CupertinoIcons.square_list,
                        color: identity.primaryAction,
                        size: 30,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '가져올 시트를 선택하세요',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: identity.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '여러 시트를 선택하면 각각의 단어장으로 만듭니다.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: identity.mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_selectedSheets.length}개',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: identity.primaryAction,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ' 선택됨',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: identity.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: identity.surface,
                    borderRadius: BorderRadius.circular(
                      MemorizeIdentity.cardRadius,
                    ),
                    border: Border.all(color: identity.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final indexed in sheetItems.indexed) ...[
                        if (indexed.$1 > 0)
                          Divider(height: 1, color: identity.border),
                        _buildSheetRow(
                          sheet: indexed.$2,
                          identity: identity,
                          theme: theme,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: identity.surface,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: FilledButton(
            onPressed: canImport ? _importSelectedSheets : null,
            child: Text(
              _isLoading
                  ? '가져오는 중...'
                  : '선택한 시트 가져오기 (${_selectedSheets.length}개)',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetRow({
    required sheets.Sheet sheet,
    required MemorizeIdentity identity,
    required ThemeData theme,
  }) {
    final sheetTitle = sheet.properties?.title ?? '이름 없는 시트';
    final isSelected = _selectedSheets.contains(sheet);

    return Material(
      color: isSelected ? identity.softContext : identity.surface,
      child: InkWell(
        onTap:
            _isLoading
                ? null
                : () => setState(() {
                  if (isSelected) {
                    _selectedSheets.remove(sheet);
                  } else {
                    _selectedSheets.add(sheet);
                  }
                }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected ? identity.softInfo : identity.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  CupertinoIcons.doc_plaintext,
                  color:
                      isSelected ? identity.primaryAction : identity.mutedInk,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  sheetTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 28,
                color: isSelected ? identity.primaryAction : identity.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
