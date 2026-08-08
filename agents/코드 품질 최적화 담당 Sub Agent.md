# 코드 품질 / 최적화 담당 Sub Agent Memory

session-id: 019e8b15-ceb5-76b2-b582-b0da7656b947

## Official Role Definition - 2026-06-04

Agent name:

- 코드 품질 / 최적화 담당 Sub Agent

Official role:

- Flutter 코드 구조, 유지보수성, 성능, 상태 관리, 오류 처리, 확장 가능성을 검토한다.
- UI, 비즈니스 로직, 데이터 모델, 서비스 계층 분리와 비동기 안정성을 점검한다.
- 테스트 가능성, 성능 위험, 회귀 위험을 점검한다.

Boundary:

- 시각 디자인 방향은 UI Agent에게 맡긴다.
- 사용자 흐름과 문구의 제품 판단은 UX Agent와 PM에게 맡긴다.
- SRS 알고리즘 규칙 자체는 SRS Agent에게 맡긴다.
- AI 제공자와 프롬프트 정책은 AI 학습 Agent에게 맡긴다.

## Role

You are the code quality and optimization sub agent for the vocabulary memorization app.

Your responsibility is code structure, maintainability, performance, state management, error handling, scalability, and development-cycle audit.

## Project Overview

The app is built with Flutter.

Main possible modules:

- home screen
- wordbook management
- quiz structure
- SRS scheduling
- notifications
- statistics
- multilingual / AI assistance

The code should be easy to maintain and extend.

## Shared Main Screen Research Table

| Area | Current Finding | Improvement Direction |
| --- | --- | --- |
| Duplicate home concepts | AppShellScreen is active, HomeScreen contains richer routine ideas but is unused. | Audit whether to merge useful logic or remove/archive unused screen. |
| State/data loading | Wordbook stats are loaded with futures and cached by stats revision. | Check loading, cache invalidation, and rebuild cost. |
| Progress logic | Home progress can be misleading. | Verify metric naming and calculation before UI changes. |
| Component duplication | Similar card/pill/action patterns appear in multiple files. | Suggest reusable widgets only where they reduce real duplication. |
| Performance | Home uses PageView/FutureBuilder, cards, shadows, and glassmorphic effects. | Check rendering cost and unnecessary rebuilds. |
| Safety | Multiple agents may edit the repo. | Never revert changes made by others. Work with existing modifications. |

## Assigned Tasks

1. Review code structure and find duplicate, fragile, or over-complex areas.
2. Check whether UI, business logic, data model, and service layers are separated clearly.
3. Improve naming, readability, and folder structure recommendations.
4. Find unnecessary rebuilds, heavy rendering, repeated calculations, or inefficient list rendering.
5. Check state management consistency.
6. At the end of each development cycle, audit the implementation result before PM asks for the next task.

## Expected Output

Return a code quality audit with:

- findings ordered by severity
- file/line references where possible
- optimization opportunities
- refactor recommendations
- risks before the next development cycle

## PM Dispatch - 2026-06-03

Assigned by:

- PM Sub Agent
- PM session-id: 019dba38-6085-7a22-9609-43d93a782102

Your session-id:

- 019e8b15-ceb5-76b2-b582-b0da7656b947

Role table received:

- You are the code quality and optimization Sub Agent for the Flutter vocabulary memorization app.
- Your role is to review code structure, maintainability, performance, state management, error handling, scalability, and regression risk.
- You must not focus on visual design unless it creates maintainability or performance risk.
- You are the mandatory audit receiver at the end of each development cycle.

Project goals to consider:

1. Flutter code must be maintainable and extensible.
2. UI, business logic, data model, and service layers should be separated where practical.
3. SRS scheduling and quiz scoring should be testable.
4. The app should remain stable with many words and review records.
5. Multilingual expansion should remain possible.

Current assigned work:

1. Audit current code structure with focus on `app_shell_screen.dart`, SRS/plan scope logic, quiz flow, flashcard flow, and AI learning setup.
2. Identify duplicate state calculations and fragile async/context handling.
3. Identify files or widgets that should be split only if doing so reduces real complexity.
4. Propose tests for SRS stage transitions, plan scoping, quiz result handling, and active wordbook restoration.
5. Prepare to audit implementation results after each PM development cycle.

Required response format:

1. 주요 코드 품질 문제
2. 위험도: 높음 / 중간 / 낮음
3. 추천 리팩터링
4. 개선된 구조 예시
5. 테스트 제안
6. 성능 개선 제안

Development-cycle audit rule:

At the end of each development cycle, PM will send the implementation summary to this Agent. This Agent must audit:

- changed files
- regression risks
- maintainability impact
- performance risk
- missing tests
- whether the next cycle can proceed

Memory rule:

- Store future code-quality findings, audit records, and PM assignments in this file.
- Do not edit other Agent memory files.

## Agent Report - 2026-06-03

### 1. 주요 코드 품질 문제

- Flashcard SRS 저장 경로가 중복 호출될 수 있다. `lib/screens/flashcard_screen.dart:102-128`에서 `dispose()`가 `_saveUpdatedSrsData()`를 기다리지 않고 호출하고, `lib/screens/flashcard_screen.dart:268-273` 세션 종료 및 `lib/screens/flashcard_screen.dart:385-391` PopScope에서도 같은 저장 함수를 호출한다. `_updatedWordsInSession`은 DB 저장 이후에야 clear되므로, 거의 동시에 호출되면 같은 단어의 SRS 레벨과 `nextReviewDate`가 중복 반영될 위험이 있다.
- Multiple choice 퀴즈는 답안마다 DB 저장과 provider refresh를 즉시 실행한다. `lib/screens/quiz_screen.dart:1539-1545`에서 `updateWordsSrsData`를 await하지 않아 저장 실패를 놓칠 수 있고, 여러 문제를 빠르게 풀면 DB 업데이트, `statsRevision`, `WordListNotifier.refreshWords()`가 문제 수만큼 반복된다.
- `app_shell_screen.dart`가 5,871라인으로 Shell, 홈/통계/복습/AI 탭, 단어장 통계, 학습 플랜 빌더, 카드 컴포넌트까지 모두 포함한다. 핵심 계산도 `lib/screens/app_shell_screen.dart:345-372`, 통계 future cache는 `lib/screens/app_shell_screen.dart:177-199`, 플랜 바텀시트는 `lib/screens/app_shell_screen.dart:3430-3573`에 섞여 있어 변경 영향 범위가 넓다.
- 플랜 범위와 SRS 일일 계획 계산이 여러 화면에 퍼져 있다. 기준 로직은 `lib/providers/wordbook_manager.dart:174-217`에 있지만, `lib/screens/app_shell_screen.dart:364-372`, `lib/screens/quiz_screen.dart:119-134`, `lib/screens/flashcard_screen.dart:72-87`, `lib/screens/srs_status_screen.dart:86-89`가 각각 다시 조합한다. planned count와 recommended count를 화면별로 다르게 쓰기 쉬운 구조다.
- `HomeScreen`은 현재 `lib/main.dart:187`에서 사용되지 않고 `AppShellScreen`이 진입점이지만, `lib/screens/home_screen.dart:24-43` 및 내부 통계 FutureBuilder 로직이 남아 있다. `AppShellScreen` 안에도 `_HomeDashboardTab`, `_DecksTab`, `_ReviewTab`, `_AiLearningTab`, `_StatsTab` 등 이전 계열 위젯이 남아 있고 일부 Bloom 위젯이 이를 상속만 한다(`lib/screens/app_shell_screen.dart:781`, `3347`, `3882`, `4052`, `4370`, `5187-5415`). 죽은 화면과 상속용 concrete widget이 유지보수 비용을 키운다.
- Flashcard 단어장 선택은 비동기 mounted guard가 한 번 부족하다. `lib/screens/flashcard_screen.dart:108-118`에서 `setActiveWordbook` 후 `mounted`를 확인하지만, 이어지는 `getAllWordsFrom` await 이후 다시 확인하지 않고 `setState`한다. 또한 `setActiveWordbook`이 이미 active words를 로드한 뒤 다시 전체 단어를 DB에서 읽어 중복 로딩한다.
- DB 로딩은 모든 단어 조회마다 isolate compute를 사용한다. `lib/services/database_service.dart:237-246`와 `lib/providers/word_list_provider.dart:19-23` 조합은 UI block을 줄이는 장점이 있으나, AppShell 단어장 상태 카드(`lib/screens/app_shell_screen.dart:177-199`, `2706-2885`)와 활성 단어장 로딩이 같은 DB를 반복 조회할 수 있다. token null 분기(`lib/services/database_service.dart:237-242`)도 null token을 background 함수에 넘길 수 있어 테스트/비표준 isolate 환경에서 취약하다.
- `QuizSessionProvider`와 `QuizResultScreen`은 현재 참조가 거의 없다(`lib/providers/quiz_session_provider.dart:17-119`, `lib/screens/quiz_result_screen.dart:6-53`). 실제 `quiz_screen.dart` 내부 상태 기반 구현과 분리되어 있어 오래된 흐름이 남은 것으로 보인다.
- 테스트는 기본 카운터 smoke test만 존재한다(`test/widget_test.dart:14-29`). SRS, 플랜 범위, 퀴즈 결과, 활성 단어장 복원 같은 핵심 로직을 보호하지 못한다.

### 2. 위험도: 높음 / 중간 / 낮음

- 높음: Flashcard SRS 중복 저장 가능성. 실제 학습 기록과 다음 복습일을 틀리게 만들 수 있어 우선 조치가 필요하다.
- 중간: Multiple choice per-answer 비동기 저장. 데이터 정합성보다는 성능, race, 실패 은닉 위험이 크다.
- 중간: AppShell 비대화와 오래된 위젯 공존. 다음 UI/기능 주기에서 회귀 위치를 찾기 어렵다.
- 중간: 플랜 scope 계산 중복. 새 단어 잠금/추천 수량이 화면별로 달라질 위험이 있다.
- 중간: DB 전체 로딩과 FutureBuilder 통계 비용. 단어장 수와 단어 수가 늘면 첫 화면 및 통계 카드 비용이 커진다.
- 낮음: orphan provider/result screen. 즉시 런타임 영향은 낮지만 설계 혼선을 만든다.

다음 주기 진행 가능 여부: 조건부 가능. 생산 변경 전에 Flashcard SRS 저장 idempotency와 플랜 scope 계산 단일화 방향을 먼저 잡는 것이 좋다.

### 3. 추천 리팩터링

- `WordbookManager` 또는 별도 `LearningPlanService`에 `LearningPlanSnapshot`을 추가해 scoped words, full plan, plan plan, locked count, planned new count, recommended new count를 한 번에 계산하게 한다.
- Flashcard와 Quiz의 SRS 업데이트는 세션 종료 시 batch 저장을 기본으로 하고, 저장 함수에는 `_isSavingSrs`, `_hasSavedSrs`, pending list snapshot clear를 넣어 idempotent하게 만든다.
- `app_shell_screen.dart`를 기능 단위로 분리한다: shell scaffold, home tab, review tab, stats tab, AI tab, deck status widgets, study plan builder.
- Bloom 위젯이 이전 concrete widget을 상속하는 구조는 field holder용 abstract/base data class 또는 composition으로 바꾼다. 사용하지 않는 old build 구현은 제거 후보로 표시한다.
- `WordbookRepository` 또는 manager 내부 cache를 두어 `getAllWordsFrom(dbFileName)` 결과를 `statsRevision`/wordbook revision 기준으로 재사용한다.
- provider 구독은 `context.watch` 전체 구독보다 `context.select`/`Selector`로 좁힌다. AppShell build 전체가 theme, auth, word list, wordbook manager 변경마다 많은 계산을 다시 수행한다.

### 4. 개선된 구조 예시

```dart
class LearningPlanSnapshot {
  final Wordbook? wordbook;
  final StudyPlan? studyPlan;
  final List<Word> allWords;
  final List<Word> scopedWords;
  final DailyLearningPlan scopedDailyPlan;
  final DailyLearningPlan fullDailyPlan;
  final int lockedNewWordCount;
  final int plannedNewWordCount;
  final int recommendedNewWordCount;
}

class LearningPlanService {
  LearningPlanSnapshot build({
    required Wordbook? wordbook,
    required StudyPlan? studyPlan,
    required List<Word> words,
    required DateTime baseDate,
  });
}
```

```dart
class SrsSessionCommitter {
  bool _saving = false;
  bool _saved = false;

  Future<void> commitOnce(List<Word> pendingUpdates) async {
    if (_saving || _saved || pendingUpdates.isEmpty) return;
    _saving = true;
    final snapshot = List<Word>.from(pendingUpdates);
    pendingUpdates.clear();
    try {
      await repository.updateSrsBatch(snapshot);
      _saved = true;
    } finally {
      _saving = false;
    }
  }
}
```

### 5. 테스트 제안

- `SrsService` unit test: new/due/learning/mature stage, overdue priority sort, flashcard good/again level transition, spellingQuiz reset/increment, `wasReviewedToday` 기준일 처리.
- `StudyPlan` 및 plan scope unit test: `unlockedNewLimit`, `currentChunk`, active/paused 상태, locked count, planned/recommended new count, review load별 감산 기준.
- Flashcard session test: swipe good/again pending update 생성, undo가 pending update 제거, `commitOnce`가 동시 호출되어도 DB batch 1회만 실행, newWords 모드가 recommended count를 지킴.
- Quiz flow test: multiple choice 결과를 세션 단위로 저장, spelling retry/skip/first try가 기대 SRS update source로 변환, PopScope/결과 화면 진입 시 저장 1회 보장.
- Active wordbook restore test: 저장된 id 우선 복원, id 미존재 시 dbFileName fallback, 삭제된 단어장일 때 첫 단어장 선택 또는 null 처리.
- Widget smoke test 교체: 현재 counter test 대신 AppInitializer가 로딩 후 AppShell을 표시하는 최소 테스트로 바꿔야 한다.

### 6. 성능 개선 제안

- 단어장 통계는 카드별 FutureBuilder가 아니라 manager/service에서 `Map<dbFileName, DeckStats>`를 batch prefetch하거나 lazy cache한다.
- 활성 단어장 단어 목록은 `WordListNotifier.words`를 우선 사용하고, 같은 dbFileName에 대한 즉시 재조회는 피한다.
- SRS 저장 후 전체 단어 refresh를 매 문제마다 하지 말고, session batch 저장 후 한 번만 refresh한다.
- `buildDailyPlan`과 `wordsAvailableForPlan`은 AppShell build 중 반복 호출하지 않고 snapshot을 memoize한다.
- 대형 단어장 검색/통계에는 전체 row 로딩 대신 SQL count/group query를 추가하는 방향을 검토한다.
- `DatabaseService.getAllWords`의 token null 분기는 direct DB read fallback으로 정리해 테스트 안정성을 높인다.
