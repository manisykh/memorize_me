# PM Sub Agent Memory

session-id: 019dba38-6085-7a22-9609-43d93a782102

## Role

You are the project manager sub agent for the vocabulary memorization app.

You own product flow, prioritization, work breakdown, development schedule, acceptance criteria, and final completion management.

Core product loop:

Home -> review -> flashcards -> quiz -> result -> next action check.

Your responsibility is to make unclear user requests actionable by deciding:

- button text
- screen state
- route behavior
- edge cases
- feature scope
- implementation priority
- work breakdown
- expected development outcome

## Project Overview

This app is a vocabulary memorization app.

Main features may include:

- wordbooks
- SRS review
- quizzes
- review history
- learning statistics
- notifications
- AI learning assistance

## Shared Main Screen Research Table

| Area | Current Finding | Improvement Direction | Owner |
| --- | --- | --- | --- |
| Home information hierarchy | Current main screen shows today's counts, a large start CTA, and wordbook status, but the user may not immediately understand what to do and why. | Turn the top of the home screen into a "today's prescription" card: review count, estimated time, priority reason, and next action. | UX 담당 Sub Agent, UI 담당 Sub Agent |
| Main CTA | The start card routes to review/new words/cards, but the label is always generic. | Make CTA copy dynamic: "오늘 복습 시작", "새 단어 5개 시작", "전체 카드 보기". | PM Sub Agent, UX 담당 Sub Agent |
| Progress indicator | Current progress calculation is review count divided by active learning counts, which can look like completion progress but may mean remaining review pressure. | Rename it clearly or replace it with a real daily completion metric. | SRS / 학습 알고리즘 담당 Sub Agent, UX 담당 Sub Agent |
| Bottom navigation | Six tabs are available: home, wordbooks, review, stats, AI learning, settings. This is broad for a mobile learning flow. | Consider reducing to home, wordbooks, learning, stats. Move settings to profile sheet and AI into home/learning actions if lower frequency. | UX 담당 Sub Agent, UI 담당 Sub Agent |
| Wordbook status | Wordbook status card is strong but large. It shows mastery, focus count, and stage distribution. | Keep it, but place it after the daily action. Add a clear "manage" or "switch" affordance. | UI 담당 Sub Agent |
| Routine flow | Unused HomeScreen already has a good 1-2-3 routine model. | Reuse the routine recommendation concept inside the active AppShell home. | PM Sub Agent, UX 담당 Sub Agent |
| Habit loop | No visible streak, weekly rhythm, or lightweight motivation on the home screen. | Add streak, weekly heatmap, or today's goal completion. Avoid heavy gamification. | UX 담당 Sub Agent, SRS / 학습 알고리즘 담당 Sub Agent |
| Social loop | No group, sharing, or mutual accountability loop. | Start small: study group, shared challenge, completion reaction, shared wordbook. | PM Sub Agent, UX 담당 Sub Agent |
| Context learning | Home does not surface a "word of the day" or recently missed word preview. | Add one compact daily word or missed word card with pronunciation/example/action. | UX 담당 Sub Agent, SRS / 학습 알고리즘 담당 Sub Agent |
| Code quality | There are duplicate home concepts: active AppShellScreen and unused HomeScreen. | Decide whether to merge useful HomeScreen pieces or remove/archive unused screen later. | 코드 품질 / 최적화 담당 Sub Agent |

## Assigned Work

1. UI 담당 Sub Agent
   - Audit visual hierarchy, spacing, typography, colors, component consistency.
   - Propose a modern but calm main-screen layout.
   - Identify which UI components should be reusable.

2. UX 담당 Sub Agent
   - Analyze the user flow from first launch to daily review.
   - Simplify the journey from "open app" to "start useful learning".
   - Propose onboarding, today's goal, streak, review count, and completion experience.

3. SRS / 학습 알고리즘 담당 Sub Agent
   - Audit SRS stages, daily plan logic, review priority, and how learning status should appear on home.
   - Recommend accurate metrics for daily progress and memory state.

4. 코드 품질 / 최적화 담당 Sub Agent
   - Audit code structure, duplication, state management, performance, loading states, and maintainability.
   - This agent receives the development result after each cycle for quality review before the next task is assigned.

## Development Cycle Rule

At the end of each development cycle:

1. PM Sub Agent collects the implementation result.
2. PM Sub Agent sends the result to 코드 품질 / 최적화 담당 Sub Agent.
3. 코드 품질 / 최적화 담당 Sub Agent audits code quality, optimization, risks, and regressions.
4. PM Sub Agent summarizes the audit.
5. PM Sub Agent asks the user for the next work instruction.

## Cycle Log

### Cycle 1: Main Screen Baseline Confirmation

Scope:

- Confirm the actual main/home screen that future work should target.
- Identify duplicate or legacy home/tab structures.
- Decide what should be preserved before any cleanup.
- Produce a PM final report before implementation.

Assigned:

- UI 담당 Sub Agent: visual impact and UI patterns to preserve.
- UX 담당 Sub Agent: user-flow impact and transition principles.
- SRS / 학습 알고리즘 담당 Sub Agent: learning-state display criteria and SRS dependencies.
- 코드 품질 / 최적화 담당 Sub Agent: actual entry screen, duplicate classes, and safe cleanup plan.

Completion definition:

- PM can declare one canonical main screen.
- PM can list preserve/migrate/archive candidates.
- PM can provide a safe next implementation plan.
- No production code is changed in this cycle unless explicitly requested later.

### Cycle 2: Today Prescription Card And Dynamic CTA

Scope:

- Make the active AppShell home explain what the user should do today.
- Merge the daily prescription message and primary action into the home daily panel.
- Keep progress copy tied to today's goal completion.
- Do not run `dart format lib\screens\app_shell_screen.dart`.
- Do not run `flutter analyze`; the user will verify.

Implementation summary:

- Added state-based prescription title and description in `_BloomHomeDashboardTabState`.
- Added state-based CTA labels for no wordbook, review, new words, learning check, and completed state.
- Moved primary CTA into `_TodayLearningPanel`.
- Removed the separate home-level `_ContinueLearningCard` call.
- Kept `_ContinueLearningCard` class because it is still used in the review tab.
- Routed no-wordbook CTA to `WordbookManagementScreen`.
- Renamed the progress label to "오늘 목표 완료율".
- Updated the no-wordbook empty state so the home hero and daily panel do not look like a completed learning state.

### Cycle 3: Sub Agent Operating Protocol And First Assignment

Date: 2026-06-03

PM session-id:

- 019dba38-6085-7a22-9609-43d93a782102

Sub Agent table received from the user:

| Agent | Session ID | Role summary |
| --- | --- | --- |
| PM Sub Agent | 019dba38-6085-7a22-9609-43d93a782102 | Product Flow Agent 역할을 겸하며 제품 방향성, 우선순위, 작업 분해, 개발 일정성, 전체 일관성을 관리한다. 홈 -> 복습 -> 플래시카드 -> 퀴즈 -> 결과 -> 다음 행동 흐름을 점검한다. |
| UI 담당 Sub Agent | 019e8b15-81bb-7de3-bfe0-850e8e503442 | 화면 구성, 시각적 계층, 색상, 타이포그래피, 간격, 컴포넌트 일관성을 개선한다. |
| UX 담당 Sub Agent | 019e8b15-a491-7172-a683-df9b2ea0ccc8 | 사용자 흐름, 학습 동기, 습관 형성, 복습 경험, 사용 편의성을 개선한다. |
| 코드 품질 / 최적화 담당 Sub Agent | 019e8b15-ceb5-76b2-b582-b0da7656b947 | 코드 구조, 유지보수성, 성능, 상태 관리, 오류 처리, 확장 가능성을 검토하고 개선한다. 개발주기 종료 후 감사 역할을 맡는다. |
| SRS / 학습 알고리즘 담당 Sub Agent | 019e8b15-fc81-7873-a701-351999195d4e | 복습 주기, 기억 단계, 퀴즈 결과 처리, 단어 난이도, 학습 효율을 설계하고 검토한다. |

Project goals to preserve:

1. 사용자가 매일 부담 없이 단어를 복습할 수 있는 앱을 만든다.
2. SRS, 퀴즈, 복습 기록, 학습 통계 기능을 통해 암기 효율을 높인다.
3. 화면은 단순하고 직관적이어야 한다.
4. 사용자는 앱을 열었을 때 바로 무엇을 해야 하는지 알 수 있어야 한다.
5. 기능은 처음부터 과하게 복잡하게 만들지 않고, MVP를 먼저 완성한 뒤 개선한다.
6. Flutter 코드 구조는 유지보수하기 쉽고 확장 가능해야 한다.
7. 한국어, 영어, 일본어 등 다국어 확장을 고려한다.

Operating rules:

- PM Sub Agent assigns work to the other Sub Agents.
- Each Sub Agent focuses only on its professional role.
- Each Sub Agent stores memory in its own file under `agents/`.
- UI Agent does not make business-logic decisions.
- UX Agent focuses on flow and user understanding, not visual polish details.
- SRS Agent owns learning-state definitions and scheduling rules.
- Code Quality Agent owns maintainability, performance, state safety, and regression risk.
- PM Agent consolidates findings and decides MVP priority.

Development cycle rule:

1. PM assigns a bounded cycle.
2. Relevant Sub Agents report findings in their required format.
3. PM consolidates findings into a product decision.
4. Implementation proceeds only after the user asks to implement.
5. At the end of each development cycle, PM sends the implementation result to Code Quality / Optimization Agent.
6. Code Quality / Optimization Agent audits the result.
7. PM summarizes the audit and asks the user to instruct the next work.

Current assignment:

- UI 담당 Sub Agent: current app UI improvement audit.
- UX 담당 Sub Agent: current app user-flow improvement audit.
- SRS / 학습 알고리즘 담당 Sub Agent: current SRS, plan, review-state audit.
- 코드 품질 / 최적화 담당 Sub Agent: current structure, performance, and risk audit.

Current cycle completion definition:

- Each Sub Agent has received its role table and assignment.
- Each Sub Agent memory file contains the assigned task.
- PM can produce a consolidated report only after individual Agent reports are available.

### Cycle 3 PM Consolidated Report

Date: 2026-06-03

Goal:

- Analyze the current app through UI, UX, SRS/learning algorithm, and code quality agents.
- Derive improvement points that make the app easier to understand, easier to use daily, and safer to maintain.
- Do not implement production code in this cycle.

Agent findings:

- UI Agent: The home direction is stronger than before, but some screens still do not share the same visual system. Highest UI risks are settings double frame/AppBar, AI quiz player style drift, long quiz text clipping, and keeping the primary home CTA visible above the fold.
- UX Agent: The user can still feel unsure about what to do next. The app should explain today's task as "what / why / how long" and reduce unclear terms such as review waiting, learning candidate, locked words, and new word routine.
- SRS Agent: Keep SRS explainable with four user-facing states: new word, learning, review needed, stable memory. When a plan is applied, the plan scope must act like the current learning unit; review, quiz, AI, and stats should use only opened plan words until the plan is complete.
- Code Quality Agent: There are structural risks in duplicated SRS/plan calculations and possible repeated SRS saving in flashcard sessions. `app_shell_screen.dart` is too large and mixes shell, tab UI, statistics, plan builder, and calculation logic.

Common conclusions:

- The app needs one clear "learning scope" concept. Active wordbook and active plan should drive home, review, quiz, AI, and stats consistently.
- The app should show fewer internal labels and more user-facing guidance. For example, "today's required learning", "review needed", and "stable memory" are clearer than implementation-like states.
- Plan logic and SRS logic must be centralized before adding more UI around them, otherwise each tab may keep showing different numbers.
- The first MVP priority is not adding features; it is making the existing study flow feel obvious and trustworthy.

PM priority:

- Required: Define and centralize active learning scope; align home/review/quiz/stats labels and counts to that scope.
- Required: Prevent duplicated SRS commit in flashcard and quiz flows.
- Required: Fix UI clarity issues that make the app feel broken: clipping, double AppBar/frame, long option text, and result back-navigation behavior.
- Recommended: Create reusable UI components for status chips, metric tiles, primary CTA, quiz option tile, and result summary.
- Recommended: Add lightweight test targets for SRS transition, plan scope, active wordbook restore, and quiz result saving.
- Optional: More gamification, social, or ranking features. These should wait until the core learning flow is stable.

Next execution proposal:

1. Product copy and state cleanup: replace confusing labels with user-facing terms.
2. Learning scope service: make active wordbook/plan decide all counts and candidate lists.
3. SRS commit safety: make flashcard and quiz sessions save results once.
4. UI P1 fixes: settings frame, AI quiz player style, quiz text clipping, primary CTA hierarchy.
5. Code quality audit: send the implementation result back to the Code Quality Agent before the next cycle.

### Official Sub Agent Role Table v3

Date: 2026-06-04

Status:

- This table is the current official Sub Agent definition.
- It supersedes earlier role tables and PM dispatch role summaries.
- File names may be normalized for Windows path safety, but each official agent name below should be used in reports.

| Agent name | Role |
| --- | --- |
| PM | Product Flow Agent 역할도 하면서 홈 -> 복습 -> 플래시카드 -> 퀴즈 -> 결과 -> 다음 행동 흐름을 점검한다. 사용자가 지금 무엇을 해야 하는지 명확한지 판단하고, 버튼 문구, 상태명, 루틴 설명, 플랜 설명, 기능 간 상위/하위 관계를 정리한다. 제품 방향성, 기능 우선순위, 작업 분해, 개발 일정성, 전체 일관성을 관리한다. |
| UI 담당 Sub Agent | 화면 구성, 시각적 계층, 색상, 타이포그래피, 간격, 컴포넌트 일관성을 개선한다. 중요한 버튼과 학습 상태가 잘 보이도록 하고, 과도하게 복잡한 디자인을 피하며, 재사용 가능한 UI 컴포넌트를 제안한다. |
| UX 담당 Sub Agent | 사용자 흐름, 학습 동기, 습관 형성, 복습 경험, 사용 편의성을 개선한다. 첫 실행부터 일일 복습까지의 흐름을 분석하고, 불필요한 단계를 줄이며, 사용자가 항상 다음 행동을 이해할 수 있도록 한다. |
| 코드 품질 / 최적화 담당 Sub Agent | Flutter 코드 구조, 유지보수성, 성능, 상태 관리, 오류 처리, 확장 가능성을 검토한다. UI, 비즈니스 로직, 데이터 모델, 서비스 계층 분리와 비동기 안정성, 테스트 가능성, 성능 위험을 점검한다. |
| SRS / 학습 알고리즘 담당 Sub Agent | 복습 주기, 기억 단계, 퀴즈 결과 처리, 단어 난이도, 학습 효율을 설계하고 검토한다. 단순하고 설명 가능한 SRS 단계와 답변별 상태 변화를 정의한다. |
| AI 학습 담당 Sub Agent | AI 예문 생성, AI 문제 생성, AI 문법 점검, AI 모델 설정, API 키 관리, 제공자 fallback, 응답 품질, 비용/한도/오류 처리를 검토한다. AI 기능이 활성 단어장/활성 플랜과 일치하고, 학습 흐름을 복잡하게 만들지 않도록 관리한다. |

Role distribution result:

- PM owns product flow, scope control, prioritization, and final reporting.
- UI 담당 Sub Agent owns visual structure and component consistency.
- UX 담당 Sub Agent owns user flow, habit formation, and comprehension.
- 코드 품질 / 최적화 담당 Sub Agent owns maintainability, performance, state safety, and testability.
- SRS / 학습 알고리즘 담당 Sub Agent owns learning stages, review intervals, quiz-result interpretation, and memory logic.
- AI 학습 담당 Sub Agent owns AI learning usefulness, provider setup, fallback behavior, prompt/response quality, and AI error handling.

### Sub Agent Table v2

Date: 2026-06-04

Purpose:

- Add an AI learning specialist Sub Agent to the existing app-improvement agent structure.
- Keep AI feature decisions separate from UI, UX, SRS, and code-quality decisions.

| Agent name | Role |
| --- | --- |
| PM Sub Agent | Product Flow Agent 역할도 하면서 홈 -> 복습 -> 플래시카드 -> 퀴즈 -> 결과 -> 다음 행동 흐름을 점검한다. 사용자가 지금 무엇을 해야 하는지 명확한지 판단하고, 버튼 문구, 상태명, 루틴 설명, 플랜 설명, 기능 간 상위/하위 관계를 정리한다. 제품 방향성, 기능 우선순위, 작업 분해, 개발 일정성, 전체 일관성을 관리한다. |
| UI 담당 Sub Agent | 화면 구성, 시각적 계층, 색상, 타이포그래피, 간격, 컴포넌트 일관성을 개선한다. 중요한 버튼과 학습 상태가 잘 보이도록 하고, 과도하게 복잡한 디자인을 피하며, 재사용 가능한 UI 컴포넌트를 제안한다. |
| UX 담당 Sub Agent | 사용자 흐름, 학습 동기, 습관 형성, 복습 경험, 사용 편의성을 개선한다. 첫 실행부터 일일 복습까지의 흐름을 분석하고, 불필요한 단계를 줄이며, 사용자가 항상 다음 행동을 이해할 수 있도록 한다. |
| 코드 품질 / 최적화 담당 Sub Agent | Flutter 코드 구조, 유지보수성, 성능, 상태 관리, 오류 처리, 확장 가능성을 검토한다. UI, 비즈니스 로직, 데이터 모델, 서비스 계층 분리와 비동기 안정성, 테스트 가능성, 성능 위험을 점검한다. |
| SRS / 학습 알고리즘 담당 Sub Agent | 복습 주기, 기억 단계, 퀴즈 결과 처리, 단어 난이도, 학습 효율을 설계하고 검토한다. 단순하고 설명 가능한 SRS 단계와 답변별 상태 변화를 정의한다. |
| AI 학습 담당 Sub Agent | AI 예문 생성, AI 문제 생성, AI 문법 점검, AI 모델 설정, API 키 관리, 제공자 fallback, 응답 품질, 비용/한도/오류 처리를 검토한다. AI 기능이 활성 단어장/활성 플랜과 일치하고, 학습 흐름을 복잡하게 만들지 않도록 관리한다. |

AI Agent boundaries:

- AI Agent owns AI feature behavior, prompt quality, provider/model setup, fallback, quota/error handling, and generated-content usefulness.
- AI Agent does not own visual layout; UI Agent owns that.
- AI Agent does not own learning-stage rules; SRS Agent owns that.
- AI Agent does not own implementation architecture; Code Quality Agent owns that.
- PM Agent resolves cross-agent conflicts and decides MVP priority.
