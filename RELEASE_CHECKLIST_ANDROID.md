# Memorize Me Android 출시 체크리스트

이 문서는 Android 첫 출시 기준이다. iOS 작업은 이번 범위에 포함하지 않는다.

## P0 — 업로드 전에 반드시 완료

### 구현 완료

- 릴리스 서명 정보가 없거나 비어 있으면 빌드가 즉시 실패한다.
- `android/key.properties`와 keystore는 Git에서 제외된다.
- 개인정보 처리방침과 계정 삭제 안내를 앱 설정에서 확인할 수 있다.
- 공개 웹용 `/privacy/`, `/account-deletion/` 페이지가 준비되어 있다.
- Android 앱은 빌드 시 전달된 공개 정책 URL을 외부 브라우저로 연다.
- Flutter 동기 오류와 비동기 치명 오류를 Firebase Crashlytics에 기록한다.
- Android 백업을 비활성화하여 로컬 단어장과 API 키가 시스템 백업으로 복제되지 않게 했다.

### 운영자가 직접 해야 하는 일

- [ ] Netlify에 `promo_site`를 배포한다.
- [ ] `NEXT_PUBLIC_SUPPORT_EMAIL`에 실제로 수신 가능한 공개 지원 메일을 설정한다.
- [ ] 배포된 `/privacy/`, `/account-deletion/`을 시크릿 창에서 열어 HTTP 200과 메일 링크를 확인한다.
- [ ] `env/release.example.json`을 `env/release.json`으로 복사하고 실제 HTTPS 주소 2개를 입력한다.
- [ ] 최종 AAB를 `--dart-define-from-file=.\env\release.json`으로 다시 빌드한다.
- [ ] keystore와 비밀번호를 저장소 밖의 안전한 위치 두 곳 이상에 백업한다.
- [ ] Google Play Console의 개인정보 처리방침 URL과 계정 삭제 URL에 같은 공개 주소를 입력한다.
- [ ] Play Console 데이터 보안 설문을 실제 동작과 일치하게 작성한다. Firebase 진단/분석, Google 로그인·시트, 사용자가 선택한 AI 제공업체로의 전송을 포함한다.
- [ ] 내부 테스트 트랙에서 설치한 앱으로 로그인, 단어장 가져오기, 학습, 퀴즈, AI 키 저장·삭제, 계정 삭제를 확인한다.

## P1 — 출시 직전 완료 권장

### 구현 완료

- 릴리스 Android 코드에 R8 난독화와 미사용 리소스 축소를 적용했다.
- 앱의 평문 HTTP 통신을 차단하고 Custom OpenAI Compatible endpoint도 HTTPS만 허용한다.
- Netlify 빌드는 유효한 공개 지원 이메일이 없으면 실패하도록 했다.
- 사용자에게 SRS 대신 `기억 단계`, `복습 일정`, `단어별 기억 상태` 용어를 사용한다.
- AI 화면에는 개인 API 키 필요, 제3자 전송, 무료 API의 시간 초과·토큰·요청 한도 가능성을 안내한다.
- 앱 시작 오류 수집, Analytics 주요 흐름, Remote Config 기본값과 오프라인 대체 동작이 구현되어 있다.

### 운영자가 직접 해야 하는 일

- [ ] 첫 배포 버전이 `1.0.0+1`인지 확인한다. Play에 한 번이라도 올린 뒤에는 매 업로드마다 build number를 증가시킨다.
- [ ] 360×800 수준의 작은 화면과 일반 화면에서 글자 크기 100%, 130%, 150%로 주요 화면의 잘림을 확인한다.
- [ ] Android 8 이상 저사양 기기 1대와 최신 Android 기기 1대에서 콜드 스타트와 20분 이상 학습을 확인한다.
- [ ] 오프라인, 느린 네트워크, 잘못된 API 키, 무료 API 한도 초과 상태에서 앱이 종료되지 않고 복구 안내를 보여주는지 확인한다.
- [ ] Firebase Crashlytics에 테스트 비치명 오류 또는 테스트 충돌이 도착하는지 확인한다.
- [ ] 앱 아이콘, 앱 이름, 스크린샷, 짧은/자세한 설명, 콘텐츠 등급, 광고 여부, 앱 액세스 정보를 Play Console에 입력한다.
- [ ] 생성된 AAB를 Play Console 사전 출시 보고서에 올리고 호환성·접근성·보안 경고를 검토한다.
- [ ] 각 릴리스의 `build/app/outputs/mapping/release/mapping.txt`를 AAB와 함께 보관하고 Play Console의 난독화 해제 파일로 등록한다.
- [ ] 내부 테스트 → 비공개 테스트 → 단계적 프로덕션 출시 순서로 배포하고 초기에는 Crashlytics와 ANR을 매일 확인한다.

## 로컬 검증 명령

```powershell
flutter pub get
flutter analyze
flutter test

Copy-Item .\env\release.example.json .\env\release.json
# env/release.json의 URL을 실제 Netlify 주소로 수정
flutter build appbundle --release --dart-define-from-file=.\env\release.json
```

Netlify 사이트는 실제 지원 이메일을 지정한 뒤 별도로 검증한다.

```powershell
Set-Location .\promo_site
$env:NEXT_PUBLIC_SUPPORT_EMAIL='support@your-domain.example'
$env:NEXT_PUBLIC_SITE_URL='https://your-site.netlify.app'
npm ci
npm run build:netlify
```

최종 AAB 위치:

`build/app/outputs/bundle/release/app-release.aab`
