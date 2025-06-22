// screens/select_spreadsheet_screen.dart

import 'package:flutter/material.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/sheets_service.dart';
import 'select_sheet_screen.dart';

class SelectSpreadsheetScreen extends StatefulWidget {
  const SelectSpreadsheetScreen({super.key});

  @override
  State<SelectSpreadsheetScreen> createState() => _SelectSpreadsheetScreenState();
}

class _SelectSpreadsheetScreenState extends State<SelectSpreadsheetScreen> {
  late Future<List<drive.File>> _filesFuture;

  @override
  void initState() {
    super.initState();
    // 화면이 처음 로드될 때 파일 목록을 가져오는 요청을 시작합니다.
    _filesFuture = context.read<SheetsService>().listSpreadsheets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google 시트 파일 선택')),
      body: FutureBuilder<List<drive.File>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          // --- 로딩 중 ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // --- 에러 발생 시 ---
          if (snapshot.hasError) {
            return Center(child: Text('파일을 불러오는 중 오류가 발생했습니다.\n${snapshot.error}'));
          }
          // --- 데이터가 없을 때 (파일이 없을 때) ---
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('구글 드라이브에 스프레드시트 파일이 없습니다.'));
          }
          // --- 성공적으로 데이터를 가져왔을 때 ---
          final files = snapshot.data!;
          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final modifiedDate =
                  file.modifiedTime != null
                      ? DateFormat('yyyy.MM.dd').format(file.modifiedTime!)
                      : '날짜 정보 없음';

              return ListTile(
                leading:
                    file.iconLink != null
                        ? Image.network(file.iconLink!, width: 40, height: 40)
                        : const Icon(Icons.description),
                title: Text(file.name ?? '이름 없는 파일'),
                subtitle: Text('수정한 날짜: $modifiedDate'),
                onTap: () {
                  // ▼▼▼ 수정된 부분 ▼▼▼
                  if (file.id != null && file.name != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => SelectSheetScreen(
                              spreadsheetId: file.id!,
                              spreadsheetName: file.name!,
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('파일 정보가 올바르지 않습니다.')));
                  }
                  // ▲▲▲ 수정된 부분 ▲▲▲
                },
              );
            },
          );
        },
      ),
    );
  }
}
