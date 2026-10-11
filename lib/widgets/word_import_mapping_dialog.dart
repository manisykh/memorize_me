import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../themes/memorize_identity.dart';

class WordImportMapping {
  const WordImportMapping({
    required this.wordColumn,
    required this.primaryMeaningColumn,
    required this.additionalMeaningColumns,
    required this.skipHeader,
  });

  final int wordColumn;
  final int primaryMeaningColumn;
  final List<int> additionalMeaningColumns;
  final bool skipHeader;
}

class WordImportSelection {
  const WordImportSelection({required this.sheetName, required this.mapping});

  final String sheetName;
  final WordImportMapping mapping;
}

Future<WordImportSelection?> showWordImportMappingDialog(
  BuildContext context, {
  required Map<String, List<List<Object?>>> sheets,
  String title = '가져올 데이터 확인',
}) {
  return showDialog<WordImportSelection>(
    context: context,
    barrierColor: const Color(0x7309255A),
    builder: (_) => _WordImportMappingDialog(sheets: sheets, title: title),
  );
}

class _WordImportMappingDialog extends StatefulWidget {
  const _WordImportMappingDialog({required this.sheets, required this.title});

  final Map<String, List<List<Object?>>> sheets;
  final String title;

  @override
  State<_WordImportMappingDialog> createState() =>
      _WordImportMappingDialogState();
}

class _WordImportMappingDialogState extends State<_WordImportMappingDialog> {
  late String _selectedSheet;
  late bool _skipHeader;
  late int _wordColumn;
  late int _primaryMeaningColumn;
  Set<int> _additionalMeaningColumns = <int>{};
  bool _showAdditionalMeanings = false;

  List<List<Object?>> get _rows => widget.sheets[_selectedSheet] ?? const [];

  int get _columnCount {
    final count = _rows
        .take(20)
        .fold<int>(0, (max, row) => row.length > max ? row.length : max);
    return count.clamp(2, 26).toInt();
  }

  @override
  void initState() {
    super.initState();
    _selectedSheet = widget.sheets.keys.first;
    _resetMapping();
  }

  void _resetMapping() {
    _skipHeader = _looksLikeHeader(_rows);
    _wordColumn = _detectWordColumn(_rows);
    final meaningCandidates = _detectMeaningColumns(_rows)..remove(_wordColumn);
    _primaryMeaningColumn =
        meaningCandidates.isNotEmpty
            ? meaningCandidates.first
            : (_wordColumn == 0 ? 1 : 0);
    _additionalMeaningColumns = meaningCandidates.skip(1).toSet();
    _showAdditionalMeanings = _additionalMeaningColumns.isNotEmpty;
  }

  void _changeSheet(String sheetName) {
    setState(() {
      _selectedSheet = sheetName;
      _resetMapping();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final columns = List<int>.generate(_columnCount, (index) => index);
    if (!columns.contains(_wordColumn)) _wordColumn = 0;
    if (!columns.contains(_primaryMeaningColumn) ||
        _primaryMeaningColumn == _wordColumn) {
      _primaryMeaningColumn = _wordColumn == 0 ? 1 : 0;
    }
    _additionalMeaningColumns.removeWhere(
      (column) =>
          !columns.contains(column) ||
          column == _wordColumn ||
          column == _primaryMeaningColumn,
    );
    final previewRows = _rows.skip(_skipHeader ? 1 : 0).take(5).toList();
    final canImport = _wordColumn != _primaryMeaningColumn;

    return AlertDialog(
      backgroundColor: identity.canvas,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      title: Column(
        children: [
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: identity.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '가져오기 설정',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(CupertinoIcons.xmark, color: identity.ink),
              ),
            ],
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionLabel(
                icon: CupertinoIcons.square_grid_2x2,
                label: '워크시트',
                identity: identity,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedSheet,
                decoration: const InputDecoration(labelText: '시트 선택'),
                items:
                    widget.sheets.keys
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        )
                        .toList(),
                onChanged:
                    widget.sheets.length > 1
                        ? (value) {
                          if (value != null) _changeSheet(value);
                        }
                        : null,
              ),
              const SizedBox(height: 20),
              _SectionLabel(
                icon: CupertinoIcons.arrow_left_right,
                label: '열 연결',
                identity: identity,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '단어 열',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: identity.primaryAction,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('word-$_selectedSheet-$_wordColumn'),
                          isExpanded: true,
                          initialValue: _wordColumn,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          items: _columnItems(columns),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _wordColumn = value;
                              _additionalMeaningColumns.remove(value);
                              if (_primaryMeaningColumn == value) {
                                _primaryMeaningColumn = value == 0 ? 1 : 0;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '대표 뜻 열',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: identity.mutedInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey(
                            'meaning-$_selectedSheet-$_primaryMeaningColumn',
                          ),
                          isExpanded: true,
                          initialValue: _primaryMeaningColumn,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
                            ),
                          ),
                          items: _columnItems(
                            columns.where((column) => column != _wordColumn),
                          ),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _primaryMeaningColumn = value;
                              _additionalMeaningColumns.remove(value);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: identity.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: identity.border),
                ),
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  value: _skipHeader,
                  title: Text(
                    '첫 행을 제목으로 제외',
                    style: TextStyle(
                      color: identity.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged:
                      (value) => setState(() => _skipHeader = value ?? false),
                ),
              ),
              if (_columnCount > 2) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: identity.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: identity.border),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    value: _showAdditionalMeanings,
                    title: Text(
                      '추가 뜻도 표시',
                      style: TextStyle(
                        color: identity.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '플래시카드, 힌트와 정답 해설에 함께 표시합니다.',
                      style: TextStyle(color: identity.mutedInk),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _showAdditionalMeanings = value;
                        if (value && _additionalMeaningColumns.isEmpty) {
                          final candidates =
                              _detectMeaningColumns(_rows)
                                ..remove(_wordColumn)
                                ..remove(_primaryMeaningColumn);
                          _additionalMeaningColumns.addAll(candidates);
                        }
                      });
                    },
                  ),
                ),
                if (_showAdditionalMeanings) ...[
                  const SizedBox(height: 8),
                  Text('추가 뜻 열 선택', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        columns
                            .where(
                              (column) =>
                                  column != _wordColumn &&
                                  column != _primaryMeaningColumn,
                            )
                            .map(
                              (column) => FilterChip(
                                label: Text(_columnLabel(column)),
                                selected: _additionalMeaningColumns.contains(
                                  column,
                                ),
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _additionalMeaningColumns.add(column);
                                    } else {
                                      _additionalMeaningColumns.remove(column);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(),
                  ),
                  if (_additionalMeaningColumns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '선택하지 않으면 대표 뜻만 가져옵니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                        ),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 18),
              _SectionLabel(
                icon: CupertinoIcons.eye,
                label: '미리보기',
                identity: identity,
              ),
              const SizedBox(height: 8),
              if (previewRows.isEmpty)
                const Text('표시할 데이터가 없습니다.')
              else
                ...previewRows.map(
                  (row) => _buildPreviewRow(theme, identity, row),
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed:
                      canImport
                          ? () => Navigator.of(context).pop(
                            WordImportSelection(
                              sheetName: _selectedSheet,
                              mapping: WordImportMapping(
                                wordColumn: _wordColumn,
                                primaryMeaningColumn: _primaryMeaningColumn,
                                additionalMeaningColumns:
                                    _showAdditionalMeanings
                                        ? (_additionalMeaningColumns.toList()
                                          ..sort())
                                        : const [],
                                skipHeader: _skipHeader,
                              ),
                            ),
                          )
                          : null,
                  child: const Text('가져오기'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(
    ThemeData theme,
    MemorizeIdentity identity,
    List<Object?> row,
  ) {
    final additional =
        (_additionalMeaningColumns.toList()..sort())
            .map((column) => _cellText(row, column))
            .where((value) => value.isNotEmpty)
            .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cellText(row, _wordColumn),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(_cellText(row, _primaryMeaningColumn)),
          if (_showAdditionalMeanings && additional.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              additional.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: identity.mutedInk,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<int>> _columnItems(Iterable<int> columns) {
    return columns
        .map(
          (column) => DropdownMenuItem<int>(
            value: column,
            child: Text(
              _columnLabel(column),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  String _columnLabel(int index) {
    final name = '${String.fromCharCode(65 + index)}열';
    if (!_skipHeader || _rows.isEmpty) return name;
    final header = _cellText(_rows.first, index);
    return header.isEmpty ? name : '$name · $header';
  }

  int _detectWordColumn(List<List<Object?>> rows) {
    if (rows.isEmpty) return 0;
    for (var index = 0; index < rows.first.length; index++) {
      if (_isWordHeader(_cellText(rows.first, index))) return index;
    }
    return 0;
  }

  Set<int> _detectMeaningColumns(List<List<Object?>> rows) {
    if (rows.isEmpty) return <int>{};
    final result = <int>{};
    for (var index = 0; index < rows.first.length; index++) {
      if (_isMeaningHeader(_cellText(rows.first, index))) result.add(index);
    }
    return result;
  }

  bool _looksLikeHeader(List<List<Object?>> rows) {
    if (rows.isEmpty) return false;
    final values = rows.first.map((cell) => cell?.toString().trim() ?? '');
    return values.any(_isWordHeader) && values.any(_isMeaningHeader);
  }

  bool _isWordHeader(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return normalized == '단어' ||
        normalized == 'word' ||
        normalized == 'vocabulary' ||
        normalized == 'term';
  }

  bool _isMeaningHeader(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    return normalized.contains('뜻') ||
        normalized.contains('의미') ||
        normalized.contains('meaning') ||
        normalized.contains('definition') ||
        normalized.contains('translation');
  }

  String _cellText(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.toString().trim() ?? '';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.identity,
  });

  final IconData icon;
  final String label;
  final MemorizeIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: identity.primaryAction),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
