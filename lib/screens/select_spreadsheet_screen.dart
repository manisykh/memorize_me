import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../services/google_picker_service.dart';
import '../services/sheets_service.dart';
import '../themes/memorize_identity.dart';
import 'select_sheet_screen.dart';

class SelectSpreadsheetScreen extends StatefulWidget {
  const SelectSpreadsheetScreen({super.key});

  @override
  State<SelectSpreadsheetScreen> createState() =>
      _SelectSpreadsheetScreenState();
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
      selectedAt:
          DateTime.tryParse(value['selectedAt']?.toString() ?? '') ??
          DateTime.now(),
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
  bool _showAdvancedInput = false;

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
    final rawItems =
        prefs.getStringList(_recentSpreadsheetsKey) ?? const <String>[];
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
    final next =
        [
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

    final pathMatch = RegExp(
      r'/spreadsheets/d/([a-zA-Z0-9-_]+)',
    ).firstMatch(value);
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
    if (!mounted) return;

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
      final spreadsheetName =
          await context.read<SheetsService>().getSpreadsheetTitle(picked.id) ??
          picked.name;
      if (!mounted) return;
      await _openSheetSelector(
        spreadsheetId: picked.id,
        spreadsheetName: spreadsheetName,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
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
    final authProvider = context.watch<AuthProvider>();
    final isGoogleConnected = authProvider.isGoogleDriveConnected;
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('Google 시트 가져오기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: identity.surface,
                borderRadius: BorderRadius.circular(
                  MemorizeIdentity.cardRadius,
                ),
                border: Border.all(color: identity.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: identity.softSuccess,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset('assets/icons/google_sheet_icon.png'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '시트를 골라 바로 시작하세요',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: identity.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Drive에서 선택한 시트만 단어장으로 가져옵니다.',
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isPicking ? null : _pickWithGooglePicker,
              icon:
                  _isPicking
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(CupertinoIcons.folder_open),
              label: Text(
                _isPicking
                    ? 'Google Drive 여는 중...'
                    : isGoogleConnected
                    ? 'Google Drive에서 선택'
                    : 'Google 계정 연결하고 시트 선택',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.lock, size: 15, color: identity.mutedInk),
                const SizedBox(width: 5),
                Text(
                  '선택한 시트만 접근합니다',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: identity.surface,
                borderRadius: BorderRadius.circular(
                  MemorizeIdentity.cardRadius,
                ),
                border: Border.all(color: identity.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                initiallyExpanded: _showAdvancedInput,
                onExpansionChanged:
                    (value) => setState(() => _showAdvancedInput = value),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: identity.softInfo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    CupertinoIcons.link,
                    color: identity.primaryAction,
                  ),
                ),
                title: Text(
                  'URL 또는 ID로 열기',
                  style: TextStyle(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '이전에 Drive에서 허용한 시트',
                  style: TextStyle(color: identity.mutedInk),
                ),
                children: [
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
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Google Drive에서 한 번 이상 선택한 시트만 열 수 있습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '최근 선택한 스프레드시트',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_recentSpreadsheets.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearRecentSpreadsheets,
                    icon: const Icon(CupertinoIcons.trash, size: 17),
                    label: const Text('기록 지우기'),
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
                title: '최근 시트가 없습니다',
                message: '한 번 선택한 시트는 다음부터 여기에서 바로 열 수 있습니다.',
              )
            else
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
                  children:
                      _recentSpreadsheets.indexed.map((indexed) {
                        final item = indexed.$2;
                        return Column(
                          children: [
                            if (indexed.$1 > 0)
                              Divider(height: 1, color: identity.border),
                            ListTile(
                              minTileHeight: 72,
                              leading: Container(
                                width: 42,
                                height: 42,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: identity.softSuccess,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Image.asset(
                                  'assets/icons/google_sheet_icon.png',
                                ),
                              ),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: identity.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '최근 선택 · ${_selectedDateLabel(item.selectedAt)}',
                                style: TextStyle(color: identity.mutedInk),
                              ),
                              trailing: Icon(
                                CupertinoIcons.chevron_right,
                                size: 20,
                                color: identity.mutedInk,
                              ),
                              onTap:
                                  () => _openSheetSelector(
                                    spreadsheetId: item.id,
                                    spreadsheetName: item.name,
                                  ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
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
    final identity = MemorizeIdentity.of(Theme.of(context));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: identity.surface,
        border: Border.all(color: identity.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: identity.primaryAction),
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
