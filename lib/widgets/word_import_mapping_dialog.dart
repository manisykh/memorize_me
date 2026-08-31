import 'package:flutter/material.dart';

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
    builder: (_) => _WordImportMappingDialog(sheets: sheets, title: title),
  );
}

class _WordImportMappingDialog extends StatefulWidget {
  const _WordImportMappingDialog({required this.sheets, required this.title});

  final Map<String, List<List<Object?>>> sheets;
  final String title;

  @override
  State<_WordImportMappingDialog> createState() => _WordImportMappingDialogState();
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
    final count = _rows.take(20).fold<int>(0, (max, row) => row.length > max ? row.length : max);
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
    final columns = List<int>.generate(_columnCount, (index) => index);
    if (!columns.contains(_wordColumn)) _wordColumn = 0;
    if (!columns.contains(_primaryMeaningColumn) || _primaryMeaningColumn == _wordColumn) {
      _primaryMeaningColumn = _wordColumn == 0 ? 1 : 0;
    }
    _additionalMeaningColumns.removeWhere(
      (column) =>
          !columns.contains(column) || column == _wordColumn || column == _primaryMeaningColumn,
    );
    final previewRows = _rows.skip(_skipHeader ? 1 : 0).take(5).toList();
    final canImport = _wordColumn != _primaryMeaningColumn;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.sheets.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedSheet,
                  decoration: const InputDecoration(labelText: '워크시트'),
                  items:
                      widget.sheets.keys
                          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                          .toList(),
                  onChanged: (value) {
                    if (value != null) _changeSheet(value);
                  },
                ),
                const SizedBox(height: 12),
              ],
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
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('word-$_selectedSheet-$_wordColumn'),
                          initialValue: _wordColumn,
                          decoration: const InputDecoration(),
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
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<int>(
                          key: ValueKey('meaning-$_selectedSheet-$_primaryMeaningColumn'),
                          initialValue: _primaryMeaningColumn,
                          decoration: const InputDecoration(),
                          items: _columnItems(columns.where((column) => column != _wordColumn)),
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
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _skipHeader,
                title: const Text('첫 행을 제목으로 제외'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() => _skipHeader = value ?? false),
              ),
              if (_columnCount > 2) ...[
                const Divider(height: 24),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _showAdditionalMeanings,
                  title: const Text('추가 뜻도 표시'),
                  subtitle: const Text('선택한 열을 가져와 플래시카드, 힌트와 정답 해설에 표시합니다.'),
                  onChanged: (value) {
                    setState(() {
                      _showAdditionalMeanings = value;
                      if (value && _additionalMeaningColumns.isEmpty) {
                        final candidates = _detectMeaningColumns(_rows)
                          ..remove(_wordColumn)
                          ..remove(_primaryMeaningColumn);
                        _additionalMeaningColumns.addAll(candidates);
                      }
                    });
                  },
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
                                  column != _wordColumn && column != _primaryMeaningColumn,
                            )
                            .map(
                              (column) => FilterChip(
                                label: Text(_columnLabel(column)),
                                selected: _additionalMeaningColumns.contains(column),
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
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 18),
              Text('미리보기', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (previewRows.isEmpty)
                const Text('표시할 데이터가 없습니다.')
              else
                ...previewRows.map((row) => _buildPreviewRow(theme, row)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
        FilledButton(
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
                                ? (_additionalMeaningColumns.toList()..sort())
                                : const [],
                        skipHeader: _skipHeader,
                      ),
                    ),
                  )
                  : null,
          child: const Text('가져오기'),
        ),
      ],
    );
  }

  Widget _buildPreviewRow(ThemeData theme, List<Object?> row) {
    final additional =
        (_additionalMeaningColumns.toList()..sort())
            .map((column) => _cellText(row, column))
            .where((value) => value.isNotEmpty)
            .toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _cellText(row, _wordColumn),
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(_cellText(row, _primaryMeaningColumn)),
          if (_showAdditionalMeanings && additional.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              additional.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            child: Text(_columnLabel(column), overflow: TextOverflow.ellipsis),
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
