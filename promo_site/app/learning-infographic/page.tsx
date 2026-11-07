export const metadata = {
  title: "Memorize Me 학습 기능 인포그래픽",
  robots: { index: false, follow: false },
};

const basicModes = [
  ["카드", "플래시카드 학습", "단어·뜻·예문을 앞뒤로 확인"],
  ["선택", "객관식 퀴즈", "선택지에서 정확한 뜻 찾기"],
  ["입력", "스펠링 퀴즈", "힌트를 보고 철자를 직접 입력"],
];

const aiModes = [
  ["보강", "예문·뜻 보강", "단어장에 예문과 뜻을 추가"],
  ["단어", "단어 문제", "난이도와 문제 수를 선택해 생성"],
  ["문법", "문법 문제", "과정·주제·세부 주제·문제 설정"],
  ["독해", "독해 문제", "지문과 묶음 문제를 난이도별 생성"],
];

export default function LearningInfographicPage() {
  return (
    <main className="learning-infographic-canvas">
      <header className="learning-infographic-header">
        <div className="learning-infographic-brand"><img src="/app-icon.png" alt="" /><span>Memorize Me</span></div>
        <p>단어장 하나로 만드는 학습 흐름</p>
        <h1>외우고, 확인하고,<br /><em>문제와 시험지까지.</em></h1>
      </header>

      <section className="learning-wordbook-hub">
        <div className="learning-hub-icon">▤</div>
        <div><span>START</span><strong>내 단어장</strong><p>Google Sheets · CSV · XLSX</p></div>
        <b>단어장을 고르면 두 가지 학습 흐름이 열려요</b>
      </section>

      <section className="learning-branches">
        <article className="learning-branch basic">
          <header><span>기본 학습</span><h2>바로 시작할 수 있어요</h2><p>API 등록 없이 사용하는 암기·확인 기능</p></header>
          <figure><img src="/media/feature/learning-modes.png" alt="플래시카드와 퀴즈를 선택하는 최신 학습 방식 화면" /></figure>
          <div className="learning-mode-list">
            {basicModes.map(([badge, title, body]) => <div key={title}><b>{badge}</b><span><strong>{title}</strong><small>{body}</small></span></div>)}
          </div>
        </article>

        <article className="learning-branch ai">
          <header><span>AI API 연결 후</span><h2>학습 자료를 더 만들어요</h2><p>직접 등록한 AI 제공업체와 모델을 사용</p></header>
          <figure><img src="/media/latest/ai-learning.png" alt="AI 학습 탭" /></figure>
          <div className="learning-mode-list">
            {aiModes.map(([badge, title, body]) => <div key={title}><b>{badge}</b><span><strong>{title}</strong><small>{body}</small></span></div>)}
          </div>
        </article>
      </section>

      <section className="learning-output-flow">
        <header><span>문제를 만든 다음</span><h2>앱에서 풀거나, 시험지로 내보내세요</h2></header>
        <div className="learning-output-steps">
          <div><b>1</b><strong>문제 생성</strong><span>단어 · 문법 · 독해</span></div>
          <i>→</i>
          <div><b>2</b><strong>저장 · 다시 보기</strong><span>카테고리별 보관·병합</span></div>
          <i>→</i>
          <div><b>3</b><strong>시험지 내보내기</strong><span>PDF · HTML</span></div>
        </div>
        <div className="learning-output-formats"><span>앱에서 바로 풀기</span><span>PDF 시험지</span><span>HTML 문제지</span><span>정답·해설 포함 선택</span></div>
      </section>

      <footer className="learning-infographic-footer">
        <div><strong>AI 기능을 쓰려면</strong><span>AI 학습 탭 → 무료 API로 시작 또는 보유한 API 키 연결</span></div>
        <p><b>AI 생성은 Beta</b> · 무료 모델은 응답 지연, 시간 초과, 토큰·요청 한도가 있을 수 있습니다.<br />생성된 문제·정답·해설은 사용 전에 꼭 확인하세요.</p>
        <div className="learning-endline"><strong>내 단어장으로 오늘 바로 시작해보세요.</strong><span>Memorize Me</span></div>
      </footer>
    </main>
  );
}
