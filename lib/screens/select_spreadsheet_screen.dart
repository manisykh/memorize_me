import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/google_picker_service.dart';
import 'select_sheet_screen.dart';

class SelectSpreadsheetScreen extends StatefulWidget {
  const SelectSpreadsheetScreen({super.key});

  @override
  State<SelectSpreadsheetScreen> createState() => _SelectSpreadsheetScreenState();
}

class _RecentSpreadsheet {
  final String id;
  final String name;
  final DateTime selectedAt;

  const _RecentSpreadsheet({
    required this.id,
    required this.name,
    required this.selectedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'selectedAt': selectedAt.toIso8601String(),
  };

  static _RecentSpreadsheet? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return _RecentSpreadsheet(
      id: id,
      name: value['name']?.toString() ?? 'Google Sheets',
      selectedAt: DateTime.tryParse(value['selectedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class _SelectSpreadsheetScreenState extends State<SelectSpreadsheetScreen> {
  static const _recentSpreadsheetsKey = 'recent_google_spreadsheets';
  static const _maxRecentSpreadsheets = 10;

  final _formKey = GlobalKey<FormState>();
  final _spreadsheetInputController = TextEditingController();
  List<_RecentSpreadsheet> _recentSpreadsheets = const [];
  bool _isLoadingRecent = true;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSpreadsheets();
  }

  @override
  void dispose() {
    _spreadsheetInputController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSpreadsheets() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_recentSpreadsheetsKey) ?? const <String>[];
    final items =
        rawItems
            .map((raw) {
              try {
                return _RecentSpreadsheet.fromJson(jsonDecode(raw));
              } catch (_) {
                return null;
              }
            })
            .whereType<_RecentSpreadsheet>()
            .toList()
          ..sort((a, b) => b.selectedAt.compareTo(a.selectedAt));

    if (!mounted) return;
    setState(() {
      _recentSpreadsheets = items;
      _isLoadingRecent = false;
    });
  }

  Future<void> _saveRecentSpreadsheet({
    required String spreadsheetId,
    required String spreadsheetName,
  }) async {
    final next = [
      _RecentSpreadsheet(
        id: spreadsheetId,
        name: spreadsheetName,
        selectedAt: DateTime.now(),
      ),
      ..._recentSpreadsheets.where((item) => item.id != spreadsheetId),
    ].take(_maxRecentSpreadsheets).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentSpreadsheetsKey,
      next.map((item) => jsonEncode(item.toJson())).toList(),
    );

    if (!mounted) return;
    setState(() => _recentSpreadsheets = next);
  }

  Future<void> _clearRecentSpreadsheets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSpreadsheetsKey);
    if (!mounted) return;
    setState(() => _recentSpreadsheets = const []);
  }

  String? _extractSpreadsheetId(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;

    final pathMatch = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(value);
    if (pathMatch != null) return pathMatch.group(1);

    final uri = Uri.tryParse(value);
    final queryId = uri?.queryParameters['id'];
    if (queryId != null && queryId.trim().isNotEmpty) return queryId.trim();

    if (RegExp(r'^[a-zA-Z0-9-_]{20,}$').hasMatch(value)) return value;
    return null;
  }

  Future<void> _openSheetSelector({
    required String spreadsheetId,
    required String spreadsheetName,
  }) async {
    await _saveRecentSpreadsheet(
      spreadsheetId: spreadsheetId,
      spreadsheetName: spreadsheetName,
    );

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder:
            (_) => SelectSheetScreen(
              spreadsheetId: spreadsheetId,
              spreadsheetName: spreadsheetName,
            ),
      ),
    );

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _pickWithGooglePicker() async {
    setState(() => _isPicking = true);
    try {
      final picker = GooglePickerService(context.read<AuthProvider>());
      final picked = await picker.pickSpreadsheet();
      if (picked == null || !mounted) return;
      await _openSheetSelector(
        spreadsheetId: picked.id,
        spreadsheetName: picked.name,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _continueWithInput() {
    if (!_formKey.currentState!.validate()) return;

    final input = _spreadsheetInputController.text.trim();
    final spreadsheetId = _extractSpreadsheetId(input)!;
    _openSheetSelector(
      spreadsheetId: spreadsheetId,
      spreadsheetName: 'Google Sheets',
    );
  }

  String _selectedDateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google 시트 가져오기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '가져올 스프레드시트를 선택하세요.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Google Drive 전체 읽기 권한 대신, 사용자가 직접 선택한 스프레드시트만 앱에서 사용합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isPicking ? null : _pickWithGooglePicker,
              icon:
                  _isPicking
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.folder_open),
              label: Text(_isPicking ? 'Google Drive 여는 중...' : 'Google Drive에서 선택'),
            ),
            const SizedBox(height: 12),
            _SpreadsheetInputCard(
              formKey: _formKey,
              controller: _spreadsheetInputController,
              onSubmit: _continueWithInput,
              validator:
                  (value) =>
                      _extractSpreadsheetId(value ?? '') == null
                          ? '올바른 Google 스프레드시트 URL 또는 ID를 입력해주세요.'
                          : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '최근 선택한 스프레드시트',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_recentSpreadsheets.isNotEmpty)
                  TextButton(
                    onPressed: _clearRecentSpreadsheets,
                    child: const Text('기록 지우기'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingRecent)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_recentSpreadsheets.isEmpty)
              const _InfoPanel(
                icon: Icons.history,
                title: '최근 선택 기록이 없습니다.',
                message: 'Google Drive에서 스프레드시트를 선택하면 다음부터 이곳에서 빠르게 다시 열 수 있습니다.',
              )
            else
              Column(
                children:
                    _recentSpreadsheets.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.table_chart),
                          title: Text(item.name),
                          subtitle: Text('최근 선택: ${_selectedDateLabel(item.selectedAt)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap:
                              () => _openSheetSelector(
                                spreadsheetId: item.id,
                                spreadsheetName: item.name,
                              ),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpreadsheetInputCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String? Function(String?) validator;

  const _SpreadsheetInputCard({
    required this.formKey,
    required this.controller,
    required this.onSubmit,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '스프레드시트 URL 또는 ID',
              hintText: 'https://docs.google.com/spreadsheets/d/...',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            validator: validator,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.link),
            label: const Text('URL/ID로 시트 선택'),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
