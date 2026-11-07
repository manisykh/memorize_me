export const metadata = {
  title: "Memorize Me AI API 연결 인포그래픽",
  robots: { index: false, follow: false },
};

export default function InfographicPage() {
  return (
    <main className="infographic-canvas">
      <header className="infographic-header">
        <div className="infographic-brand"><img src="/app-icon.png" alt="" /><span>Memorize Me</span></div>
        <p>AI 학습 시작 가이드</p>
        <h1>내 API 연결,<br /><em>3단계면 끝나요.</em></h1>
        <span className="infographic-subtitle">예문 · 퀴즈 · 문법 문제를 내 단어장으로 생성하세요</span>
      </header>

      <section className="infographic-choice">
        <div><span>처음이라면</span><strong>무료 API로 시작</strong></div>
        <b>또는</b>
        <div><span>이미 키가 있다면</span><strong>보유한 API 키 연결</strong></div>
      </section>

      <section className="infographic-steps">
        <article>
          <div className="infographic-step-title"><b>1</b><div><span>제공업체 선택</span><strong>목록에서 하나를 고르세요</strong></div></div>
          <figure><img src="/media/latest/ai-provider-step1.png" alt="무료 API 제공업체 선택 화면" /></figure>
          <p>처음이라면 <strong>초보 추천</strong> 표시가 있는 제공업체부터 시작하세요.</p>
        </article>
        <article>
          <div className="infographic-step-title"><b>2</b><div><span>API 키 연결</span><strong>안내대로 발급 후 붙여넣기</strong></div></div>
          <figure><img src="/media/latest/ai-provider-step2.png" alt="API 키 연결 화면" /></figure>
          <p>키는 <strong>이 기기의 보안 저장소</strong>에 저장됩니다. 비밀번호와는 달라요.</p>
        </article>
        <article>
          <div className="infographic-step-title"><b>3</b><div><span>연결 확인</span><strong>테스트가 성공하면 등록 완료</strong></div></div>
          <figure><img src="/media/latest/ai-settings.png" alt="AI 설정 화면" /></figure>
          <p>등록 후 가장 위 카드가 <strong>주 모델</strong>, 아래 카드는 자동 대체 모델입니다.</p>
        </article>
      </section>

      <section className="infographic-help">
        <div><b>401</b><span><strong>키 오류</strong>새 키인지 확인</span></div>
        <div><b>429</b><span><strong>사용량 초과</strong>잠시 후 재시도</span></div>
        <div><b>⏱</b><span><strong>시간 초과</strong>다른 모델로 변경</span></div>
      </section>

      <footer className="infographic-footer">
        <p><strong>AI 생성은 Beta</strong> · 무료 API는 응답 지연과 토큰·분당·일일 요청 제한이 있을 수 있습니다.</p>
        <span>생성된 문제와 정답은 학습 전에 꼭 확인하세요.</span>
      </footer>
      <div className="infographic-path"><span>앱에서 찾기</span><strong>AI 학습 탭 → 무료 API로 시작</strong></div>
    </main>
  );
}
