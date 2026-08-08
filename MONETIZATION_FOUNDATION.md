# Memorize Me 유료화 기반 설계

이 문서는 Memorize Me의 무료 출시 정책과 향후 유료 전환을 위해 준비된 기술 구조, Firebase 설정 및 운영 절차를 설명합니다.

## 1. 출시 초기 운영 정책

출시 초기에는 다음 정책을 적용합니다.

- 모든 기능을 무료로 제공합니다.
- 배너 광고와 전면 광고를 표시하지 않습니다.
- 유료 결제 화면을 표시하지 않습니다.
- 초기 사용자는 `Founding` 사용자로 등록합니다.
- `Founding` 사용자는 향후 추가되는 유료 기능도 무료로 이용할 수 있습니다.
- Google Sheets 가져오기, CSV 가져오기, 기본 단어장, 플래시카드, SRS 복습, 기본 문제와 기본 통계는 유료 전환 이후에도 계속 무료로 제공합니다.

앱의 기본 Remote Config 값은 다음과 같습니다.

```text
monetization_mode = launch_free
enable_banner_ads = false
enable_interstitial_ads = false
enable_paywall = false
founding_program_open = true
```

Remote Config 또는 네트워크 연결에 문제가 발생하더라도 출시 초기에는 기능이 잠기지 않도록 `fail-open` 방식으로 구현되어 있습니다.

## 2. 사용자 권한 종류

앱 내부에서는 사용자를 다음 세 종류로 구분합니다.

### Free

일반 무료 사용자입니다. 유료 전환 이후에도 다음 핵심 기능을 계속 사용할 수 있습니다.

- Google Sheets 가져오기
- CSV 가져오기
- 기본 단어장
- 플래시카드
- SRS 복습
- 기본 객관식·주관식 문제
- 기본 통계

### Pro

Google Play 결제 또는 향후 구축할 결제 시스템을 통해 유료 권한을 취득한 사용자입니다.

현재는 결제 기능이 연결되어 있지 않으므로 `Pro` 권한을 자동으로 부여하는 기능은 아직 사용하지 않습니다. 추후 결제 서버가 구매를 확인한 후 이 권한을 기록해야 합니다.

### Founding

초기 무료 운영 기간에 등록한 사용자입니다.

- 현재 제공 중인 모든 기능을 무료로 이용합니다.
- 향후 추가되는 유료 기능도 무료로 이용합니다.
- 유료 전환 이후에도 평생 전체 기능 접근 권한을 유지합니다.
- 가능하면 Google 계정에 연결하여 기기 변경이나 재설치 후에도 권한을 복원할 수 있도록 합니다.

`Founding`은 사실상 초기 사용자에게 제공하는 평생 `Pro` 권한입니다.

## 3. Founding 무료 등록 종료 기준

종료일을 단순히 달력 날짜만으로 정하지 않습니다. 다음 조건을 모두 충족한 이후 종료일을 확정하는 것을 권장합니다.

1. 정식 출시 후 최소 90일이 지났습니다.
2. 서버에 등록된 Founding 사용자가 1,000명 이상입니다.
3. 최소 4주 연속으로 사용자 유지율이 안정적입니다.
4. 온보딩, 단어장 가져오기, 학습 시작 등 핵심 흐름이 더 이상 크게 변경되지 않는 상태입니다.
5. 크래시와 ANR 수준이 상용 서비스 운영에 적합합니다.
6. 첫 유료 기능 묶음과 가격이 확정되었습니다.
7. 구매와 구매 복원 기능이 준비되었습니다.
8. 환불 및 고객 지원 정책이 준비되었습니다.

위 조건을 충족하면 Founding 등록 종료일을 확정하고 최소 30일 전에 앱과 홈페이지를 통해 공지합니다.

권장 고지 예시는 다음과 같습니다.

> Memorize Me의 초기 무료 이용자 혜택이 20XX년 X월 X일 종료됩니다. 종료일 이전에 Founding 혜택 등록을 완료한 사용자는 향후 추가되는 유료 기능도 계속 무료로 이용할 수 있습니다.

## 4. Founding 등록 종료 방법

Founding 등록을 종료할 때는 Firestore와 Remote Config를 모두 변경해야 합니다.

### 1단계: Firestore에서 실제 등록 차단

Firestore의 다음 문서를 엽니다.

```text
system/commercialization
```

다음 필드를 `false`로 변경합니다.

```text
foundingEnrollmentOpen = false
```

Firestore 값이 실제 권한 등록 여부를 결정하는 최종 기준입니다.

### 2단계: Remote Config에서 앱 표시 변경

Remote Config에서 다음 값을 변경하고 게시합니다.

```text
founding_program_open = false
```

Remote Config 값은 안내 문구와 화면 표시를 제어합니다. Remote Config만 변경해서는 실제 Founding 등록을 안전하게 차단할 수 없습니다.

## 5. Firebase Authentication 설정

Firebase Console에서 다음 인증 제공자를 활성화해야 합니다.

```text
빌드 → Authentication → Sign-in method
```

활성화할 제공자는 다음과 같습니다.

- 익명 인증
- Google 인증

### 익명 인증의 역할

사용자가 Google 로그인을 하지 않아도 앱을 처음 실행한 기기를 Firebase 사용자로 등록하고 Founding 혜택을 먼저 기록합니다.

### Google 인증의 역할

사용자가 Google Sheets를 사용하기 위해 Google 로그인하면 기존 익명 Firebase 사용자와 Google 계정을 연결합니다. 연결이 완료되면 Founding 혜택을 계정 기준으로 복원할 수 있습니다.

Google 계정에 연결하지 않은 상태에서 앱을 삭제하거나 기기를 변경하면 익명 사용자 ID를 복원하지 못할 수 있습니다. 따라서 Founding 등록 기간이 종료되기 전에 Google 계정을 연결하도록 안내하는 것이 좋습니다.

## 6. Cloud Firestore 설정

### 데이터베이스 생성

Firebase Console에서 Cloud Firestore 데이터베이스를 생성합니다.

### 운영 설정 문서 생성

다음 경로에 문서를 생성합니다.

```text
컬렉션: system
문서 ID: commercialization
```

다음 Boolean 필드를 추가합니다.

```text
foundingEnrollmentOpen = true
```

### 보안 규칙 배포

프로젝트 루트에서 다음 명령을 실행합니다.

```powershell
firebase.cmd deploy --only firestore:rules
```

앱 사용자는 자신의 권한 문서만 읽을 수 있습니다. Founding 등록이 열려 있을 때에만 자신의 초기 Founding 권한 문서를 생성할 수 있습니다.

유료 `Pro` 권한은 앱에서 직접 기록하면 안 됩니다. 향후 Google Play 구매를 검증하는 신뢰할 수 있는 결제 서버 또는 Firebase 관리자 환경에서만 기록해야 합니다.

## 7. 권한 데이터 구조

사용자의 권한은 다음 경로에 저장됩니다.

```text
entitlements/{firebaseUserId}
```

Founding 사용자 문서 예시는 다음과 같습니다.

```text
plan = founding
foundingMember = true
claimedAt = 서버 등록 시간
source = launch_founding_program
schemaVersion = 1
```

`claimedAt`은 사용자의 기기 시간이 아니라 Firestore 서버 시간을 사용합니다.

## 8. Firebase Analytics 설정

Firebase 프로젝트에서 Google Analytics를 활성화해야 합니다.

앱은 다음 정보를 분석 이벤트로 기록합니다.

- 사용한 기능 종류
- 학습 방식
- 처리한 단어 또는 문제 개수
- AI 생성 시작과 완료 여부
- 내보내기 형식
- 메인 탭 사용 흐름
- Founding 등록 완료 여부

다음 정보는 Analytics에 전송하지 않습니다.

- 단어와 뜻
- 단어장 이름
- CSV 파일명
- Google Sheets 파일명
- AI 프롬프트
- 사용자 API 키
- Google 계정 이메일과 이름

### 등록된 주요 이벤트

```text
onboarding_completed
founding_registration_completed
wordbook_import_completed
study_session_started
study_session_completed
quiz_completed
ai_generation_started
ai_generation_completed
study_material_exported
main_tab_viewed
```

Analytics 데이터는 Founding 종료 시점을 판단하고 어떤 기능을 유료 기능으로 발전시킬지 결정하는 데 사용합니다.

## 9. Firebase Remote Config 설정

Remote Config는 앱을 다시 빌드하거나 Google Play 업데이트를 배포하지 않고도 운영 설정을 변경하기 위해 사용합니다.

Firebase Console의 Remote Config에서 다음 파라미터를 생성합니다.

| 파라미터 | 출시 초기 값 | 역할 |
| --- | --- | --- |
| `monetization_mode` | `launch_free` | 전체 무료 또는 유료 운영 모드 |
| `enable_banner_ads` | `false` | 배너 광고 표시 여부 |
| `enable_interstitial_ads` | `false` | 전면 광고 표시 여부 |
| `enable_paywall` | `false` | 유료 안내 화면 표시 여부 |
| `founding_program_open` | `true` | Founding 모집 안내 표시 여부 |
| `show_launch_notice` | `true` | 무료 출시 안내 표시 여부 |
| `launch_notice_version` | `1` | 안내문 재표시 버전 |
| `launch_notice_title` | `출시 초기 모든 기능 무료` | 안내 제목 |
| `launch_notice_message` | 앱의 무료 출시 안내 문구 | 안내 본문 |
| `free_wordbook_limit` | `-1` | 무료 단어장 제한, `-1`은 무제한 |
| `free_pdf_export_limit` | `-1` | 무료 PDF 제한, `-1`은 무제한 |
| `ai_beta_enabled` | `true` | AI 베타 기능 활성화 여부 |

무료 출시 안내 문구를 수정하고 사용자에게 다시 보여주려면 `launch_notice_version` 값을 증가시킵니다.

예를 들어 기존 값이 `1`이면 다음 게시에서 `2`로 변경합니다.

## 10. Remote Config에 저장하면 안 되는 정보

Remote Config는 보안 저장소가 아닙니다. 사용자가 앱 내부의 Remote Config 값을 확인하거나 변조할 수 있다고 전제해야 합니다.

다음 정보는 절대 Remote Config에 저장하지 않습니다.

- 사용자 API 키
- Google OAuth 비밀키
- 결제 영수증
- 특정 사용자의 Pro 여부
- Founding 사용자 명단
- 서버 관리자 키
- 결제 검증 결과

사용자의 실제 `Pro` 및 `Founding` 권한은 Firestore와 향후 결제 서버에서 관리합니다.

## 11. 유료 전환 절차

유료 기능을 출시할 준비가 완료되면 다음 순서로 진행합니다.

1. 초기 사용자 중 Founding 서버 등록이 누락된 사용자가 없는지 확인합니다.
2. 종료일을 최소 30일 전에 공지합니다.
3. Firestore의 `foundingEnrollmentOpen`을 `false`로 변경합니다.
4. Remote Config의 `founding_program_open`을 `false`로 변경합니다.
5. Google Play 결제와 구매 복원 기능을 배포합니다.
6. 실제 결제가 정상적으로 검증되는지 확인합니다.
7. Remote Config의 `monetization_mode`를 `freemium`으로 변경합니다.
8. 결제 화면을 사용할 준비가 된 후에만 `enable_paywall`을 `true`로 변경합니다.

결제 시스템이 준비되지 않았거나 Google Play 심사 중이라면 `enable_paywall`은 계속 `false`로 유지합니다.

## 12. 광고 도입 절차

초기에는 광고를 사용하지 않습니다.

향후 광고를 도입할 경우 다음 사항을 먼저 준비합니다.

- AdMob SDK와 광고 단위 등록
- 테스트 광고와 운영 광고 ID 분리
- 개인정보 동의 화면
- Play Console 데이터 보안 항목 수정
- 광고 포함 여부 신고
- 광고 빈도 제한
- 광고 제거 Pro 상품

광고 SDK가 앱에 준비되지 않은 상태에서 Remote Config의 광고 값을 `true`로 변경해도 광고가 표시되지는 않습니다. 해당 값은 향후 광고 기능을 구현한 뒤 사용합니다.

## 13. 출시 전 확인 목록

- [ ] Firebase Authentication에서 익명 인증 활성화
- [ ] Firebase Authentication에서 Google 인증 활성화
- [ ] Cloud Firestore 데이터베이스 생성
- [ ] `system/commercialization` 문서 생성
- [ ] `foundingEnrollmentOpen = true` 설정
- [ ] `firestore.rules` 배포
- [ ] Google Analytics 활성화
- [ ] Remote Config 파라미터 생성 및 게시
- [ ] 앱 설정에서 `Founding 혜택 등록 완료` 표시 확인
- [ ] Google 로그인 후에도 Founding 상태 유지 확인
- [ ] 앱 재실행 후 Founding 상태 복원 확인
- [ ] 무료 출시 안내 문구 확인
- [ ] 광고와 Paywall이 표시되지 않는지 확인

## 14. 관련 코드

주요 구현 파일은 다음과 같습니다.

```text
lib/models/app_entitlement.dart
lib/providers/entitlement_provider.dart
lib/services/analytics_service.dart
lib/services/app_config_service.dart
lib/widgets/launch_notice_gate.dart
firestore.rules
```

현재 구조는 무료 출시를 안전하게 유지하면서, 추후 결제 SDK와 결제 검증 서버를 연결할 수 있도록 준비한 기반입니다.
