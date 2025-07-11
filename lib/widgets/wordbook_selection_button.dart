// lib/widgets/wordbook_selection_button.dart (신규 파일)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import 'glassmorphic_card.dart';
import 'wordbook_selection_dialog.dart';

class WordbookSelectionButton extends StatelessWidget {
  final Wordbook? selectedWordbook;
  final Function(Wordbook) onWordbookSelected;
  final int wordCount;

  const WordbookSelectionButton({
    super.key,
    required this.selectedWordbook,
    required this.onWordbookSelected,
    required this.wordCount,
  });

  @override
  Widget build(BuildContext context) {
    return GlassmorphicCard(
      onTap: () async {
        final result = await showWordbookSelectionDialog(context);
        if (result != null) {
          onWordbookSelected(result);
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('학습할 단어장', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  selectedWordbook?.name ?? '단어장을 선택해주세요',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (selectedWordbook != null)
                  Text('$wordCount 개의 단어', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
