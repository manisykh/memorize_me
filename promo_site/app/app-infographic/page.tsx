export const metadata = {
  title: "Memorize Me 앱 사용 인포그래픽",
  robots: { index: false, follow: false },
};

const steps = [
  {
    number: "1",
    kicker: "단어장 준비",
    title: "내가 가진 단어를 그대로 가져와요",
    body: "Google Sheets · CSV · XLSX 중 원하는 방식으로 단어장을 만듭니다.",
    image: "/media/latest/onboarding-01.png",
    alt: "단어장 가져오기 온보딩 화면",
  },
  {
    number: "2",
    kicker: "오늘 학습",
    title: "홈에서 학습할 단어장을 골라요",
    body: "단어장을 선택하면 기본 학습과 추가 복습을 합쳐 오늘 범위를 계산합니다.",
    image: "/media/latest/home.png",
    alt: "학습 단어장을 선택하기 전 홈 화면",
  },
  {
    number: "3",
    kicker: "기억 확인",
    title: "익히고 바로 문제로 확인해요",
    body: "플래시카드 · 객관식 · 주관식 스펠링 · 시험지로 같은 단어를 다르게 확인합니다.",
    image: "/media/feature/learning-modes.png",
    alt: "플래시카드와 퀴즈를 선택하는 최신 학습 방식 화면",
  },
  {
    number: "4",
    kicker: "맞춤 복습",
    title: "앱이 다시 볼 날을 정리해요",
    body: "학습 결과에 따라 기억 단계와 다음 복습일이 달라집니다.",
    image: "/media/latest/onboarding-03.png",
    alt: "복습 일정과 기억 단계 온보딩 화면",
  },
  {
    number: "5",
    kicker: "선택 기능",
    title: "필요할 때 내 API로 AI를 더해요",
    body: "예문·뜻 보강, 퀴즈 생성, 문법 문제 생성에 직접 연결한 AI를 사용합니다.",
    image: "/media/latest/ai-learning.png",
    alt: "AI 학습 탭 화면",
  },
];

export default function AppInfographicPage() {
  return (
    <main className="app-infographic-canvas">
      <header className="app-infographic-header">
        <div className="app-infographic-brand"><img src="/app-icon.png" alt="" /><span>Memorize Me</span></div>
        <p>처음 사용하는 분을 위한 한 장 가이드</p>
        <h1>단어장부터 복습까지,<br /><em>이 순서대로 시작하세요.</em></h1>
        <div className="app-infographic-imports"><span>Google Sheets</span><span>CSV</span><span>XLSX</span></div>
      </header>

      <section className="app-infographic-timeline">
        {steps.map((step) => (
          <article key={step.number}>
            <div className="app-infographic-index">{step.number}</div>
            <figure><img src={step.image} alt={step.alt} /></figure>
            <div className="app-infographic-copy">
              <span>{step.kicker}</span>
              <h2>{step.title}</h2>
              <p>{step.body}</p>
            </div>
          </article>
        ))}
      </section>

      <section className="app-infographic-memory">
        <div><span>기억 단계</span><strong>학습할수록 복습 시점이 달라져요</strong></div>
        <ol><li>진입</li><li>학습 중</li><li>복습 예정</li><li>복습 필요</li><li>안정 기억</li></ol>
      </section>

      <footer className="app-infographic-footer">
        <div><span>앱에서 시작</span><strong>홈 → 단어장 만들기</strong></div>
        <p>설정의 <strong>가이드</strong>에서 온보딩과 사용 설명을 언제든 다시 볼 수 있습니다.</p>
      </footer>
    </main>
  );
}
