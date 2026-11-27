import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:memorize_app/providers/auth_provider.dart';
import 'package:memorize_app/screens/select_sheet_screen.dart';
import 'package:memorize_app/screens/select_spreadsheet_screen.dart';
import 'package:memorize_app/services/sheets_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Account implements GoogleSignInAccount {
  @override
  String get email => 'study@example.test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  GoogleSignInAccount get currentUser => _Account();
  @override
  void usePickerAccessToken(String accessToken) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sheets implements SheetsService {
  int titleCalls = 0;
  int infoCalls = 0;
  Object? error;
  Completer<String?>? pendingTitle;

  @override
  Future<String?> getSpreadsheetTitle(String id) async {
    titleCalls++;
    if (error != null) throw error!;
    return pendingTitle == null ? '최신 단어장 이름' : pendingTitle!.future;
  }

  @override
  Future<List<sheets.Sheet>> getSheetInfo(String id) async {
    infoCalls++;
    return [
      sheets.Sheet(
        properties: sheets.SheetProperties(title: 'Unit 1', sheetId: 0),
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _historyKey = 'recent_google_spreadsheets';
const _channel = MethodChannel('memorize_me/google_picker');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Auth auth;
  late _Sheets service;
  late int pickerCalls;
  late String storedHistory;

  setUp(() {
    auth = _Auth();
    service = _Sheets();
    pickerCalls = 0;
    storedHistory = jsonEncode({
      'id': 'recent-file',
      'name': '기존 단어장',
      'selectedAt': '2026-01-01T12:00:00.000',
    });
    SharedPreferences.setMockInitialValues({
      _historyKey: [storedHistory],
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          pickerCalls++;
          return {
            'id': 'new-file',
            'name': 'Google Sheets',
            'accessToken': 'test-token',
          };
        });
  });

  tearDown(() {
    auth.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  Future<void> openScreen(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          Provider<SheetsService>.value(value: service),
        ],
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
          home: const SelectSpreadsheetScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'recent sheet skips Google picker, refreshes its name and reuses metadata',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('기존 단어장'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectSheetScreen), findsOneWidget);
      expect(find.text('최신 단어장 이름'), findsOneWidget);
      expect(service.titleCalls, 1);
      expect(service.infoCalls, 1);
      expect(pickerCalls, 0);
      final history =
          (await SharedPreferences.getInstance()).getStringList(_historyKey)!;
      expect(jsonDecode(history.first)['name'], '최신 단어장 이름');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'denied access keeps history and opens Google picker only on explicit recovery',
    (tester) async {
      service.error = Exception(
        '이 앱에 허용되지 않은 스프레드시트입니다. Google Drive에서 파일을 다시 선택해주세요.',
      );
      await openScreen(tester);
      await tester.tap(find.text('기존 단어장'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectSheetScreen), findsNothing);
      expect(find.text('Drive에서 다시 선택'), findsOneWidget);
      expect(pickerCalls, 0);
      expect(
        (await SharedPreferences.getInstance()).getStringList(_historyKey),
        [storedHistory],
      );
      service.error = null;
      await tester.tap(find.text('Drive에서 다시 선택'));
      await tester.pumpAndSettle();
      expect(pickerCalls, 1);
      expect(
        tester
            .widget<SelectSheetScreen>(find.byType(SelectSheetScreen))
            .spreadsheetId,
        'new-file',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'network failure offers retry without asking for file permissions again',
    (tester) async {
      service.error = Exception('네트워크 연결을 확인해주세요.');
      await openScreen(tester);
      await tester.tap(find.text('기존 단어장'));
      await tester.pumpAndSettle();
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.text('Drive에서 다시 선택'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getStringList(_historyKey),
        [storedHistory],
      );
      service.error = null;
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectSheetScreen), findsOneWidget);
      expect(pickerCalls, 0);
    },
  );

  testWidgets(
    'large text fits a narrow screen and repeated taps open only one sheet',
    (tester) async {
      service.pendingTitle = Completer<String?>();
      await openScreen(tester, scale: 1.4);
      expect(tester.takeException(), isNull);
      expect(find.text('새 시트 가져오기').hitTestable(), findsOneWidget);
      await tester.tap(find.text('기존 단어장'));
      await tester.pump();
      await tester.tap(find.text('기존 단어장'));
      expect(service.titleCalls, 1);
      service.pendingTitle!.complete('최신 단어장 이름');
      await tester.pumpAndSettle();
      expect(find.byType(SelectSheetScreen), findsOneWidget);
      expect(service.infoCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
