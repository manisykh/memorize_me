import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:provider/provider.dart';

import '../providers/wordbook_manager.dart';
import '../services/sheets_service.dart';

class SelectSheetScreen extends StatefulWidget {
  final String spreadsheetId;
  final String spreadsheetName;

  const SelectSheetScreen({super.key, required this.spreadsheetId, required this.spreadsheetName});

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
    _sheetsFuture = context.read<SheetsService>().getSheetInfo(widget.spreadsheetId);
  }

  Future<void> _importSelectedSheets() async {
    if (_selectedSheets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('가져올 시트를 1개 이상 선택해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    final manager = context.read<WordbookManager>();
    await manager.createMultipleWordbooksFromSheets(_selectedSheets.toList(), widget.spreadsheetId);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_selectedSheets.length}개의 단어장을 가져왔습니다.')));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 버튼의 활성화 여부를 결정하는 변수
    final canImport = !_isLoading && _selectedSheets.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('"${widget.spreadsheetName}"'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '단어를 가져올 시트를 선택하세요 (다중 선택 가능)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        // ▼▼▼ [수정] AppBar의 actions에 '가져오기' 버튼 추가 ▼▼▼
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: FilledButton.icon(
                icon:
                    _isLoading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                        : const Icon(Icons.download, size: 18),
                label: Text(_isLoading ? '가져오는 중...' : '${_selectedSheets.length}개 가져오기'),
                onPressed: canImport ? _importSelectedSheets : null, // 조건에 따라 버튼 비활성화
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<sheets.Sheet>>(
        future: _sheetsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('시트 정보를 불러오는 중 오류 발생:\n${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('파일에 시트가 없습니다.'));
          }

          final sheets = snapshot.data!;
          return ListView.builder(
            itemCount: sheets.length,
            itemBuilder: (context, index) {
              final sheet = sheets[index];
              final sheetTitle = sheet.properties?.title ?? '이름 없는 시트';
              final isSelected = _selectedSheets.contains(sheet);

              return CheckboxListTile(
                secondary: const Icon(CupertinoIcons.doc_plaintext),
                title: Text(sheetTitle),
                value: isSelected,
                onChanged:
                    _isLoading
                        ? null
                        : (bool? value) {
                          // 로딩 중에는 체크박스도 비활성화
                          setState(() {
                            if (value == true) {
                              _selectedSheets.add(sheet);
                            } else {
                              _selectedSheets.remove(sheet);
                            }
                          });
                        },
              );
            },
          );
        },
      ),
      // ▼▼▼ [제거] 기존 플로팅 액션 버튼 제거 ▼▼▼
      // floatingActionButton: ...
    );
  }
}
