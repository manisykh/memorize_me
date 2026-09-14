# Memorize Me 상용화 개선 보고서

작성일: 2026-09-05 · 대상: 현재 로컬 Flutter 구현, 커밋되지 않은 변경 포함

후속 업데이트(2026-09-07): 실제 연결 기기에서 화면을 캡처한 [시각 디자인 평가 보고서](C:/Users/manis/flutter_PJT/memorize_app/design_audit_2026-09-05/VISUAL_DESIGN_REPORT_2026-09-07.md)를 추가했다. 아래 내용은 작성 당시의 코드 기반 검토이며, 시각 평가와 설치 빌드의 검증 범위는 후속 보고서를 참조한다.

## 1. 판단과 검토 한계

Memorize Me는 단어장 가져오기, 카드, 객관식·스펠링, SRS, 학습 플랜, 달력, 누적 오답, AI 생성, 시험지 내보내기까지 갖춘 앱이다. 기능 폭은 충분하다. 다음 개선의 중심은 **첫 학습 진입, 화면 사이 학습 범위 유지, 데이터 저장 신뢰, 정보 구조와 디자인 규칙 통일**이다.

이번 결과는 **코드·정보 구조 기반 사전 검토**다. 실제 기기 화면을 캡처한 시각·인터랙션 감사는 완료하지 못했다. 현재 연결된 UI 도구는 브라우저만 지원하고 네이티브 앱 제어는 비활성이다. 열린 앱 웹 화면도 없었다. 소스는 `dart:io`, `sqflite`, 네이티브 Firebase 초기화에 의존하므로 웹 폴더가 있다는 이유로 네이티브와 동일한 실행 화면이라고 가정하지 않았다.

- 현재 소스와 디자인 명세를 대조했으며, 실제 동작의 성공 여부는 실행 검증하지 않았다.
- 기존 홍보 이미지·온보딩 일러스트를 현재 앱 스크린샷처럼 사용하지 않았다.
- 픽셀 단위 정렬, 실제 색 대비, 터치감, 화면 넘침, 속도, VoiceOver/TalkBack 품질은 미판정이다.
- 아래에서 **확인**은 소스에서 직접 확인한 사실, **위험**은 그 구조에서 예상되는 문제, **제안**은 검증할 개선 방향이다.
- 앱 코드는 변경하지 않았고 테스트를 실행하지 않았다. 테스트 파일의 존재와 다루는 사례만 확인했다.

Product Design 감사 스킬의 제한: “Do not claim an audit if the actual flow could not be accessed and captured.” 따라서 본 문서는 화면 감사 완료 보고서가 아니다. [적용한 audit SKILL.md](C:/Users/manis/.codex/plugins/cache/openai-curated-remote/product-design/0.1.53/skills/audit/SKILL.md)

## 2. 현재 앱 구성과 사용자 여정

아래 상태는 시각적 점수가 아니라 코드에서 확인되는 구성의 평가다.

| 단계 | 현재 구성 | 상태와 주요 검토점 |
|---|---|---|
| 1. 첫 실행 | Firebase 초기화 → 데이터 초기화 → 6장 온보딩 → 조건부 출시 공지 → 앱 셸 | 건너뛰기·데이터 초기화 재시도 있음. 첫 학습 전 안내량과 Firebase 초기화 실패 복구 점검 필요 |
| 2. 자료 준비 | 단어장 관리 → 기본 단어장 / Google Sheets / CSV·XLSX → 열 매핑·미리보기 | 입력 방법이 다양하고 기본 자료도 있음. 첫 실행에서 기본 단어장 체험으로 연결하는 직접 경로 개선 여지 |
| 3. 오늘 학습 | 홈의 복습·새 단어 추천, 예상 시간, 완료율, 플랜 요약, 단어장 현황 | 핵심 CTA가 상태에 따라 달라지는 기반이 좋음. 오늘·전체·현재 묶음 의미를 간결하게 전달할 필요 |
| 4. 카드 학습 | 준비 화면 → 카드 뒤집기·TTS·알아요/몰라요·되돌리기 → 결과 | 스와이프 외 버튼 조작과 결과 후 행동 있음. 중단 복원·저장 실패 인지·모션 접근성 보완 |
| 5. 기억 확인 | 셀프 테스트 → 객관식 / 스펠링 / 오답 → 결과·재학습 | 첫 정답·재도전·스킵 구분, 오답 연결 기반 있음. 카드에서 넘어온 출제 범위 보존 점검 필요 |
| 6. 성과·다음 일정 | 통계 / 달력 / SRS 현황 / 누적 오답 이력 | 기록이 풍부함. 통계와 달력의 상위 내비게이션 역할을 통합할 여지 |
| 7. AI 활용 | AI 학습 → 예문·퀴즈·문법 → 모델/API 설정 → 생성·풀이·내보내기 | 오류 분류·자동 대체·문항 검증 기반 있음. API 키 요구가 일반 사용자 진입 장벽 |
| 8. 계정·설정 | Google 연결·혜택 복원·계정 삭제, 테마, 가이드, 음성, AI | 선택적 계정 사용과 삭제 영향 안내 있음. 학습 데이터 백업과 혜택 복원을 분명하게 구분할 필요 |

실제 메인 화면은 [app_shell_screen.dart](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:575)다. 명세의 화면 이름만 보고 구형 홈을 현재 화면으로 평가하지 않았다. [현재 디자인 명세](C:/Users/manis/flutter_PJT/memorize_app/design.md)

## 3. 유지할 강점

1. **사용자 단어장 중심의 학습**: Google Sheets, 로컬 파일, 기본 단어장까지 지원해 시작 자료 선택권이 있다.
2. **오늘 할 일 추천이 이미 존재**: 홈은 복습 우선, 가능한 새 단어, 학습 중 카드 확인 순으로 행동을 결정한다. 개선 시 이 로직을 살려야 한다. [홈 추천](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:836)
3. **학습 방식 연결 기반**: 카드 결과에서 퀴즈, 퀴즈 결과에서 재학습으로 이어지는 흐름이 있다. 단순 기능 나열만 있는 상태가 아니다. [카드 결과](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/flashcard_screen.dart:352)
4. **SRS와 이력 구분**: 중단 세션의 응답과 완료 세션을 구분하고, 퀴즈 첫 정답·재도전 관련 테스트가 있다. [학습 이력](C:/Users/manis/flutter_PJT/memorize_app/lib/services/study_history_service.dart:123), [퀴즈 SRS 테스트](C:/Users/manis/flutter_PJT/memorize_app/test/services/quiz_srs_test.dart:11)
5. **접근성 일부 기반**: 카드 판단 버튼·되돌리기 tooltip, 달력 semantic label, 좁은 화면/큰 글자 달력 테스트가 있다. 접근성을 처음부터 새로 시작할 필요는 없다. [달력](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/study_calendar.dart:166), [달력 테스트](C:/Users/manis/flutter_PJT/memorize_app/test/widgets/study_calendar_test.dart:42)
6. **운영 기반**: Crashlytics, Analytics, Remote Config, AI 응답 검증이 있다. 설치만 된 기능과 실제 호출은 구분해야 하지만, 온보딩·카드 시작/완료 등 호출도 확인했다. [이벤트 정의](C:/Users/manis/flutter_PJT/memorize_app/lib/services/analytics_service.dart:16)

## 4. 우선순위별 개선 항목

P0 = 출시 전 신뢰·복구 기준으로 우선 확인. P1 = 핵심 사용 흐름 개선. P2 = 재방문·확장 개선. P0라고 현재 장애가 재현되었다는 뜻은 아니다.

### R01 · P0 · 학습 저장 실패를 학습 화면에서 알려야 한다

**확인:** SRS 쓰기 큐는 실패를 `srsSaveError`에 저장하고 예외를 내부에서 처리한다. 재시도 기능도 있다. 그러나 해당 오류와 학습 이력 저장 오류의 재시도 UI 참조는 달력에 있다. 카드 완료 처리는 저장 큐 대기 후 결과 안내로 진행한다.

**위험:** 사용자가 완료 화면만 보고 저장까지 끝났다고 생각할 수 있다. 저장 실패를 발견하려고 달력으로 이동해야 하는 흐름은 학습 데이터에 대한 신뢰를 떨어뜨린다.

**제안:** 세션 결과·홈에 `저장 완료 / 저장 중 / 저장 재시도 필요`를 표시한다. 네트워크와 무관한 로컬 저장 실패도 설명하고, 미저장 데이터는 재시작 후 회수할 수 있게 설계한다. 이미 있는 쓰기 큐와 재시도 기능을 재사용한다.

**완료 기준:** DB 쓰기를 의도적으로 실패시켜도 결과 화면에서 실패와 재시도를 인지할 수 있고, 재시도 후 SRS·이력이 중복되지 않는다.

근거: [저장 큐](C:/Users/manis/flutter_PJT/memorize_app/lib/providers/wordbook_manager.dart:473), [카드 완료](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/flashcard_screen.dart:322), [달력 재시도](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/study_calendar.dart:206)

### R02 · P0 · 혜택 복원과 학습 데이터 복구를 분리한다

**확인:** 계정 연결 용도는 Google 시트와 초기 사용자 혜택 복원이라고 안내한다. 학습 데이터는 로컬 DB에 저장한다. 확인한 코드에는 단어장·예문·SRS·플랜·세션을 함께 백업하고 복원하는 앱 수준의 전체 복구 경로가 없다. CSV 내보내기는 단어·뜻·추가 뜻만 포함한다.

**위험:** 기기 변경 시 혜택 복원을 학습 기록 복원으로 오해할 수 있다. CSV 파일을 전체 백업으로 사용해도 학습 상태는 복구되지 않는다. OS 자동 백업의 작동 여부는 이번에 검증하지 않았다.

**제안:** 우선 버전이 포함된 전체 백업 파일과 복원 미리보기, 기존 데이터와의 충돌 정책을 제공한다. 그 다음 계정 기반 자동 백업·동기화를 검토한다. 화면에는 마지막 백업 시각과 포함되는 데이터를 구체적으로 표시한다.

**완료 기준:** 새 설치에 백업을 복원했을 때 단어·예문·SRS·플랜·학습 이력 건수가 일치하고, 잘못된 파일은 기존 데이터 변경 전에 거절한다.

근거: [계정 용도](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_settings_screen.dart:364), [CSV 출력 필드](C:/Users/manis/flutter_PJT/memorize_app/lib/services/csv_service.dart:72), [로컬 DB](C:/Users/manis/flutter_PJT/memorize_app/lib/services/database_service.dart:33)

### R03 · P0 · 앱 시작과 가져오기 오류의 복구 경로를 완성한다

**확인:** `Firebase.initializeApp()`을 `runApp()`과 전역 오류 핸들러 설치 전에 기다린다. 이후 단어장 초기화 오류에는 재시도 화면이 있지만, 그 화면이 Firebase 초기화 실패까지 처리하지는 못한다. Google 시트 목록 오류 UI는 예외 문자열을 출력하며 같은 상태에서 누를 재시도 버튼이 없다.

**제안:** 앱 시작 실패 범위를 구분해 최소 오류 화면·재시도를 보장한다. 로컬 학습은 선택적 외부 서비스의 실패로 막히지 않도록 의존성을 검토한다. 가져오기에는 사용자 언어 오류, 재시도, 로그인 복구를 제공한다.

**완료 기준:** Firebase 초기화 실패, 시트 권한 만료, 시트 로딩 실패를 각각 주입해도 빈 화면이나 복구 불가능한 대기 상태가 생기지 않는다. 오프라인이면 Firebase 초기화가 반드시 실패한다는 뜻은 아니다.

근거: [앱 시작](C:/Users/manis/flutter_PJT/memorize_app/lib/main.dart:38), [데이터 초기화 재시도](C:/Users/manis/flutter_PJT/memorize_app/lib/main.dart:260), [시트 오류](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/select_sheet_screen.dart:176)

### R04 · P1 · 카드에서 퀴즈로 넘어갈 때 학습 범위를 유지한다

**확인:** 카드의 `_goToQuiz()`는 출처와 객관식 모드를 전달하지만 `_sessionWords`는 전달하지 않는다. 퀴즈는 활성 단어장의 `wordsAvailableForPlan()`으로 `_words`를 다시 만든다. 일반 객관식은 이 `_words`를 사용한다. `wordsOverride`는 현재 오답용 목록에 적용된다.

**위험:** 새 단어 일부만 카드로 학습한 뒤 `퀴즈 시작`을 누르면 방금 배운 단어보다 넓은 플랜/단어장 범위에서 출제될 수 있다. 실행 재현은 필요하지만, 화면 간 범위 전달이 빠진 것은 확인된다.

**제안:** 세션에 단어장·단어 목록·출처·문항 수를 묶어 전달한다. 기본 CTA는 `방금 배운 N개 확인`, 더 넓은 범위는 별도 선택으로 둔다. 선다형 오답 선택지 풀은 출제 대상과 분리해 유지한다.

**완료 기준:** 예를 들어 100단어 중 10개를 학습한 경우 다음 퀴즈의 출제 대상은 그 10개로 유지된다. 단어장에 선택지 후보가 부족할 때 대체 방식도 제공한다.

근거: [카드 → 퀴즈](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/flashcard_screen.dart:466), [퀴즈 범위 구성](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/quiz_screen.dart:143), [일반 객관식 입력](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/quiz_screen.dart:446)

### R05 · P1 · 하단 탭을 사용자의 목적 기준으로 정리한다

**확인:** 현재 6개 탭은 홈·복습·통계·달력·AI 학습·설정이다. 단어장은 홈에서 관리 화면으로 들어가며, 복습 탭에는 새 학습에도 쓰이는 카드·셀프 테스트가 함께 있다. 내비게이션 공통 라벨은 10으로 설정된다.

**제안:** 1차 검증안은 **오늘 / 단어장 / 학습 / 기록 / AI**의 5개 탭이다. 통계와 달력은 기록의 하위 화면으로 묶고, 설정은 프로필에서 연다. 학습 탭에는 카드·테스트·오답을 배치한다. AI 이용률이 낮다면 이후 학습 안으로 옮기는 4탭안도 비교할 수 있다.

**이유:** 핵심 자료와 반복 행동의 위치를 고정하고, 서로 연관된 기록 화면을 한곳에 모은다. Android 공식 내비게이션 가이드도 동등한 중요도의 목적지 3~5개를 기본 범위로 제시한다. 6개라는 숫자만으로 사용성 실패를 단정하지는 않는다. [공식 기준](https://developer.android.com/develop/ui/compose/components/navigation-bar)

**완료 기준:** 첫 사용자 검증에서 단어장 찾기·오늘 복습 시작·기록 확인을 설명 없이 수행하며, 좁은 화면과 큰 글자에서 라벨이 잘리지 않는다.

근거: [6개 목적지](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:554), [복습 탭](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:2317), [탭 글자 설정](C:/Users/manis/flutter_PJT/memorize_app/lib/themes/app_theme.dart:216)

### R06 · P1 · 첫 실행을 실제 학습 체험으로 연결한다

**확인:** 온보딩 6장은 기능 소개이며 건너뛰기가 있다. 종료 콜백 자체는 기본 단어장 선택이나 학습을 시작하지 않는다. 출시 공지는 기본값이 활성이고 표시 조건이 맞으면 별도 확인이 필요하다. 기본 단어장은 이미 6단계 템플릿이 있다.

**제안:** `기본 단어로 체험`과 `내 단어장 가져오기`를 첫 선택으로 둔다. 체험은 예컨대 5단어 카드 → 짧은 퀴즈 → 결과로 이어지게 한다. 기능 설명은 해당 기능을 처음 쓸 때 보여주고, 혜택 안내는 첫 학습 이후 자연스러운 위치에 둔다.

**완료 기준:** 로그인·API 등록 없이 기본 자료로 첫 세션을 완료할 수 있다. 첫 세션까지의 시간과 이탈 지점을 계측한다. 특정 시간 단축이나 전환율 개선은 검증 전 보장하지 않는다.

근거: [6장 온보딩](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/onboarding_screen.dart:20), [출시 공지](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/launch_notice_gate.dart:28), [기본 단어장](C:/Users/manis/flutter_PJT/memorize_app/lib/providers/wordbook_manager.dart:26)

### R07 · P1 · 홈은 현재의 추천 구조를 유지하면서 범위를 더 쉽게 설명한다

**확인:** 이미 홈의 주 행동은 복습·새 단어·점검 중 하나로 결정된다. 그 주변에는 오늘 복습/새 단어/학습 중 수치, 목표 완료율, 플랜 상태, 단어장 현황이 들어간다. 학습 플랜에는 자유·일정 달성·복습 우선 모드가 있다.

**제안:** 첫 화면에서 `오늘 무엇을 얼마나 할지`와 단일 시작 버튼을 우선한다. `오늘 완료`와 장기 기억 상태는 구분하고, 전체·묶음 범위를 항상 같은 위치에 표시한다. 플랜 수정·분포 해설은 상세로 내린다. 예시 문구는 `오늘 복습 12개 · 약 4분`, 보조 설명은 `새 단어는 복습 후 추천해요`처럼 행동 중심으로 쓴다.

**완료 기준:** 사용자가 오늘 남은 학습량, 현재 단어장, 시작 버튼의 대상을 설명할 수 있다. 수치가 많다는 이유만으로 현재 화면이 혼잡하다고 단정하지 않고 실제 캡처로 우선순위를 검증한다.

근거: [홈 구성](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:878), [플랜 UI](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/study_plan_panel.dart:184)

### R08 · P1 · 디자인 토큰과 강조 규칙을 한곳에서 관리한다

**확인:** `AppTheme`에 공통 색·타이포그래피가 있지만 셸의 `_ShellPalette`, `GlassmorphicCard`의 고정색, 학습 모드 색이 별도로 존재한다. 밝은 테마의 셸은 중립 배경·녹색, 공통 카드는 크림색·베이지 테두리를 사용한다. 화면별 `w900`과 10~11 크기의 보조 라벨도 있다.

**위험:** 여러 시각 스타일의 공존이 의도된 브랜드 표현인지 구현 편차인지 불명확하고, 테마 수정 때 일부 화면이 다른 규칙을 유지할 수 있다. 색 조합이 현재 보기 나쁘다는 판정은 아니다.

**제안:** 기존의 차분한 녹색과 종이 감성을 바탕으로 배경·표면·브랜드·주의·오답·성공 색을 의미별로 통일한다. 제목·본문·보조·숫자용 글자 역할, 카드 종류, 간격, 모서리 값을 공통화한다. 강조는 주 CTA와 핵심 숫자에 집중한다. 일러스트는 온보딩·빈 상태·완료처럼 맥락이 있는 곳에서 사용한다.

**완료 기준:** 밝음·어두움·시력 보호 테마에서 동일 컴포넌트가 동일한 의미의 색·크기·강조를 사용한다. 대표 화면을 함께 캡처해 일관성을 비교한다.

근거: [AppTheme](C:/Users/manis/flutter_PJT/memorize_app/lib/themes/app_theme.dart:3), [셸 팔레트](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:49), [공통 카드](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/glassmorphic_card.dart:22), [학습 모드 색](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/study_mode_icon.dart:1)

### R09 · P1 · 일반 사용자용 AI 진입과 고급 설정을 분리한다

**확인:** AI 탭에서 키가 없으면 `API 등록이 필요합니다`와 설정 이동을 표시한다. 설정의 AI 영역은 기본 접힘 상태다. 모델 선택·직접 입력·자동 대체 등 고급 기능이 있고, AI 서비스에는 timeout과 문항 형식 검증도 있다.

**제안:** 단기적으로 AI 진입에서 필요한 제공자·키 설정 화면을 바로 열고 성공 후 원래 작업으로 돌아온다. 사용 목적을 먼저 고르게 하고 모델 상세는 고급 영역에 둔다. 일반 소비자 대상으로 확장한다면 앱이 제공하는 제한된 AI 체험을 별도 검토하되, 이는 서버·비용·사용량 제한이 필요한 제품 결정이다. 사용자 키 방식은 고급 옵션으로 유지할 수 있다.

**완료 기준:** 설정 후 생성 대상·문제 수를 다시 고르지 않는다. 키 오류·한도 초과·부분 생성 성공을 구분해 안내한다. AI 문항의 형식 검증과 정답의 사실적 정확성 검증은 별도로 다룬다.

근거: [AI 준비 상태](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_shell_screen.dart:2892), [설정 접힘 상태](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_settings_screen.dart:30), [AI 문항 검증](C:/Users/manis/flutter_PJT/memorize_app/lib/services/ai_quiz_validator.dart:6)

### R10 · P1 · 중단 후 이어하기를 명시적인 기능으로 만든다

**확인:** 카드의 현재 위치·세션 단어 목록은 화면 State에 있고, 학습 응답 이력은 별도 저장된다. 확인한 활성 화면에는 종료한 세션의 남은 단어를 복원하는 `이어서 학습` 경로가 없다. 이미 처리한 SRS 저장과 동일 세션 재개는 다른 기능이다.

**제안:** 중단한 세션의 단어 목록·순서·응답·현재 위치·모드를 저장하고 홈에서 `남은 N개 이어하기`를 제공한다. 새 세션 시작과 이어하기를 구분하고, 플랜이 바뀌었을 때 원래 범위를 어떻게 처리할지 정의한다.

**완료 기준:** 강제 종료 후 재실행해도 남은 문항과 답안이 복원되고, 이미 반영된 SRS가 중복 업데이트되지 않는다.

근거: [카드 상태](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/flashcard_screen.dart:68), [세션 기록 모델](C:/Users/manis/flutter_PJT/memorize_app/lib/models/study_session_model.dart:74)

### R11 · P1 · 접근성을 출시 확인 항목으로 구체화한다

**확인:** 카드 뒤집기는 360ms 회전 애니메이션과 GestureDetector를 사용한다. 확인한 소스 검색에서는 `disableAnimations`/`accessibleNavigation` 대응 분기가 발견되지 않았다. 달력은 semantic label과 좁은 화면·확대 글자 테스트가 있다.

**제안:** 카드에 앞면/뒷면과 뒤집기 동작을 읽어주는 명시적 라벨을 부여하고 모션 감소 시 즉시 전환을 제공한다. 버튼 크기, 큰 글자, 오류 읽기, 초점 순서를 핵심 여정 전체로 확장 검증한다. 카드 판단 버튼이 있으므로 스와이프만 가능한 앱으로 평가하지 않는다.

**완료 기준:** TalkBack/VoiceOver로 첫 학습을 끝낼 수 있다. 작은 화면·큰 글자·3개 테마·모션 감소에서 핵심 CTA가 유지된다. Flutter 공식 가이드의 터치 목표와 큰 글자 검증을 활용한다. 이번 검토로 실제 대비 미달이나 접근성 준수 여부를 확정하지 않는다. [Flutter 접근성 기준](https://docs.flutter.dev/ui/accessibility)

근거: [카드 뒤집기](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/flashcard_screen.dart:1589), [판단 버튼](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/flashcard_screen.dart:1086), [달력 접근성](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/study_calendar.dart:166)

### R12 · P2 · 기록을 다음 행동과 재방문으로 연결한다

**확인:** 통계·달력·연속 학습 기록은 있으나, 확인한 소스와 의존성에는 학습 리마인더 기능이 보이지 않는다. Analytics에 온보딩 완료·학습 시작/완료·AI 생성·탭 이벤트가 있지만 세션 중단·가져오기 실패 단계·재개 같은 흐름 진단 이벤트 정의는 없다.

**제안:** 기록 화면에서 `이번 주 학습`, `반복해서 틀리는 단어`, `다음 복습`을 다음 행동과 연결한다. 알림은 사용자가 학습 가치를 경험한 뒤 시간·빈도를 선택하게 한다. 이벤트는 기존 체계에 이어서 추가하고 첫 세션 완료와 D1/D7 재방문을 측정한다.

**완료 기준:** 실패율·세션 완료율의 분모와 이벤트 중복 기준을 정의하고 실제 데이터로 검증한다. 알림은 완료한 학습을 반복 독촉하지 않으며 쉽게 끌 수 있다. 개선 후 수치 상승은 아직 검증되지 않았다.

근거: [Analytics 정의](C:/Users/manis/flutter_PJT/memorize_app/lib/services/analytics_service.dart:16), [달력 구성](C:/Users/manis/flutter_PJT/memorize_app/lib/widgets/study_calendar.dart:198), [의존성](C:/Users/manis/flutter_PJT/memorize_app/pubspec.yaml)

### R13 · P2 · 도움말과 대량 사용의 마찰을 줄인다

**확인:** 설정에는 가이드와 온보딩 다시 보기가 있다. 하지만 검토한 설정 메뉴에는 문의·오류 신고·앱 버전·개인정보 안내 링크가 드러나지 않는다. 단어장에는 검색·편집·열 매핑이 이미 있다.

**제안:** 도움말을 현재 문제에서 바로 접근하게 하고, 문의에는 사용자가 검토한 앱 버전·오류 코드만 첨부한다. 가져오기에는 읽은 행·추가한 단어·제외한 행과 이유를 요약하고, 재가져오기 시 새 단어 추가/기존 수정/건너뛰기 정책을 명시한다. 여기서는 법적 적합성이나 스토어 심사 통과 여부를 평가하지 않았다.

**완료 기준:** 빈 파일·잘못된 열·중복 단어·취소·일부 시트 실패를 구분하고, 사용자가 가져오기 결과와 다음 조치를 이해할 수 있다. 기능이 이미 부분 구현된 곳은 현재 동작을 확인한 후 확장한다.

근거: [설정 메뉴](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/app_settings_screen.dart:48), [시트 매핑 흐름](C:/Users/manis/flutter_PJT/memorize_app/lib/screens/select_sheet_screen.dart:36)

## 5. 권장 정보 구조

| 상위 화면 | 핵심 목적 | 포함할 하위 기능 |
|---|---|---|
| 오늘 | 지금 시작할 학습 하나를 제안 | 현재 단어장, 오늘 복습·새 단어, 이어하기, 완료 안내 |
| 단어장 | 내 자료를 찾고 관리 | 기본 단어장, 가져오기, 검색·편집, 학습 플랜 |
| 학습 | 원하는 방식으로 학습 | 카드, 객관식, 스펠링, 현재 오답·누적 이력 |
| 기록 | 성과와 일정을 확인 | 주간 요약, 통계, 달력, SRS 상세 |
| AI | 내 자료를 확장 | 예문, 퀴즈, 문법, 생성 결과·내보내기 |
| 프로필 내 설정 | 개인 환경과 데이터 관리 | 계정, 백업·복구, 테마, 음성, AI 고급 설정, 도움말 |

이는 구현 지시가 아니라 사용자 검증을 위한 제안이다. AI를 독립 탭에 둘지는 실제 사용률을 보고 조정한다.

## 6. 실행 순서와 통과 기준

| 순서 | 작업 묶음 | 완료 시 확인할 결과 |
|---|---|---|
| 1 | 실제 앱 기준 화면 캡처와 핵심 결함 재현 | 새 사용자/기존 사용자 여정, 카드→퀴즈 범위, 실패 복구 상태의 증거 확보 |
| 2 | R01~R04: 저장·복구·시작 오류·학습 범위 | 저장 실패가 보이고 재시도 가능, 백업 복구 일치, 학습 범위 유지 |
| 3 | R05~R08: 정보 구조·첫 학습·홈·디자인 시스템 | 기본 자료 첫 세션과 매일 복습을 설명 없이 완료, 대표 화면 시각 일관성 |
| 4 | R09~R11: AI 진입·이어하기·접근성 | 설정 왕복 후 맥락 유지, 강제 종료 복원, 보조기술로 핵심 여정 완료 |
| 5 | R12~R13: 재방문·측정·도움말·대량 자료 | 실제 실패/완료/재방문 데이터 확보, 문의·가져오기 결과 안내 검증 |

일정은 팀 인원, 목표 플랫폼, 백업의 로컬/서버 범위, AI 비용 모델에 따라 달라진다. 현재 정보만으로 확정 개발 기간이나 비용을 제시하지 않는다. 별도 대형 기능을 늘리기 전에 2~3번 묶음을 우선 완료하는 것이 좋다.

## 7. 후속 화면 감사에서 확보할 증거

1. 첫 설치: 온보딩·공지·빈 홈·기본 단어장 선택·첫 카드 진입.
2. 기존 사용자: 복습이 있는 홈·완료한 홈·플랜이 있는 홈.
3. 카드: 앞/뒤, 긴 뜻, 알아요/몰라요, 되돌리기, 중간 종료, 결과.
4. 카드 → 퀴즈: 같은 단어 범위 유지와 4개 미만 선택지 풀 조건.
5. 퀴즈: 첫 정답·재도전·스킵·오답 결과·후속 학습.
6. 데이터: Sheets 권한 취소/만료, CSV 열 오류, 빈 파일, 저장 실패, 복구.
7. 기록: 통계·달력·현재 오답·누적 오답 수치와 범위 설명.
8. AI: 키 없음·키 오류·대기·부분 성공·결과·원래 작업 복귀.
9. 공통: 밝음/어두움/시력 보호, 작은 화면/큰 글자, 스크린리더/모션 감소.

이 증거가 확보되어야 색 대비·레이아웃·인터랙션 완성도까지 포함한 최종 디자인 감사를 확정할 수 있다.
