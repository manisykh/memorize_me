const features = [
  {
    number: "01",
    title: "시트가 바로 단어장이 됩니다",
    body: "Google Drive에서 필요한 스프레드시트만 고르고, 학습할 시트를 선택하세요. 익숙한 자료를 다시 옮겨 적을 필요가 없습니다.",
    image: "/media/app-import.jpg",
    art: "/media/onboarding-sheet.png",
    alt: "Google 시트에서 단어장을 가져오는 Memorize Me 화면",
  },
  {
    number: "02",
    title: "기억은 여러 방식으로 확인합니다",
    body: "플래시카드로 뜻을 떠올리고, 객관식과 스펠링 퀴즈로 기억을 꺼내 봅니다. 같은 단어도 다른 각도에서 반복됩니다.",
    image: "/media/app-flashcard.jpg",
    art: "/media/onboarding-flashcard.png",
    alt: "Memorize Me 플래시카드 학습 화면",
  },
  {
    number: "03",
    title: "복습할 때를 앱이 기억합니다",
    body: "오늘 볼 단어와 새로 시작할 단어를 나누고, SRS 흐름에 맞춰 필요한 복습을 먼저 보여줍니다.",
    image: "/media/app-stats.png",
    art: "/media/onboarding-srs.png",
    alt: "Memorize Me 암기율과 SRS 학습 통계 화면",
  },
];

const studyModes = [
  ["플래시카드", "뜻과 예문을 앞뒤로 확인하며 기억 단계를 올립니다."],
  ["객관식 퀴즈", "비슷한 선택지 사이에서 정확한 의미를 구분합니다."],
  ["주관식·스펠링", "정답을 직접 꺼내 쓰며 기억을 단단하게 만듭니다."],
  ["시험지 내보내기", "생성한 문제를 PDF와 HTML로 정리해 활용합니다."],
];

export default function Home() {
  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="Memorize Me 처음으로">
          <span className="brand-mark" aria-hidden="true">
            <span />
          </span>
          <span>Memorize Me</span>
        </a>
        <nav aria-label="주요 메뉴">
          <a href="#flow">학습 흐름</a>
          <a href="#ai">AI 학습</a>
          <a href="/manual">사용 가이드</a>
          <a className="nav-cta" href="#start">시작하기</a>
        </nav>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <p className="eyebrow">YOUR WORDS, A BETTER ROUTINE</p>
          <h1>
            적어둔 단어를
            <br />
            <em>기억하는 단어</em>로.
          </h1>
          <p className="hero-description">
            Google 시트에서 시작해 플래시카드, 퀴즈, 복습, AI 시험지까지.
            Memorize Me가 흩어진 단어를 매일의 학습 흐름으로 바꿉니다.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="#flow">
              학습 흐름 보기 <span aria-hidden="true">→</span>
            </a>
            <a className="text-link" href="#modes">
              학습 기능 살펴보기
            </a>
          </div>
          <div className="hero-note">
            <strong>오늘 볼 것만 선명하게</strong>
            <span>시트 선택 · 반복 학습 · 암기율 기록</span>
          </div>
        </div>

        <div className="hero-gallery" aria-label="Memorize Me 앱 화면 미리보기">
          <figure className="hero-art">
            <img
              src="/media/onboarding-start.png"
              alt="색연필로 그린 Memorize Me 학습 장면"
            />
          </figure>
          <figure className="phone-shot phone-shot-main">
            <img src="/media/app-home.png" alt="Memorize Me 오늘 학습 홈 화면" />
          </figure>
          <figure className="phone-shot phone-shot-side">
            <img src="/media/app-quiz.jpg" alt="Memorize Me 객관식 퀴즈 화면" />
          </figure>
          <span className="pencil-caption">매일 조금씩, 오래 남도록</span>
        </div>
      </section>

      <section className="statement" aria-label="제품 소개">
        <p>단어를 모으는 앱은 많습니다.</p>
        <h2>Memorize Me는 그 단어를 다시 만나게 합니다.</h2>
      </section>

      <section className="flow-section" id="flow">
        <div className="section-heading">
          <p className="eyebrow">FROM SHEET TO MEMORY</p>
          <h2>한 번 가져오고, 매일 이어가는 학습</h2>
          <p>
            자료를 준비하는 시간보다 실제로 떠올리고 확인하는 시간에 집중하도록
            설계했습니다.
          </p>
        </div>

        <div className="feature-list">
          {features.map((feature, index) => (
            <article className="feature" key={feature.number}>
              <div className="feature-copy">
                <span className="feature-number">{feature.number}</span>
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
                <span className="feature-tag">
                  {index === 0
                    ? "Google Sheets"
                    : index === 1
                      ? "Active recall"
                      : "Spaced repetition"}
                </span>
              </div>
              <div className="feature-visual">
                <img className="feature-art" src={feature.art} alt="" aria-hidden="true" />
                <figure className="screen-frame">
                  <img src={feature.image} alt={feature.alt} />
                </figure>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="modes-section" id="modes">
        <div className="modes-art">
          <img
            src="/media/onboarding-quiz.png"
            alt="색연필로 표현한 다양한 단어 퀴즈 학습 장면"
          />
          <span>보고, 고르고, 직접 쓰기</span>
        </div>
        <div className="modes-content">
          <p className="eyebrow">FOUR WAYS TO REMEMBER</p>
          <h2>외우는 방식은 하나가 아니니까</h2>
          <div className="mode-list">
            {studyModes.map(([title, body], index) => (
              <article key={title}>
                <span>{String(index + 1).padStart(2, "0")}</span>
                <div>
                  <h3>{title}</h3>
                  <p>{body}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section className="ai-section" id="ai">
        <div className="ai-intro">
          <p className="eyebrow">AI, WHERE IT HELPS</p>
          <h2>내 단어장으로 만드는<br />나만의 문제</h2>
          <p>
            선택한 단어와 난이도에 맞춰 객관식, 문법, 독해 문제를 생성합니다.
            완성된 문제는 화면에서 풀거나 시험지로 내보낼 수 있습니다.
          </p>
          <div className="ai-points">
            <span>문제 수·난이도 설정</span>
            <span>해설 포함 선택</span>
            <span>PDF·HTML 내보내기</span>
          </div>
        </div>
        <div className="ai-collage">
          <figure className="ai-art">
            <img src="/media/onboarding-ai.png" alt="색연필로 그린 AI 문제 생성 장면" />
          </figure>
          <figure className="ai-screen ai-screen-setup">
            <img src="/media/app-ai-setup.jpg" alt="AI 퀴즈 옵션 설정 화면" />
          </figure>
          <figure className="ai-screen ai-screen-result">
            <img src="/media/app-ai-result.jpg" alt="AI가 생성한 퀴즈 화면" />
          </figure>
          <figure className="ai-screen ai-screen-pdf">
            <img src="/media/app-pdf.jpg" alt="AI 퀴즈 PDF 내보내기 화면" />
          </figure>
        </div>
      </section>

      <section className="quote-section">
        <img src="/media/onboarding-flashcard.png" alt="색연필로 그린 플래시카드 학습 장면" />
        <blockquote>
          <span>“</span>
          자료는 이미 충분합니다.
          <br />
          이제 기억에 남게 공부하세요.
        </blockquote>
      </section>

      <section className="start-section" id="start">
        <div>
          <p className="eyebrow">START WITH YOUR WORDS</p>
          <h2>내가 만든 시트에서<br />오늘의 학습을 시작하세요.</h2>
          <p>
            익숙한 단어장을 그대로 가져오고, 필요한 만큼 학습하고, 기억의 변화를
            확인하세요.
          </p>
        </div>
        <a className="button button-light" href="#top">
          Memorize Me 둘러보기 <span aria-hidden="true">↑</span>
        </a>
      </section>

      <footer>
        <div className="brand footer-brand">
          <span className="brand-mark" aria-hidden="true"><span /></span>
          <span>Memorize Me</span>
        </div>
        <p>Google Sheet에서 시작하는 단어 학습 루틴</p>
        <p className="copyright">© 2026 Memorize Me</p>
      </footer>
    </main>
  );
}
