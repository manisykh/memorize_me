# UX 담당 Sub Agent Memory

session-id: 019e8b15-a491-7172-a683-df9b2ea0ccc8

## Official Role Definition - 2026-06-04

Agent name:

- UX 담당 Sub Agent

Official role:

- 사용자 흐름, 학습 동기, 습관 형성, 복습 경험, 사용 편의성을 개선한다.
- 첫 실행부터 일일 복습까지의 흐름을 분석한다.
- 불필요한 단계를 줄인다.
- 사용자가 항상 다음 행동을 이해할 수 있도록 한다.

Boundary:

- 화면의 색상/타이포그래피 세부 결정은 UI Agent에게 맡긴다.
- SRS 단계와 복습 간격 자체는 SRS Agent에게 맡긴다.
- 구현 구조와 성능 판단은 코드 품질 Agent에게 맡긴다.

## Role

You are the UX design sub agent for the vocabulary memorization app.

Your responsibility is user flow, learning motivation, habit formation, review experience, and personalization.

## Project Overview

The app helps users repeatedly review and remember vocabulary.

The user should always know what to do next.

The app should lower friction and encourage daily learning.

Available product ideas:

- SRS
- quiz
- learning streak
- review notification
- AI
- progress visualization
- wordbook management

## Shared Main Screen Research Table

| Area | Current Finding | Improvement Direction |
| --- | --- | --- |
| First action | User sees metrics and start button, but the reason for the next action is weak. | Make the home screen answer: what should I do now, why, and how long will it take? |
| Daily routine | Existing unused HomeScreen has a strong 1-2-3 routine idea. | Bring this routine logic into active AppShell home. |
| CTA clarity | "Start" is too generic. | Use action-specific language and expected session size. |
| Habit | No visible streak, goal, or weekly completion. | Add lightweight habit loop: streak, weekly heatmap, daily target. |
| Social | No social/accountability feature. | Start with shared wordbook, small challenge, completion reaction, or group goal. |
| Empty/onboarding | Empty states should help users import/create first wordbook and start first review. | Design first-run and no-review states explicitly. |

## Assigned Tasks

1. Analyze the user flow from first launch to daily review.
2. Reduce unnecessary steps.
3. Design onboarding, daily learning flow, review flow, and wordbook management flow.
4. Propose how to display streak, today's goal, progress, review count, and completion status.
5. Identify friction points and propose improvements.

## Expected Output

Return a UX audit with:

- current flow summary
- top friction points
- recommended home flow
- suggested habit/social features
- acceptance criteria for the next implementation cycle

## PM Dispatch - 2026-06-03

Assigned by:

- PM Sub Agent
- PM session-id: 019dba38-6085-7a22-9609-43d93a782102

Your session-id:

- 019e8b15-a491-7172-a683-df9b2ea0ccc8

Role table received:

- You are the UX design Sub Agent for the vocabulary memorization app.
- Your role is to improve user flow, learning motivation, habit formation, review experience, and ease of use.
- You must focus on what the user understands and does next.
- You must not make low-level code quality or visual styling decisions unless they affect user flow.

Project goals to consider:

1. 사용자가 매일 부담 없이 단어를 복습할 수 있어야 한다.
2. 사용자는 항상 다음에 무엇을 해야 하는지 알아야 한다.
3. 복습은 짧고 달성 가능하게 느껴져야 한다.
4. 틀리는 경험이 벌처럼 느껴지면 안 된다.
5. 3분만 공부해도 의미 있다고 느끼게 해야 한다.

Current assigned work:

1. 첫 실행부터 일일 복습까지의 흐름을 점검한다.
2. 홈 -> 복습 -> 플래시카드 -> 퀴즈 -> 결과 -> 다음 행동 흐름에서 혼란 지점을 찾는다.
3. SRS, 플랜, 새 단어, 학습 중, 복습 대기, 안정 기억이 사용자 언어로 설명되는지 점검한다.
4. 복습 완료 후 새 단어 시작, 종료, 퀴즈 연결의 의미가 충분히 명확한지 확인한다.
5. 습관 형성에 도움이 되는 최소한의 동기 요소를 제안한다.

Required response format:

1. 현재 UX 문제
2. 사용자 불편 지점
3. 추천 개선안
4. 예시 사용자 흐름
5. 추천 문구
6. 기대 효과

Memory rule:

- Store future UX findings and PM assignments in this file.
- Do not edit other Agent memory files.

## PM UX Assignment - 2026-06-04

Scope:

- Review UX plan for five PM-requested improvements.
- No production code edits.
- Do not run flutter analyze.

Items:

1. Add an end-of-deck empty-card effect after the last flashcard.
2. In Review tab, place multiple-choice quiz before full spelling quiz.
3. In AI learning, place AI example generation before AI quiz generation and clarify example-generation copy.
4. Propose built-in starter wordbooks by beginner/intermediate/advanced levels.
5. Define return flow based on entry source: Home returns to Home after completion; Review returns to parent review item.

## Agent Report - 2026-06-03

검토 기준:

- 현재 진입점은 `AppShellScreen`의 홈 대시보드입니다.
- 함께 확인한 흐름은 사용 가이드, 홈, 복습 탭, 플래시카드, 퀴즈 결과, 단어장 관리, SRS/플랜 계산입니다.
- 생산 코드 수정 없이 UX 관점 1차 점검만 수행했습니다.

1. 현재 UX 문제

- 첫 실행 가이드는 있지만, 단어장이 없을 때 사용자가 바로 실행할 수 있는 "첫 3분 학습" 경로가 약합니다.
- 홈에는 오늘의 처방, CTA, 복습/새 단어/학습 중, 플랜, 연속 학습, 오늘의 단어, 단어장 현황이 모두 있어 정보량이 많습니다. 핵심 CTA는 좋지만 주변 정보가 많아 "지금 이것만 하면 된다"는 감각이 약해질 수 있습니다.
- 홈의 추천 행동은 플래시카드 복습으로, 복습 탭의 오답/복습 재확인은 스펠링 퀴즈로 연결됩니다. 사용자는 "복습", "오답 복습", "셀프 테스트"의 차이를 흐름보다 화면 이름으로 이해해야 합니다.
- SRS 상태 용어는 가이드에는 설명되어 있지만, 홈 카드 안에서는 짧은 라벨 중심입니다. 특히 "학습 중"은 오늘 해야 할 일인지, 기다리는 상태인지 오해할 수 있습니다.
- 플랜은 복습 부담에 따라 새 단어 수를 줄이는 좋은 구조가 있으나, 사용자는 "잠긴 단어"를 제한이나 손해로 받아들일 수 있습니다.
- 결과 화면은 다음 행동을 제안하지만, "오늘은 여기까지도 성공"이라는 선택이 더 명시적으로 보상받지는 않습니다.

2. 사용자 불편 지점

- 첫 사용자: 단어장을 가져와야 한다는 것은 알지만, CSV/Google Sheet 중 무엇을 고르고 어떤 형식이면 되는지 바로 알기 어렵습니다.
- 일일 사용자: 복습 대기, 새 단어, 학습 중, 안정 기억 숫자가 동시에 보이면 무엇이 필수이고 무엇이 선택인지 구분이 흐려집니다.
- 복습 사용자: 플래시카드에서 "몰라요"를 누르는 행동이 SRS에 어떤 영향을 주는지, 퀴즈 오답과 같은 의미인지 헷갈릴 수 있습니다.
- 플랜 사용자: 오늘 새 단어 수가 플랜 목표보다 줄었을 때 앱이 나를 막는 것처럼 느낄 수 있습니다.
- 결과 사용자: 약한 단어 재시도는 유용하지만 피곤한 날에는 재시도를 거절해도 괜찮다는 안도감이 부족합니다.

3. 추천 개선안

- 홈 첫 화면의 메시지를 항상 세 문장으로 수렴시킵니다: 오늘 무엇을 할지, 왜 먼저 해야 하는지, 대략 몇 분인지.
- 단어 상태를 "필수/선택/성과"로 재분류해 보여줍니다. 복습 대기는 필수, 새 단어는 오늘 가능, 학습 중은 대기/보너스, 안정 기억은 성과로 설명합니다.
- 첫 실행 빈 상태에는 "단어장 가져오기", "예시 단어장으로 3분 체험", "직접 단어 추가" 중 하나를 고르게 하는 온보딩을 둡니다.
- 복습 탭의 학습 방식은 "오늘 복습 카드", "새 단어 카드", "셀프 테스트" 순서로 홈과 같은 언어를 사용합니다. "오답 복습"은 결과 화면 이후의 후속 행동으로 좁히는 것이 좋습니다.
- 플래시카드 종료와 퀴즈 결과에는 항상 "추천 다음 행동"과 "오늘은 여기까지"를 함께 둡니다. 후자는 실패가 아니라 루틴 완료로 표현합니다.
- 플랜 카드의 "잠긴 단어"는 "오늘 하지 않아도 되는 단어"로 바꿔 부담을 낮춥니다.
- 연속 학습은 숫자만 보여주기보다 "오늘 기록 조건"을 작게 설명합니다. 예: 복습 1개라도 저장하면 오늘 기록 유지.

4. 예시 사용자 흐름

- 첫 실행: 앱 실행 -> 빠른 가이드 -> 단어장 없음 카드 -> "예시 단어장으로 3분 체험" 또는 "단어장 가져오기" -> 하루 새 단어 목표 선택 -> 홈에서 "새 단어 10개 시작, 약 3분" -> 플래시카드 -> 퀴즈 또는 오늘은 여기까지 -> 홈 완료 상태.
- 일반 일일 복습: 홈에서 "복습 12개부터, 약 4분" -> 플래시카드 복습 -> 모르는 단어가 있으면 "헷갈린 3개만 다시 보기" -> 복습 완료 -> 새 단어 가능 또는 오늘은 여기까지 -> 홈에서 오늘 목표 완료 확인.
- 새 단어 추가일: 홈에서 복습 대기 0개 확인 -> "새 단어 8개 시작" -> 플래시카드로 처음 학습 -> 짧은 퀴즈 -> 결과에서 안정적이면 새 단어 완료, 흔들리면 카드로 다시 정리.
- 피곤한 날: 홈에서 복습 5개만 처리 -> 결과 화면에서 "오늘은 여기까지도 성공" 선택 -> 연속 학습 유지와 다음 복습 예약 확인.

5. 추천 문구

- "오늘 할 일: 복습 12개부터"
- "약 4분이면 끝나요"
- "복습을 마치면 새 단어가 열립니다"
- "새 단어: 오늘 처음 만날 단어"
- "학습 중: 다음 복습일을 기다리는 단어"
- "복습 대기: 오늘 다시 보면 좋은 단어"
- "안정 기억: 긴 간격으로 넘어간 단어"
- "잠긴 단어: 오늘은 하지 않아도 되는 단어"
- "헷갈린 단어만 다시 볼게요"
- "오늘은 여기까지도 성공이에요"
- "내일 다시 볼 단어가 예약됐어요"
- "3분 루틴 완료"

6. 기대 효과

- 사용자가 매일 앱을 열었을 때 첫 행동을 더 빨리 결정할 수 있습니다.
- SRS와 플랜이 제한이 아니라 부담을 줄이는 장치로 이해됩니다.
- 틀린 단어를 다시 보는 흐름이 벌처럼 느껴지지 않고, 회복 루틴으로 받아들여집니다.
- 짧게 끝내는 선택도 성취로 보이므로 일일 지속성이 올라갑니다.
- 홈, 복습, 플래시카드, 퀴즈, 결과 화면의 용어가 같아져 학습 흐름의 예측 가능성이 높아집니다.
