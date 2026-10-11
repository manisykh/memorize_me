import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/word_model.dart';
import '../services/wordbook_xlsx_service.dart';
import '../themes/memorize_identity.dart';

Future<WordbookXlsxExportOptions?> showWordbookXlsxExportDialog(
  BuildContext context,
  List<Word> words,
) {
  final hasAdditional = words.any((word) => word.additionalMeanings.isNotEmpty);
  final hasSentence = words.any(
    (word) => word.exampleSentence?.trim().isNotEmpty ?? false,
  );
  final hasTranslation = words.any(
    (word) => word.exampleSentenceTranslation?.trim().isNotEmpty ?? false,
  );
  var includeAdditional = hasAdditional;
  var includeSentence = hasSentence;
  var includeTranslation = hasTranslation;

  return showDialog<WordbookXlsxExportOptions>(
    context: context,
    barrierColor: const Color(0x9909255A),
    builder:
        (dialogContext) => StatefulBuilder(
          builder: (context, refresh) {
            final theme = Theme.of(context);
            final identity = MemorizeIdentity.of(theme);
            return Dialog(
              backgroundColor: identity.surface,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: identity.softContext,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            CupertinoIcons.doc_text,
                            color: identity.primaryAction,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '엑셀로 내보내기',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: identity.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(CupertinoIcons.xmark, color: identity.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '단어와 대표 뜻은 항상 포함됩니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: identity.softContext,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: identity.primaryAction,
                            size: 23,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '기본 포함',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: identity.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '·  단어, 대표 뜻',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: identity.mutedInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasAdditional || hasSentence || hasTranslation) ...[
                      const SizedBox(height: 20),
                      Text(
                        '추가로 포함할 항목',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: identity.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: identity.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: identity.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            if (hasAdditional)
                              _ExportOptionRow(
                                icon: CupertinoIcons.doc_plaintext,
                                title: '추가 뜻',
                                subtitle: '여러 뜻이 있는 단어',
                                value: includeAdditional,
                                onChanged:
                                    (value) => refresh(
                                      () => includeAdditional = value,
                                    ),
                              ),
                            if (hasAdditional &&
                                (hasSentence || hasTranslation))
                              Divider(
                                height: 1,
                                indent: 56,
                                color: identity.border,
                              ),
                            if (hasSentence)
                              _ExportOptionRow(
                                icon: CupertinoIcons.chat_bubble,
                                title: '예문',
                                subtitle: '학습에 사용한 영어 문장',
                                value: includeSentence,
                                onChanged:
                                    (value) =>
                                        refresh(() => includeSentence = value),
                              ),
                            if (hasSentence && hasTranslation)
                              Divider(
                                height: 1,
                                indent: 56,
                                color: identity.border,
                              ),
                            if (hasTranslation)
                              _ExportOptionRow(
                                icon: CupertinoIcons.textformat_alt,
                                title: '예문 해석',
                                subtitle: '예문의 한국어 번역',
                                value: includeTranslation,
                                onChanged:
                                    (value) => refresh(
                                      () => includeTranslation = value,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed:
                                () => Navigator.pop(
                                  dialogContext,
                                  WordbookXlsxExportOptions(
                                    includeAdditionalMeanings:
                                        includeAdditional,
                                    includeExampleSentence: includeSentence,
                                    includeExampleTranslation:
                                        includeTranslation,
                                  ),
                                ),
                            icon: const Icon(CupertinoIcons.share, size: 19),
                            label: const Text('XLSX 공유'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
  );
}

class _ExportOptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ExportOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(icon, color: identity.mutedInk, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: identity.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (next) => onChanged(next ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
