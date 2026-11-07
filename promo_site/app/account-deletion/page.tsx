import type { Metadata } from "next";
import "../legal.css";

export const metadata: Metadata = {
  title: "계정 삭제 | Memorize Me",
  description: "Memorize Me 계정과 연결 데이터를 삭제하는 방법을 안내합니다.",
};

export default function AccountDeletionPage() {
  const supportEmail = process.env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim();

  return (
    <main className="legal-page">
      <header className="legal-header">
        <a href="/">Memorize Me</a>
        <a href="/privacy">개인정보 처리방침</a>
      </header>
      <article className="legal-content">
        <p className="legal-kicker">ACCOUNT DELETION</p>
        <h1>계정 삭제 요청</h1>
        <p className="legal-updated">최종 업데이트: 2026년 10월 18일</p>

        <div className="legal-summary">
          앱에서 계정 삭제를 즉시 요청할 수 있습니다. 앱에 접근할 수 없다면
          아래 외부 요청 방법을 이용하세요.
        </div>

        <section className="legal-section">
          <h2>1. 앱에서 삭제</h2>
          <ol>
            <li>Memorize Me에서 <strong>설정</strong> 탭을 엽니다.</li>
            <li><strong>계정과 Google 시트</strong>를 엽니다.</li>
            <li><strong>계정 및 초기 사용자 혜택 삭제</strong>를 누릅니다.</li>
            <li>삭제 범위를 확인한 뒤 요청을 확정합니다.</li>
          </ol>
        </section>

        <section className="legal-section">
          <h2>2. 앱 없이 삭제 요청</h2>
          {supportEmail ? (
            <>
              <p>
                등록한 Google 계정의 이메일 주소에서 아래 지원 주소로
                “Memorize Me 계정 삭제 요청”을 보내세요. 계정 확인에 필요한
                최소 정보만 요청하며, API 키나 비밀번호를 보내지 마세요.
              </p>
              <a
                className="legal-action"
                href={`mailto:${supportEmail}?subject=${encodeURIComponent("Memorize Me 계정 삭제 요청")}`}
              >
                {supportEmail}로 삭제 요청
              </a>
            </>
          ) : (
            <p className="legal-note">
              현재 외부 삭제 요청 연락처를 준비 중입니다. 배포 전에
              NEXT_PUBLIC_SUPPORT_EMAIL을 설정하여 이 화면에 지원 메일 버튼이
              표시되는지 확인해야 합니다.
            </p>
          )}
        </section>

        <section className="legal-section">
          <h2>3. 삭제되는 데이터</h2>
          <ul>
            <li>Firebase 인증 계정과 클라우드 계정 연결 정보</li>
            <li>초기 사용자 혜택 및 관련 등록 정보</li>
            <li>최근 Google 시트 연결 기록</li>
          </ul>
          <p className="legal-note">
            기기에만 저장된 단어장, 학습 기록과 API 키는 클라우드 계정 삭제와
            별개입니다. 이 데이터는 Android 설정에서 앱 데이터를 삭제하거나 앱을
            삭제해 제거할 수 있습니다.
          </p>
        </section>
      </article>
    </main>
  );
}
