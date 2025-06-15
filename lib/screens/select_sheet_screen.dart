// screens/select_sheet_screen.dart

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
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sheetsFuture = context.read<SheetsService>().getSheetInfo(widget.spreadsheetId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            child: Text('단어를 가져올 시트를 선택하세요', style: Theme.of(context).textTheme.titleSmall),
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
          return ListView.builder(
            itemCount: sheets.length,
            itemBuilder: (context, index) {
              final sheet = sheets[index];
              final sheetTitle = sheet.properties?.title ?? '이름 없는 시트';

              return ListTile(
                leading: const Icon(CupertinoIcons.doc_plaintext),
                title: Text(sheetTitle),
                onTap: () => _onSheetSelected(context, sheet),
              );
            },
          );
        },
      ),
    );
  }

  void _onSheetSelected(BuildContext context, sheets.Sheet sheet) {
    final sheetTitle = sheet.properties?.title;
    if (sheetTitle == null) return;

    // 단어장 이름을 입력받는 다이얼로그를 띄웁니다.
    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        _nameController.text = sheetTitle; // 기본값으로 시트 이름을 제안
        return CupertinoAlertDialog(
          title: const Text('단어장 이름 지정'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: CupertinoTextField(
              controller: _nameController,
              placeholder: '단어장 이름을 입력하세요',
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('생성'),
              onPressed: () {
                final newName = _nameController.text.trim();
                if (newName.isEmpty) return;

                // 단어장 생성 로직 호출
                context.read<WordbookManager>().createNewWordbook(
                  name: newName,
                  spreadsheetId: widget.spreadsheetId,
                  sheetName: sheetTitle,
                );

                // 생성 화면들을 모두 닫고 단어장 목록 첫 화면으로 돌아갑니다.
                Navigator.of(dialogContext).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }
}
