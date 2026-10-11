import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_plan_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../themes/memorize_identity.dart';

/// 앱 전체에서 현재 학습 단어장을 선택하는 공통 바텀시트입니다.
///
/// 행을 누르면 별도의 확인 단계 없이 선택한 [Wordbook]을 반환합니다.
Future<Wordbook?> showWordbookSelectionDialog(BuildContext context) {
  return showModalBottomSheet<Wordbook>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9909255A),
    builder: (sheetContext) {
      final manager = sheetContext.watch<WordbookManager>();
      final identity = MemorizeIdentity.of(Theme.of(sheetContext));
      final wordbooks = manager.wordbooks;

      return SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: identity.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: _SheetHeader(
                  count: wordbooks.length,
                  identity: identity,
                  onClose: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '학습할 단어장을 선택하세요.',
                    style: Theme.of(
                      sheetContext,
                    ).textTheme.bodyMedium?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (wordbooks.isEmpty)
                Flexible(child: _EmptyWordbookState(identity: identity))
              else
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: identity.surface,
                        borderRadius: BorderRadius.circular(
                          MemorizeIdentity.cardRadius,
                        ),
                        border: Border.all(color: identity.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          MemorizeIdentity.cardRadius,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: wordbooks.length,
                          separatorBuilder:
                              (_, __) =>
                                  Divider(height: 1, color: identity.border),
                          itemBuilder: (context, index) {
                            final wordbook = wordbooks[index];
                            return _WordbookSelectionRow(
                              wordbook: wordbook,
                              selected: _sameWordbook(
                                wordbook,
                                manager.activeWordbook,
                              ),
                              identity: identity,
                              manager: manager,
                              onTap:
                                  () =>
                                      Navigator.of(sheetContext).pop(wordbook),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

bool _sameWordbook(Wordbook wordbook, Wordbook? activeWordbook) {
  if (activeWordbook == null) return false;
  if (wordbook.id != null && activeWordbook.id != null) {
    return wordbook.id == activeWordbook.id;
  }
  return wordbook.dbFileName == activeWordbook.dbFileName;
}

class _SheetHeader extends StatelessWidget {
  final int count;
  final MemorizeIdentity identity;
  final VoidCallback onClose;

  const _SheetHeader({
    required this.count,
    required this.identity,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '단어장 선택',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count개',
          style: theme.textTheme.titleMedium?.copyWith(
            color: identity.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '닫기',
          onPressed: onClose,
          icon: Icon(CupertinoIcons.xmark, color: identity.ink, size: 22),
        ),
      ],
    );
  }
}

class _WordbookSelectionRow extends StatelessWidget {
  final Wordbook wordbook;
  final bool selected;
  final MemorizeIdentity identity;
  final WordbookManager manager;
  final VoidCallback onTap;

  const _WordbookSelectionRow({
    required this.wordbook,
    required this.selected,
    required this.identity,
    required this.manager,
    required this.onTap,
  });

  String _metadata(int wordCount) {
    final plan = manager.planFor(wordbook);
    if (plan == null || plan.status != StudyPlanStatus.active) {
      return '전체 $wordCount개';
    }
    if (plan.mode == StudyPlanMode.free) {
      return '전체 $wordCount개 · 현재 묶음 ${plan.currentChunk()}/${plan.chunkCount}';
    }
    return '전체 $wordCount개 · ${plan.progressLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? identity.softContext : identity.surface,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 92),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.book,
                  color: selected ? identity.primaryAction : identity.mutedInk,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              wordbook.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: identity.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: identity.primaryAction.withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '현재 학습',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: identity.primaryAction,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<int>(
                        future: manager
                            .getAllWordsFrom(wordbook)
                            .then((words) => words.length),
                        builder: (context, snapshot) {
                          final text =
                              snapshot.hasData
                                  ? _metadata(snapshot.data!)
                                  : '단어 수 확인 중';
                          return Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: identity.mutedInk,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.circle,
                  color: selected ? identity.primaryAction : identity.border,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyWordbookState extends StatelessWidget {
  final MemorizeIdentity identity;

  const _EmptyWordbookState({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.book, size: 40, color: identity.mutedInk),
            const SizedBox(height: 12),
            Text(
              '생성된 단어장이 없습니다.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
