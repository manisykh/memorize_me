import type { Metadata } from "next";
import "../legal.css";

export const metadata: Metadata = {
  title: "개인정보 처리방침 | Memorize Me",
  description: "Memorize Me의 데이터 수집, 이용, 보관과 삭제 방법을 안내합니다.",
};

export default function PrivacyPage() {
  return (
    <main className="legal-page">
      <header className="legal-header">
        <a href="/">Memorize Me</a>
        <a href="/account-deletion">계정 삭제 안내</a>
      </header>
      <article className="legal-content">
        <p className="legal-kicker">PRIVACY</p>
        <h1>개인정보 처리방침</h1>
        <p className="legal-updated">시행일: 2026년 10월 18일</p>

        <div className="legal-summary">
          Memorize Me는 단어장과 학습 기록을 기본적으로 사용자의 기기에
          저장합니다. 외부 서비스 연결은 사용자가 직접 선택한 기능을
          제공하기 위해서만 사용합니다.
        </div>

        <section className="legal-section">
          <h2>1. 처리하는 정보</h2>
          <ul>
            <li><strong>로컬 학습 데이터:</strong> 단어장, 단어, 예문, 학습 기록, 기억 단계와 설정</li>
            <li><strong>Google 연결 정보:</strong> 로그인 계정 식별 정보와 사용자가 선택한 파일에 접근하기 위한 Google Drive 권한</li>
            <li><strong>AI 사용 정보:</strong> 사용자가 AI 기능을 실행할 때 선택한 제공업체로 전송되는 프롬프트, 단어, 예문과 생성 설정</li>
            <li><strong>앱 품질 정보:</strong> 앱 사용 이벤트, 오류 및 충돌 진단 정보, 앱 설정 배포 정보</li>
          </ul>
        </section>

        <section className="legal-section">
          <h2>2. 사용 목적과 제3자 서비스</h2>
          <p>
            Google 로그인·Drive, Firebase Authentication·Firestore·Analytics·
            Crashlytics·Remote Config, 그리고 사용자가 직접 연결한 AI
            제공업체가 사용될 수 있습니다. AI 프롬프트와 응답에는 해당
            제공업체의 약관과 개인정보 처리방침이 적용됩니다.
          </p>
        </section>

        <section className="legal-section">
          <h2>3. API 키 보관</h2>
          <p>
            AI API 키는 Android의 보안 저장소를 이용해 현재 기기에 보관되며,
            선택한 AI 제공업체에 요청을 인증하는 목적 외에 Memorize Me가
            별도로 수집하지 않습니다.
          </p>
        </section>

        <section className="legal-section">
          <h2>4. 보관과 삭제</h2>
          <p>
            로컬 학습 데이터는 사용자가 삭제하거나 앱 데이터를 제거할 때까지
            기기에 보관됩니다. 클라우드 계정 정보는 앱의 삭제 기능 또는
            계정 삭제 요청을 통해 제거할 수 있습니다.
          </p>
          <a className="legal-action" href="/account-deletion">계정 삭제 방법 보기</a>
        </section>
      </article>
    </main>
  );
}
