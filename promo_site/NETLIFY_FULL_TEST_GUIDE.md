# Memorize Me Netlify 전체 기능 테스트

이 폴더를 Git 저장소로 연결하면 홈페이지, 사용자 가이드, 정책 페이지와
테스터 게시판 API가 함께 배포됩니다. 게시판 테스트에는 단일 HTML 파일의
드래그 배포가 아니라 Git 저장소 연결 배포가 필요합니다.

## 1. Netlify 프로젝트 만들기

1. Netlify에서 **Add new project > Import an existing project**를 선택합니다.
2. 이 `promo_site` 소스가 들어 있는 Git 저장소를 연결합니다.
3. 저장소 루트가 이 폴더라면 `netlify.toml`이 아래 설정을 자동 적용합니다.

- Build command: `npm run build:netlify`
- Publish directory: `out`
- Functions directory: `netlify/functions`
- Node.js: `24`

상위 Flutter 저장소를 연결하는 경우에는 저장소 루트의 `netlify.toml`에 따라
Base directory가 `promo_site`로 자동 설정됩니다.

## 2. 필수 환경변수

Netlify의 **Project configuration > Environment variables**에서 다음 값을
등록합니다. 실제 비밀번호와 비밀값은 Git에 올리지 마세요.

```text
NEXT_PUBLIC_SUPPORT_EMAIL=실제_고객지원_이메일
FEEDBACK_ADMIN_PASSWORD=게시판_관리자_비밀번호_10자_이상
FEEDBACK_SESSION_SECRET=무작위_문자열_32자_이상
```

첫 배포 뒤 발급된 주소를 등록하고 다시 배포합니다.

```text
NEXT_PUBLIC_SITE_URL=https://발급주소.netlify.app
```

## 3. 배포 후 확인 주소

```text
https://발급주소.netlify.app/
https://발급주소.netlify.app/manual/
https://발급주소.netlify.app/ai-api/
https://발급주소.netlify.app/feedback/
https://발급주소.netlify.app/privacy/
https://발급주소.netlify.app/account-deletion/
https://발급주소.netlify.app/api/feedback
```

`/api/feedback`에는 오류 페이지가 아니라 `posts` 배열이 포함된 JSON이
표시되어야 합니다.

## 4. 게시판 기능 검증

1. 시크릿 창에서 닉네임과 글 비밀번호로 새 글을 등록합니다.
2. 새로고침 후 글이 남아 있는지 확인합니다.
3. 글 비밀번호로 제목과 내용을 수정합니다.
4. 공감을 누른 뒤 동일 브라우저의 중복 공감이 차단되는지 확인합니다.
5. 관리자 비밀번호로 로그인합니다.
6. 상태를 `확인 중` 또는 `반영 예정`으로 바꿉니다.
7. 운영자 답글을 등록합니다.
8. 로그아웃한 뒤 답글과 상태가 공개 화면에 보이는지 확인합니다.
9. 다른 브라우저나 휴대폰에서도 같은 글이 보이는지 확인합니다.
10. 테스트 글을 삭제하고 새로고침 후 사라졌는지 확인합니다.

저장된 게시물은 Netlify의 **Data & Storage > Blobs > memorize-feedback**에서
확인할 수 있습니다.

## 주의 사항

- 기존 Cloudflare D1 게시판 데이터는 Netlify Blobs로 자동 이전되지 않습니다.
- Netlify 게시판은 처음에는 빈 상태로 시작합니다.
- 현재 저장 방식은 테스터 규모에 적합합니다. 동시 사용자가 크게 늘어나는
  정식 서비스 단계에서는 관계형 데이터베이스 전환을 검토해야 합니다.
