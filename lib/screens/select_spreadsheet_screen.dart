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
  String? _openingSpreadsheetId;
  String? _openError;
  bool _needsAccess = false;
  _RecentSpreadsheet? _failedSpreadsheet;
  String? _historyError;

  bool get _busy =>
      _isLoadingRecent || _isPicking || _openingSpreadsheetId != null;

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
    try {
      final prefs = await SharedPreferences.getInstance();
      final items =
          (prefs.getStringList(_recentSpreadsheetsKey) ?? const <String>[])
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
      if (mounted) {
        setState(
          () =>
              _recentSpreadsheets = items.take(_maxRecentSpreadsheets).toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _historyError = '최근 기록을 불러오지 못했습니다. 새 시트는 계속 가져올 수 있습니다.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRecent = false);
    }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setStringList(
        _recentSpreadsheetsKey,
        next.map((item) => jsonEncode(item.toJson())).toList(),
      );
      if (!saved) throw StateError('History was not saved');
      if (mounted) setState(() => _historyError = null);
    } catch (_) {
      if (mounted) {
        setState(() => _historyError = '시트는 열었지만 이 기기에 최근 기록을 저장하지 못했습니다.');
      }
    }
    if (mounted) setState(() => _recentSpreadsheets = next);
  }

  Future<void> _clearRecentSpreadsheets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove(_recentSpreadsheetsKey)) {
        throw StateError('History was not cleared');
      }
      if (!mounted) return;
      setState(() {
        _recentSpreadsheets = const [];
        _historyError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 기기의 최근 기록을 지웠습니다. 원본 시트와 단어장은 유지됩니다.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _historyError = '최근 기록을 지우지 못했습니다. 다시 시도해 주세요.');
      }
    }
  }

  String? _extractSpreadsheetId(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    final pathMatch = RegExp(
      r'/spreadsheets/d/([a-zA-Z0-9-_]+)',
    ).firstMatch(value);
    if (pathMatch != null) return pathMatch.group(1);
    final queryId = Uri.tryParse(value)?.queryParameters['id'];
    if (queryId != null && queryId.trim().isNotEmpty) return queryId.trim();
    return RegExp(r'^[a-zA-Z0-9-_]{20,}$').hasMatch(value) ? value : null;
  }

  Future<void> _openSheetSelector({
    required String spreadsheetId,
    required String spreadsheetName,
  }) async {
    if (_openingSpreadsheetId != null) return;
    setState(() {
      _openingSpreadsheetId = spreadsheetId;
      _openError = null;
      _failedSpreadsheet = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final service = context.read<SheetsService>();
      if (auth.currentUser == null) await auth.signIn();
      if (!mounted) return;
      if (auth.currentUser == null) {
        throw Exception('시트를 열려면 Google 계정을 연결해 주세요.');
      }

      // Check access before navigating or changing history. Reuse the sheet
      // metadata on the next screen instead of requesting it a second time.
      final title = await service.getSpreadsheetTitle(spreadsheetId);
      final sheets = await service.getSheetInfo(spreadsheetId);
      if (!mounted) return;
      final name = title?.trim().isNotEmpty == true ? title! : spreadsheetName;
      await _saveRecentSpreadsheet(
        spreadsheetId: spreadsheetId,
        spreadsheetName: name,
      );
      if (!mounted) return;
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder:
              (_) => SelectSheetScreen(
                spreadsheetId: spreadsheetId,
                spreadsheetName: name,
                initialSheets: sheets,
              ),
        ),
      );
      if (result != null && mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _openError = message;
        _needsAccess = [
          '허용',
          '인증',
          '로그인',
          '계정을 연결',
          '권한',
        ].any(message.contains);
        _failedSpreadsheet = _RecentSpreadsheet(
          id: spreadsheetId,
          name: spreadsheetName,
          selectedAt: DateTime.now(),
        );
      });
    } finally {
      if (mounted) setState(() => _openingSpreadsheetId = null);
    }
  }

  Future<void> _pickWithGooglePicker() async {
    if (_busy) return;
    setState(() {
      _isPicking = true;
      _openError = null;
      _failedSpreadsheet = null;
    });
    try {
      final picked =
          await GooglePickerService(
            context.read<AuthProvider>(),
          ).pickSpreadsheet();
      if (picked == null || !mounted) return;
      await _openSheetSelector(
        spreadsheetId: picked.id,
        spreadsheetName: picked.name,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _openError = error.toString().replaceFirst('Exception: ', '');
        _needsAccess = true;
      });
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _continueWithInput() {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    _openSheetSelector(
      spreadsheetId: _extractSpreadsheetId(_spreadsheetInputController.text)!,
      spreadsheetName: 'Google Sheets',
    );
  }

  String _selectedDateLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '오늘 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('Google 시트 가져오기')),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: identity.surface,
          border: Border(top: BorderSide(color: identity.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _pickWithGooglePicker,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      icon:
                          _isPicking
                              ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(CupertinoIcons.add, size: 20),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          _isPicking ? '시트 연결 중…' : '새 시트 가져오기',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Google Drive에서 선택한 파일만 접근합니다.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SheetIcon(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '사용하던 시트를 바로 열어요',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: identity.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '새 파일은 아래에서 가져올 수 있어요.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: identity.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.person_crop_circle,
                      size: 18,
                      color: identity.mutedInk,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        account?.email ?? '시트를 열 때 Google 계정을 연결합니다.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_openError != null) ...[
                  const SizedBox(height: 16),
                  _buildOpenError(theme, identity),
                ],
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      '최근 사용한 시트',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_recentSpreadsheets.isNotEmpty)
                      TextButton(
                        onPressed: _busy ? null : _clearRecentSpreadsheets,
                        child: const Text('기록 지우기'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_isLoadingRecent)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_recentSpreadsheets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 12,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 32,
                          color: identity.mutedInk,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '아직 사용한 시트가 없어요',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: identity.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '새 시트를 한 번 선택하면\n다음부터 여기에서 바로 열 수 있어요.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: identity.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._recentSpreadsheets.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: identity.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: identity.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap:
                              _busy
                                  ? null
                                  : () => _openSheetSelector(
                                    spreadsheetId: item.id,
                                    spreadsheetName: item.name,
                                  ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const _SheetIcon(size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: identity.ink,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '최근 사용 · ${_selectedDateLabel(item.selectedAt)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: identity.mutedInk,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (_openingSpreadsheetId == item.id)
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    size: 16,
                                    color: identity.mutedInk,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_historyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _historyError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildUrlInput(theme, identity),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenError(ThemeData theme, MemorizeIdentity identity) {
    final failed = _failedSpreadsheet;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: identity.softContext,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _needsAccess ? '시트 연결을 확인해 주세요' : '시트를 열지 못했어요',
              style: theme.textTheme.titleSmall?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _openError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: identity.mutedInk,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (failed != null)
                  TextButton(
                    onPressed:
                        _busy
                            ? null
                            : () => _openSheetSelector(
                              spreadsheetId: failed.id,
                              spreadsheetName: failed.name,
                            ),
                    child: const Text('다시 시도'),
                  ),
                if (_needsAccess)
                  TextButton.icon(
                    onPressed: _busy ? null : _pickWithGooglePicker,
                    icon: const Icon(CupertinoIcons.folder_open, size: 18),
                    label: const Text('Drive에서 다시 선택'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput(ThemeData theme, MemorizeIdentity identity) {
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        leading: Icon(CupertinoIcons.link, size: 21, color: identity.mutedInk),
        title: Text(
          '링크로 시트 열기',
          style: theme.textTheme.titleSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '이전에 접근을 허용한 파일',
          style: theme.textTheme.bodySmall?.copyWith(color: identity.mutedInk),
        ),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _spreadsheetInputController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '스프레드시트 URL 또는 ID',
                    hintText: 'https://docs.google.com/spreadsheets/d/…',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _continueWithInput(),
                  validator:
                      (value) =>
                          _extractSpreadsheetId(value ?? '') == null
                              ? '올바른 Google 스프레드시트 URL 또는 ID를 입력해 주세요.'
                              : null,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : _continueWithInput,
                  child: const Text('링크로 열기'),
                ),
                const SizedBox(height: 6),
                Text(
                  '처음 가져오는 파일은 ‘새 시트 가져오기’에서 선택해 주세요.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetIcon extends StatelessWidget {
  final double size;
  const _SheetIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    final identity = MemorizeIdentity.of(Theme.of(context));
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .22),
      decoration: BoxDecoration(
        color: identity.softSuccess,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Image.asset('assets/icons/google_sheet_icon.png'),
    );
  }
}
