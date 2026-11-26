import type { Metadata } from "next";
import "../legal.css";
import { CopyLines } from "../copy-lines";
import { PolicyHeader } from "../policy-header";
import { getReleaseConfig, privacyNotice } from "../../lib/site-release";

export const metadata: Metadata = {
  title: "개인정보 처리방침 | Memorize Me",
  description: "Memorize Me의 데이터 수집, 이용, 보관과 삭제 방법을 안내합니다.",
};

export default function PrivacyPage() {
  const config = getReleaseConfig();
  const notice = privacyNotice(config, "tester");
  return (
    <main className="legal-page">
      <PolicyHeader current="privacy" />
      <article className="legal-content">
        <p className="legal-kicker">PRIVACY</p>
        <h1>개인정보 처리방침</h1>
        <p className="legal-updated">시행일: 2026년 10월 18일</p>

        <div className="legal-summary">
          <CopyLines lines={["단어장과 학습 기록은 기본적으로", "사용자의 기기에 저장합니다.", "외부 서비스는 사용자가 선택한 기능을", "제공하기 위해서만 연결합니다."]} />
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
        <section id="tester-data" className="legal-section">
          <h2>5. 홈페이지 테스트 신청 및 출시 알림</h2>
          {!config.privacyConfirmed ? <p>개인정보 수집·보관 기준과 문의 채널을 준비하고 있습니다. 기준이 확정되기 전에는 홈페이지에서 테스트 신청과 출시 알림 정보를 접수하지 않습니다.</p> : <>
            <p><strong>목적:</strong> {notice.purpose}. 별도로 동의한 경우 정식 출시 알림을 발송합니다.</p>
            <p><strong>항목:</strong> {notice.items}. 출시 알림만 신청하면 이메일과 수신·개인정보 동의 기록을 수집합니다. 서버에서 접수 시각, 안내문 버전과 운영 상태를 기록합니다.</p>
            <p><strong>보관·삭제:</strong> {notice.retention}</p>
            <p><strong>처리 방식:</strong> Netlify의 접근이 제한된 서버 저장소에 보관하며, 운영자가 신청 확인·테스터 등록·안내를 위해 사용합니다. 신청한 Google 계정은 Google Play 테스터 등록에 사용됩니다. 스팸 방지 식별값은 원문 IP 대신 해시로 저장하고, 유효 시간 10분이 지난 후 1시간 이내 삭제합니다.</p>
            <p>필수 동의를 거부하면 접수할 수 없습니다. 주요 사용 목적과 출시 알림 수신은 선택이며, 동의하지 않아도 테스트 신청이 가능합니다. 정보 열람·삭제 및 수신 철회는 <a href={`mailto:${config.supportEmail}`}>{config.supportEmail}</a>로 요청해 주세요. 어린이의 참여는 보호자를 통해 문의해 주세요.</p>
          </>}
        </section>
      </article>
    </main>
  );
}
