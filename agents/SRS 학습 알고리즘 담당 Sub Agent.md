# SRS 학습 알고리즘 담당 Sub Agent Memory

session-id: 019e8b15-fc81-7873-a701-351999195d4e

## Official Role Definition - 2026-06-04

Agent name:

- SRS / 학습 알고리즘 담당 Sub Agent

Official role:

- 복습 주기, 기억 단계, 퀴즈 결과 처리, 단어 난이도, 학습 효율을 설계하고 검토한다.
- 단순하고 설명 가능한 SRS 단계를 정의한다.
- 사용자 답변별 상태 변화를 정의한다.

Boundary:

- 화면 배치와 시각 디자인은 UI Agent에게 맡긴다.
- 사용 흐름과 문구의 이해 가능성은 UX Agent에게 맡긴다.
- 구현 구조, 성능, 테스트 설계는 코드 품질 Agent와 협의한다.
- AI 생성 문제의 품질 기준은 AI 학습 Agent와 협의한다.

## Role

You are the SRS and learning algorithm sub agent for the vocabulary memorization app.

Your responsibility is review cycle, memory stage, quiz result handling, difficulty, learning efficiency, and how learning state should be shown to the user.

## Project Overview

The app helps users memorize vocabulary effectively.

Users should review words at appropriate times.

The SRS system should be understandable enough to increase user trust and motivation.

## Shared Main Screen Research Table

| Area | Current Finding | Improvement Direction |
| --- | --- | --- |
| SRS stages | Current service separates new word, due, learning, and mature. | Confirm whether thresholds and labels match the intended learning model. |
| Review priority | Review priority uses overdue days, incorrect count, and SRS level. | Check if this prioritization is appropriate and explainable. |
| Daily progress | Current home progress is not a true completion rate. | Propose a correct daily progress metric. |
| New word batch | Suggested new word batch is capped at 5. | Check whether it should adapt to user load or streak. |
| User-facing status | Users need to understand why a word is due. | Propose labels like "오늘 복습일", "3일 밀림", "다음 복습 6/5". |
| Long-forgotten words | Old overdue words may need special handling. | Propose recovery mode or priority grouping. |

## Assigned Tasks

1. Design simple and clear SRS stages.
2. Define how word state changes after correct, wrong, good, hard, or easy responses.
3. Design review priority logic.
4. Define how old words, skipped words, overdue words, and long-unreviewed words should be handled.
5. Propose how to show review state to users on the home screen.

## Expected Output

Return an SRS audit with:

- current algorithm summary
- risks in current stage/progress logic
- recommended daily plan model
- recommended home metrics
- acceptance criteria for implementation

## PM Dispatch - 2026-06-03

Assigned by:

- PM Sub Agent
- PM session-id: 019dba38-6085-7a22-9609-43d93a782102

Your session-id:

- 019e8b15-fc81-7873-a701-351999195d4e

Role table received:

- You are the SRS and learning algorithm Sub Agent for the vocabulary memorization app.
- Your role is to design and review review intervals, memory stages, quiz result handling, word difficulty, and learning efficiency.
- Algorithms must remain simple, explainable, and easy to test.
- Do not make UI styling decisions, but define how learning state should be represented to users.

Project goals to consider:

1. SRS, quiz, review record, and learning statistics should improve memorization efficiency.
2. The user should understand why a word appears today.
3. A plan-applied wordbook should be treated as a strict current learning scope.
4. New words, learning words, due reviews, and stable memory must be clearly separated.

Current assigned work:

1. Audit the current SRS stage definitions: 새 단어, 학습 중, 복습 필요, 안정 기억.
2. Check whether plan scope correctly limits new words, review, quiz, AI generation, and statistics.
3. Define how `몰라요`, `알아요`, quiz wrong answer, quiz correct answer, skip, and retry should affect SRS state.
4. Recommend a daily progress metric that users can understand.
5. Recommend how old overdue words and long-unreviewed words should be prioritized.

Required response format:

1. SRS 규칙 제안
2. 복습 간격 표
3. 사용자 답변별 처리 방식
4. 예외 상황
5. 필요한 데이터 모델
6. 테스트 케이스

Memory rule:

- Store future SRS findings and PM assignments in this file.
- Do not edit other Agent memory files.

## Agent Report - 2026-06-03

### 1. SRS 규칙 제안

Current audit summary:

- Current stage source is `SrsService`: `newWord`, `due`, `learning`, `mature`.
- Current intervals are `[0, 1, 3, 7, 15, 30, 60, 120]` days by `srsLevel`.
- Current new word definition: `srsLevel == 0`, no `nextReviewDate`, and `correctStreak == 0`.
- Current due definition: `nextReviewDate <= today`. This takes priority over every other stage, so a mature word becomes due when its review date arrives.
- Current mature definition: `srsLevel >= 5` and not due.
- Current review priority is `overdueDays * 100 + incorrectCount * 10 - srsLevel`, so long-overdue words dominate, then frequently missed words, then lower-level words.
- Current active app entry is `AppShellScreen`, which builds the daily plan from `wordsAvailableForPlan(...)`. Flashcard, quiz, AI quiz/sentence setup, SRS status, wordbook stats, and shell stats mostly respect the active plan scope. The older `home_screen.dart` builds from all active words and appears unused by `main.dart`, but it can confuse future maintenance.

Recommended rules:

- Keep the four user-facing stages simple: 새 단어, 학습 중, 복습 필요, 안정 기억.
- Treat a plan-applied wordbook as the strict current learning scope: daily plan, new words, review, quiz, AI generation, and stats should use only opened plan words.
- Use `recommendedNewWordSessionCount`, not raw `newWords.length`, for today's new-word target when review load is high.
- Define "오늘 목표 완료율" as a true daily task metric: completed planned tasks today / (completed planned tasks today + remaining due reviews + remaining new-word target). Current `lastReviewedAt`-based logic is close, but it is a proxy until review history or daily plan snapshots exist.
- Keep review-first priority: due reviews first, then new words, then optional quiz/learning check.
- Add an explicit old-overdue policy: 1-6 days overdue = normal due queue, 7-20 days = recovery queue before new words, 21+ days = long-forgotten recovery with level reset or capped intensive review.
- Do not let retry success erase the original failure. Retry success should be weaker than first-try success.
- Consider preventing more than one SRS level increase per word per day unless the action is explicitly a recovery step.

### 2. 복습 간격 표

| Level | Stage when not due | Interval after success | Meaning |
| --- | --- | --- | --- |
| 0 | 새 단어 or 복습 필요 | 0 days | first exposure or relearning today |
| 1 | 학습 중 | 1 day | first short reinforcement |
| 2 | 학습 중 | 3 days | early memory check |
| 3 | 학습 중 | 7 days | weekly reinforcement |
| 4 | 학습 중 | 15 days | medium-term memory |
| 5 | 안정 기억 | 30 days | stable memory starts |
| 6 | 안정 기억 | 60 days | long-term memory |
| 7+ | 안정 기억 | 120 days cap | maintenance review |

Recommended failure intervals:

- `몰라요` or clear wrong answer: schedule today again, reduce one level, reset streak.
- Spelling skip or answer reveal: schedule today again, reset to level 0.
- Retry success: schedule short interval, preferably 1 day, without treating it as a full level-up.
- Very old overdue words: keep visible before new words, but cap the daily recovery batch so the user is not buried by backlog.

### 3. 사용자 답변별 처리 방식

| User action | Current behavior | Recommended behavior |
| --- | --- | --- |
| `알아요` on flashcard | `srsLevel + 1`, `correctStreak + 1`, next date by new level | Keep. Count as success only once per word per day if possible. |
| `몰라요` on flashcard | `srsLevel - 1` down to 0, streak reset, `incorrectCount + 1`, next review today | Keep. It should remain in today's recovery queue before new words. |
| Multiple-choice correct | Treated as `good`, SRS advances immediately | Acceptable, but first-try correctness should be recorded in history. |
| Multiple-choice wrong | Treated as `again`, level decreases and `incorrectCount` increases | Keep as a mild failure. Wrong choice should remain recorded even if retried later. |
| Spelling first-try correct | Saved later as `good`, SRS advances | Keep. This is stronger evidence than multiple choice. |
| Spelling wrong then retry success | Currently saved as `good`; original wrong attempt is not penalized | Change rule: record the miss, then mark retry success as `hard` or recovery success. No full level-up. |
| Spelling answer reveal / skip | Saved as `spellingQuiz`, resets level to 0 and increments `incorrectCount` | Keep as strong failure. Add explicit `skip` result in data for explainability. |
| Retry weak words | Reuses weak words in a new session | Keep, but repeated same-day retries should not inflate SRS level. |
| AI quiz answer | AI quiz generation uses scoped words, but quiz result is not connected to SRS | Either document as practice-only or add word-linked result logging before it affects SRS. |

### 4. 예외 상황

- Active plan scope currently locks by ordered word position. If a plan is created after some words already have SRS history, due or learning words outside the opened range can be hidden. This must be accepted as "strict current scope" or changed to "locked new words only"; the product copy and tests should match one rule.
- `nextReviewDate == null` with `srsLevel > 0` becomes learning or mature but has no real next review date. Add a repair rule: missing/invalid schedule should be treated as due or rescheduled.
- `incorrectCount` is cumulative and never decays. It is good for weak-word priority, but old mistakes can permanently bias priority unless a separate `lapseCount` or decayed difficulty score is added.
- Current daily progress is based on `lastReviewedAt`, so voluntary review of non-target words can inflate completion. A daily plan snapshot would make this exact.
- Current SRS update uses `DateTime.now()` directly. Unit tests and timezone correctness would be easier with an injectable clock or base date.
- Streak records any SRS batch update, including failed-only sessions. That is acceptable if "study activity" means showing up, but it should not be confused with successful completion.
- Long-overdue words should not unlock unlimited new words. If review load reaches the heavy-review threshold, new words should be paused as the manager already does.

### 5. 필요한 데이터 모델

Current fields are enough for basic SRS:

- `srsLevel`
- `nextReviewDate`
- `lastReviewedAt`
- `incorrectCount`
- `correctStreak`

Recommended additions for accurate progress and explainability:

- `ReviewLog`: `id`, `wordbookDbFileName`, `wordId`, `planId`, `sessionId`, `source`, `result`, `wasDueAtStart`, `attemptNumber`, `reviewedAt`, `previousLevel`, `newLevel`, `previousNextReviewDate`, `newNextReviewDate`.
- `DailyPlanSnapshot`: `date`, `wordbookDbFileName`, `planId`, `dueWordIdsAtStart`, `newWordIdsTarget`, `completedWordIds`, `remainingWordIds`.
- `SrsOutcome` enum: `again`, `hard`, `good`, `easy`, `skip`, `retrySuccess`.
- Optional difficulty fields: `lapseCount`, `lastIncorrectAt`, `lastOutcome`, `consecutiveDaysReviewed`.

### 6. 테스트 케이스

- Stage classification: new word, due word, scheduled learning word, mature word, and mature-but-due word.
- Interval mapping: levels 0-7+ map to 0, 1, 3, 7, 15, 30, 60, 120 days.
- Flashcard `알아요`: level and streak increase, next review moves forward, `incorrectCount` unchanged.
- Flashcard `몰라요`: level decreases, streak resets, `incorrectCount` increases, next review is today.
- Multiple-choice correct and wrong: correct advances; wrong decreases mildly and remains recorded.
- Spelling first-try correct, retry success, answer reveal, and skip: retry success must not equal first-try success in future rules.
- Plan scoping: AppShell daily plan, flashcard sessions, review quiz, general quiz, AI quiz setup, AI sentence generation, SRS status, and wordbook stats use only opened plan words.
- Plan edge case: create a plan after words already have SRS dates; verify the chosen strict-scope behavior for locked due words.
- Daily progress: reviewing a due word to success increases completion; marking `again` leaves it in remaining work; learning a new word counts as completed; voluntary mature review should not inflate planned completion once snapshots exist.
- Review priority: overdue 10 days outranks overdue 1 day; same overdue days sorts higher `incorrectCount`; same miss count sorts lower `srsLevel` first.
- Long-overdue handling: 7+ day and 21+ day overdue words are grouped or prioritized before new words.
- Invalid dates: malformed `nextReviewDate` and missing review date on non-new words are repaired or treated as due.
- Same-day repeated success: a word should not gain multiple levels from repeated retries unless explicitly allowed.

## PM Dispatch - 2026-06-04

Requested SRS/learning algorithm review for five improvement items:

1. Flashcard session should show an empty/no-card effect after the last word.
2. Review tab order should place multiple-choice quiz before full spelling quiz.
3. AI learning tab order should place AI example sentence generation before AI quiz generation, and sentence-generation copy should mention the selected wordbook.
4. Built-in default wordbooks should be split into beginner/intermediate/advanced sets, with clear quantity, difficulty, learning order, and initial SRS state.
5. Completion flow should return home-launched sessions to Home, and review-tab-launched sessions to the parent review item.

SRS focus for this dispatch:

- Built-in words should start as true new words: `srsLevel = 0`, `nextReviewDate = null`, `lastReviewedAt = null`, `incorrectCount = 0`, `correctStreak = 0`.
- Recommended built-in quantity is progressive and modest enough for SRS trust: beginner 300, intermediate 500, advanced 700 as separate wordbooks.
- Recommended default daily new target: beginner 10-15, intermediate 15-20, advanced 20-25, with review-load throttling preserved.
- Built-in word order must be stable and intentional, easiest/high-frequency first, because active plans unlock by DB insertion order.
