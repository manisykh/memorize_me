/* eslint-disable @next/next/no-html-link-for-pages */
import type { Metadata } from "next";
import { FeedbackBoard } from "./feedback-board";

export const metadata: Metadata = {
  title: "테스터 의견 게시판 | Memorize Me",
  description: "Memorize Me를 사용한 소감과 칭찬, 오류, 개선 요청과 아이디어를 회원가입 없이 남기는 게시판입니다.",
};

export default function FeedbackPage() {
  return (
    <main className="feedback-page">
      <header className="feedback-header">
        <a className="feedback-brand" href="/">
          <img src="/app-icon.png" alt="" aria-hidden="true" />
          <span>Memorize Me</span>
        </a>
        <nav aria-label="게시판 메뉴">
          <a href="/">홈으로 돌아가기</a>
        </nav>
      </header>

      <section className="feedback-hero">
        <div>
          <p className="feedback-kicker">TESTER FEEDBACK</p>
          <h1>함께 더 나은<br />Memorize Me를 만들어요.</h1>
          <p>
            사용하며 좋았던 점, 불편, 오류와 아이디어를 자유롭게 남겨 주세요.
            회원가입 없이 작성할 수 있고, 운영자가 확인 후 답변과 진행 상태를 알려드립니다.
          </p>
        </div>
        <aside>
          <strong>작성 전에 확인해 주세요</strong>
          <ul>
            <li>API 키·비밀번호·개인정보는 적지 마세요.</li>
            <li>기기와 발생 상황을 함께 적으면 확인이 빨라집니다.</li>
            <li>글 비밀번호는 수정·삭제할 때만 사용합니다.</li>
          </ul>
        </aside>
      </section>

      <FeedbackBoard />
    </main>
  );
}
