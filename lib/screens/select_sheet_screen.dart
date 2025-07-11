// lib/screens/select_sheet_screen.dart (수정된 전체 코드)

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
  // ▼▼▼ [추가] 여러 시트를 선택하기 위한 Set ▼▼▼
  final Set<sheets.Sheet> _selectedSheets = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sheetsFuture = context.read<SheetsService>().getSheetInfo(widget.spreadsheetId);
  }

  // ▼▼▼ [추가] 선택된 시트들을 단어장으로 가져오는 함수 ▼▼▼
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
      // 성공적으로 가져온 후, true 값을 반환하며 현재 화면을 닫습니다.
      Navigator.of(context).pop(true);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
          // ▼▼▼ [수정] ListTile을 CheckboxListTile로 변경 ▼▼▼
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
                onChanged: (bool? value) {
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
      // ▼▼▼ [추가] 선택한 시트들을 가져오는 FAB(플로팅 액션 버튼) ▼▼▼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _importSelectedSheets,
        label: _isLoading ? const Text('가져오는 중...') : Text('${_selectedSheets.length}개 시트 가져오기'),
        icon:
            _isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
                : const Icon(Icons.download),
      ),
    );
  }
}
