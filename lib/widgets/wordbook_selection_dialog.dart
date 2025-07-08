import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import 'glassmorphic_card.dart';

/// 앱 전체에서 단어장을 선택하는 UI를 모달 시트 형태로 보여주는 함수입니다.
///
/// 사용자가 단어장을 선택하면 해당 [Wordbook] 객체를 반환하고,
/// 선택하지 않고 닫으면 `null`을 반환합니다.
Future<Wordbook?> showWordbookSelectionDialog(BuildContext context) async {
  return await showModalBottomSheet<Wordbook>(
    context: context,
    backgroundColor: Colors.transparent, // 배경을 투명하게 하여 Glassmorphic 효과가 보이도록 함
    builder: (ctx) {
      // Provider를 통해 단어장 목록과 현재 활성화된 단어장 정보를 가져옵니다.
      final manager = ctx.watch<WordbookManager>();
      final wordbooks = manager.wordbooks;
      final activeWordbookId = manager.activeWordbook?.id;

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: GlassmorphicCard(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 내용물의 크기만큼만 차지하도록 설정
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 다이얼로그 제목
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('단어장 선택', style: Theme.of(ctx).textTheme.titleLarge),
              ),
              // 단어장이 없을 경우 안내 메시지 표시
              if (wordbooks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('생성된 단어장이 없습니다.')),
                )
              else
                // 단어장이 있을 경우, 스크롤 가능한 리스트로 보여줌
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true, // 내용물에 맞게 높이를 조절
                    itemCount: wordbooks.length,
                    itemBuilder: (_, index) {
                      final wordbook = wordbooks[index];
                      return RadioListTile<int>(
                        title: Text(wordbook.name, style: Theme.of(ctx).textTheme.bodyLarge),
                        value: wordbook.id!,
                        groupValue: activeWordbookId, // 현재 활성화된 단어장에 체크 표시
                        onChanged: (value) {
                          // 라디오 버튼을 탭하면 선택된 단어장 정보를 반환하며 다이얼로그를 닫음
                          Navigator.of(ctx).pop(wordbook);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
