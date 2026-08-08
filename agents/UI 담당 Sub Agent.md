# UI 담당 Sub Agent Memory

session-id: 019e8b15-81bb-7de3-bfe0-850e8e503442

## Official Role Definition - 2026-06-04

Agent name:

- UI 담당 Sub Agent

Official role:

- 화면 구성, 시각적 계층, 색상, 타이포그래피, 간격, 컴포넌트 일관성을 개선한다.
- 중요한 버튼과 학습 상태가 잘 보이도록 한다.
- 과도하게 복잡한 디자인을 피한다.
- 재사용 가능한 UI 컴포넌트를 제안한다.

Boundary:

- 비즈니스 로직, SRS 규칙, AI 모델 정책, 코드 구조 판단은 직접 결정하지 않는다.
- 해당 판단이 필요하면 PM에게 넘기고, PM이 담당 Agent에 배정한다.

## Role

You are the UI design sub agent for the vocabulary memorization app.

Your responsibility is improving screen composition, visual hierarchy, colors, typography, spacing, and component consistency.

## Project Overview

The app should feel modern, calm, focused, and easy to understand.

The user should understand the next action immediately after opening the home screen.

Important user actions:

- start review
- learn new words
- check progress
- manage wordbooks
- continue today's learning journey

## Shared Main Screen Research Table

| Area | Current Finding | Improvement Direction |
| --- | --- | --- |
| Home hierarchy | Home has useful metrics and a start button, but the most important next action can be clearer. | Put a "today's prescription" card first with count, estimated time, and CTA. |
| CTA | The CTA is visually large but generic. | Make CTA label and supporting chip dynamic. |
| Progress | Progress can be misunderstood. | Use clearer label, segmented status bar, or true completion progress. |
| Navigation | Six bottom tabs may feel crowded. | Reduce bottom tabs or move low-frequency items out. |
| Wordbook card | Wordbook card is useful but visually heavy. | Keep it below the primary task and make switch/manage affordance clear. |
| Habit visuals | No visible streak or weekly rhythm. | Add compact streak/weekly heatmap if it does not clutter the top. |
| Components | AppShellScreen and HomeScreen contain overlapping home ideas. | Suggest reusable cards for daily task, metric tile, wordbook status, and quick action. |

## Assigned Tasks

1. Review the current main screen visual hierarchy.
2. Identify which information should be above the fold.
3. Suggest a calm modern layout for the home screen.
4. Check consistency of colors, typography, spacing, cards, chips, and icon use.
5. Propose reusable UI components.

## Review Criteria

- Is the main action obvious?
- Is information priority clear?
- Does visual weight match learning importance?
- Are text, buttons, and cards readable on mobile?
- Does the UI feel like a study tool rather than a marketing page?

## Expected Output

Return a concise UI audit with:

- high-priority visual changes
- proposed screen order
- reusable component candidates
- risks or questions for PM

## PM Dispatch - 2026-06-03

Assigned by:

- PM Sub Agent
- PM session-id: 019dba38-6085-7a22-9609-43d93a782102

Your session-id:

- 019e8b15-81bb-7de3-bfe0-850e8e503442

Role table received:

- You are the UI design Sub Agent for the vocabulary memorization app.
- Your role is to improve screen composition, visual hierarchy, colors, typography, spacing, and component consistency.
- You must not make business-logic decisions.
- You must focus on practical Flutter UI improvements that can be applied quickly.

Project goals to consider:

1. 화면은 단순하고 직관적이어야 한다.
2. 사용자는 앱을 열었을 때 바로 무엇을 해야 하는지 알 수 있어야 한다.
3. 앱은 깔끔하고 현대적이며 공부하고 싶게 느껴져야 한다.
4. 중요한 행동은 복습 시작, 새 단어 학습, 진도 확인, 단어장 관리, 오늘의 학습 이어가기이다.

Current assigned work:

1. 현재 앱의 UI 개선점을 독립적으로 점검한다.
2. 홈, 복습, 플래시카드, 퀴즈, 통계, AI 학습, 설정 화면에서 시각적 일관성 문제를 찾는다.
3. 카드, 버튼, 칩, 다이얼로그, 하단바, 상단바, 입력 폼의 스타일 통일 방안을 제안한다.
4. 텍스트가 잘리거나 시각적 균형이 무너지는 화면을 우선 지적한다.
5. 구현 가능한 컴포넌트 단위 개선안을 제안한다.

Required response format:

1. 발견한 UI 문제
2. 추천 레이아웃 변경
3. 컴포넌트별 개선안
4. 색상 / 글꼴 / 간격 제안
5. 우선순위
6. Flutter 구현 참고사항

Memory rule:

- Store future UI findings and PM assignments in this file.
- Do not edit other Agent memory files.

## Agent Report - 2026-06-03

검토 방식:

- 정적 UI 코드 점검으로 진행했다.
- 검토 범위는 홈, 복습, 플래시카드, 객관식/스펠링 퀴즈, 통계, AI 학습, 설정이다.
- production code는 수정하지 않았다.
- `flutter analyze`는 실행하지 않았다.

### 1. 발견한 UI 문제

- 홈 탭은 `AppShellScreen` 기준으로 "오늘의 학습"과 처방형 CTA가 이미 전면에 배치되어 방향은 좋다. 다만 상단 셸, 히어로 문구, 오늘 패널, 학습 플랜 카드, 습관 카드가 연속으로 쌓여 작은 모바일에서는 단어장 현황과 보조 행동이 아래로 많이 밀릴 수 있다.
- 오늘 패널 내부의 CTA 제목/설명, 지표 3개, 진행률 설명이 한 카드에 모두 들어가 있어 정보량이 많다. 긴 한국어 문구가 `maxLines: 1~2`로 잘릴 가능성이 있고, CTA의 실제 행동이 "복습/새 단어/전체 카드"로 바뀌는 만큼 보조 설명의 가독성이 중요하다.
- 복습 탭은 이어가기 카드와 플래시카드/테스트/오답 복습 카드가 같은 화면에 반복되어 있다. 빠른 시작 행동은 명확하지만, 2차 행동이 모두 비슷한 카드 무게를 가져 우선순위가 약해질 수 있다.
- 플래시카드 준비 화면은 단어장 선택, 루틴 요약, 보기 방향 설정, 세 가지 시작 카드가 순서대로 배치되어 있다. 시작 카드들이 비슷한 시각적 무게를 가져 "오늘 추천 시작"과 "수동 시작"의 차이가 덜 보인다.
- 플래시카드 세션 화면은 카드와 하단 판단 버튼이 잘 분리되어 있다. 다만 긴 예문/번역이 카드 안에서 스크롤되는 구조라, 카드 상단 배지와 하단 TTS 버튼 사이 공간이 좁은 기기에서는 답답해질 수 있다.
- 객관식 퀴즈는 4개 보기를 한 화면에 고정하는 구조이고, 보기 텍스트가 `maxLines: 3`으로 제한된다. 긴 뜻이나 예문형 뜻은 잘릴 수 있으며, 고정 ListView가 작은 화면에서 압축감을 만들 수 있다.
- 스펠링 퀴즈는 숨겨진 1px TextField와 글자 박스 UI를 사용한다. 학습 몰입감은 좋지만, 접근성/포커스 affordance가 약하고 긴 단어는 30px 박스가 여러 줄로 늘어나면서 CTA와 간격이 불안정해질 수 있다.
- 통계 탭은 범위 전환, 숙련도, 지표 카드, 상세 현황으로 구성되어 있다. 정보 구조는 적절하지만 "현재 플랜/전체 단어장" 범위가 바뀔 때 카드 색과 제목만으로는 사용자가 표본 범위를 즉시 파악하기 어려울 수 있다.
- AI 학습 탭과 AI 설정 카드는 기능이 많아 한 카드 안 밀도가 높다. AI 퀴즈 설정의 단어 선택 목록은 고정 높이 200px라 단어가 많을 때 선택 작업이 좁게 느껴질 수 있다.
- AI 퀴즈 플레이어는 기본 `Card`, 8~12px radius, 하드코딩된 green/red shade를 사용한다. 앱의 `GlassmorphicCard`, 큰 radius, 다크/시력보호 색 체계와 어긋나므로 AI 결과 화면만 다른 앱처럼 보일 수 있다.
- 설정 탭은 `AppShellScreen` 내부 탭으로 표시될 때 `AppSettingsScreen`의 별도 `Scaffold`와 `AppBar`를 그대로 렌더링한다. 셸 상단바와 설정 AppBar가 함께 보여 이중 프레임처럼 느껴질 위험이 있다.
- 카드 radius가 18, 20, 22, 24, 28, 34로 넓게 섞여 있다. 현재 부드러운 톤은 유지하되, 반복 컴포넌트끼리 radius와 padding 규칙을 좁혀야 한다.
- `NotoSansKR` 폰트 자산은 등록되어 있지만 테마는 `fontFamilyFallback` 중심이다. OS별 기본 한글 폰트 차이로 글꼴 두께와 줄 높이가 달라질 수 있다.

### 2. 추천 레이아웃 변경

- 홈 상단 순서: 상단바/학습 범위 -> 오늘 처방 카드 -> 플랜 상태 한 줄 카드 -> 습관/목표 2분할 -> 오늘의 단어 -> 단어장 현황. 첫 화면에는 "오늘 처리할 개수, 예상 시간, 시작 CTA, 복습/새 단어/학습 중 지표"까지만 확실히 보이게 한다.
- 복습 탭은 "오늘 이어가기"를 단일 primary 카드로 두고, 플래시카드/객관식/스펠링/오답 복습은 2열 또는 compact list로 묶는다. 추천 행동과 수동 모드 선택의 시각적 무게를 분리한다.
- 플래시카드 준비 화면은 "오늘 추천 세션"을 첫 CTA로 승격하고, 전체 카드/새 단어/복습 카드는 segmented control 또는 compact option card로 정리한다.
- 객관식/스펠링 퀴즈는 문제 영역, 입력/보기 영역, 하단 CTA의 세 영역을 고정하되 화면 높이가 부족하면 보기/입력 영역만 스크롤되게 한다.
- 통계 탭은 상단에 범위 선택 segmented control을 명확히 두고, 선택된 범위명을 모든 요약 카드 헤더에 작게 반복 표시한다.
- AI 학습은 "AI 퀴즈 생성", "AI 예문 생성", "AI 문법 체크", "AI 설정"을 같은 크기 카드로 나열하기보다 생성 행동 3개를 먼저, 설정은 접을 수 있는 하위 섹션이나 별도 설정 카드로 낮춘다.
- 설정 탭은 셸 탭 안에서는 AppBar 없는 섹션형 콘텐츠로 표시하고, 외부에서 push될 때만 AppBar를 유지한다.

### 3. 컴포넌트별 개선안

- `TodayLearningPanel`: 제목/설명/CTA/지표/진행률을 모두 담는 패널은 유지하되, CTA는 별도 `PrimaryRoutineCTA`로 분리해 홈과 복습 탭에서 재사용한다.
- `GlassmorphicCard`: 기본 radius/padding을 앱 토큰으로 고정하고, 특수 카드만 명시적으로 override한다. 추천값은 일반 카드 20~22, 대형 히어로 카드 24, bottom sheet 28이다.
- `MetricTile`: 홈, 복습, 통계, 프로필 시트의 지표 카드를 같은 구조로 통일한다. label/value/helper/icon/accentColor를 받는 한 컴포넌트가 적합하다.
- `StatusChip`: 학습 범위, 플랜 적용, 잠긴 단어, API 상태, 정답/오답 배지를 같은 높이와 radius로 통일한다.
- `ModeOptionCard`: 플래시카드 시작 카드, 퀴즈 모드 카드, AI 생성 카드가 같은 icon/title/subtitle/cta 구조를 공유하게 한다.
- `QuizOptionTile`: 객관식 앱 퀴즈와 AI 퀴즈 플레이어의 선택지 UI를 통일한다. 정답/오답 색은 theme semantic color에서 가져온다.
- `SettingsSectionCard`: 설정, AI 설정, 출력 설정처럼 폼 요소가 많은 카드는 섹션 헤더, 설명, 컨트롤 간격을 동일하게 맞춘다.
- `ResultSummaryCard`: 객관식 결과, 스펠링 결과, AI 결과가 같은 결과 요약 카드와 재시작/복습 CTA를 사용하면 완료 경험이 더 안정적이다.

### 4. 색상 / 글꼴 / 간격 제안

- 색상 역할을 고정한다: 복습=coral, 새 단어=sage green, 학습 중=amber, 안정 기억=deep green 또는 neutral blue, 정보=neutral gray/blue. 같은 의미의 숫자는 모든 화면에서 같은 색을 사용한다.
- 라이트 테마의 coral/brown은 브랜드 포인트로 좋지만 버튼/히어로에 많이 반복되면 무거워질 수 있다. 넓은 배경은 neutral surface를 유지하고 CTA와 중요한 상태에만 coral을 쓴다.
- 다크 테마는 espresso/brown 계열이 강하다. 카드 surface에 더 중립적인 charcoal을 섞고, 학습 상태 색은 saturation을 낮춰 긴 학습 시간에도 피로감이 덜하게 한다.
- `NotoSansKR`를 primary `fontFamily`로 지정하는 것을 권장한다. 현재 등록된 폰트 자산을 실제로 사용하면 Windows/web/Android에서 글자 폭과 굵기가 더 일관된다.
- 화면 padding은 20 또는 24, 카드 내부 padding은 16 또는 18, 섹션 간격은 22 또는 24, 카드 간격은 12 또는 14로 정리한다.
- 버튼 높이는 48~52를 유지하고, 긴 CTA 텍스트는 아이콘+짧은 동사형 라벨을 기본으로 두며 설명은 아래 보조 텍스트로 분리한다.

### 5. 우선순위

- P1: 설정 탭의 nested `Scaffold/AppBar` 구조를 탭 전용 레이아웃으로 분리한다.
- P1: AI 퀴즈 플레이어의 기본 `Card`, 하드코딩 green/red, 작은 radius를 앱 공통 카드/색상 체계로 교체한다.
- P1: 객관식 보기와 스펠링 글자 박스가 긴 텍스트/긴 단어/작은 화면에서 잘리지 않도록 반응형 제약을 둔다.
- P1: 홈 첫 화면에서 오늘 처방 CTA가 확실히 보이도록 상단 정보량을 유지 점검한다.
- P2: 카드 radius, padding, chip 높이, 아이콘 박스 크기를 토큰화한다.
- P2: 플래시카드 준비 화면과 복습 탭에서 추천 행동과 보조 행동의 시각적 무게를 분리한다.
- P2: AI 설정/AI 퀴즈 설정의 긴 폼을 섹션형 카드와 더 넓은 단어 선택 UI로 정리한다.
- P3: 현재 `main.dart`에서는 쓰이지 않는 legacy `HomeScreen`, standalone `QuizResultScreen`의 UI 패턴이 다시 노출될 경우 셸 디자인과 맞춘다.

### 6. Flutter 구현 참고사항

- 설정 화면은 `AppSettingsScreen(showAppBar: bool = true)` 또는 `SettingsContent` 분리 방식으로 셸 탭과 push 화면을 구분하면 된다.
- 객관식 퀴즈는 `LayoutBuilder`로 남은 높이를 계산하고, 선택지 영역은 높이가 부족할 때 `SingleChildScrollView` 또는 adaptive grid/list로 전환한다.
- 스펠링 박스는 단어 길이에 따라 box width를 30 -> 26 -> 22처럼 줄이거나, `Wrap`의 line count가 늘어날 때 입력 영역과 CTA 사이 간격을 자동 축소한다. 숨겨진 TextField에는 `Semantics` label과 명확한 탭 가능 영역을 둔다.
- AI 퀴즈 플레이어는 `Card` 대신 `GlassmorphicCard` 또는 공통 `StudySurfaceCard`를 사용하고, 정답/오답 배경은 `colorScheme` 또는 semantic palette에서 가져온다.
- `AppTheme`에 spacing/radius/iconSize 토큰을 추가하면 화면별 매직 넘버를 줄일 수 있다.
- `ThemeData.textTheme`에 `fontFamily: 'NotoSansKR'` 적용 여부를 확인한다. 폴백은 유지하되 primary font를 명확히 지정하는 편이 UI QA에 유리하다.
- 고정 높이 목록은 단어 수가 많은 화면에서 답답해질 수 있으므로 AI 단어 선택 목록은 bottom sheet/full-screen selector 또는 `maxHeight` 기반 adaptive height를 권장한다.
