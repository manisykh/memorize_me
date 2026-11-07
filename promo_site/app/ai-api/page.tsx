import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "AI API 연결 가이드 | Memorize Me",
  description:
    "무료 API 또는 보유한 API 키를 Memorize Me에 연결하는 3단계 사용 가이드입니다.",
};

const setupSteps = [
  {
    number: "1",
    label: "제공업체 선택",
    title: "무료로 시작하거나, 보유한 키를 선택합니다",
    body: "처음이라면 ‘무료 API로 시작’을 권장합니다. 이미 결제·발급한 키가 있다면 ‘보유한 API 키 연결’을 선택하세요.",
  },
  {
    number: "2",
    label: "API 키 연결",
    title: "발급 주소를 확인하고 키를 붙여넣습니다",
    body: "앱이 보여주는 발급 순서를 따라 키를 만든 뒤 입력합니다. API 키는 구독 계정 비밀번호와 다르며, 앞뒤 공백 없이 붙여넣어야 합니다.",
  },
  {
    number: "3",
    label: "연결 확인",
    title: "짧은 테스트 요청으로 실제 작동을 확인합니다",
    body: "모델과 키가 정상일 때만 등록을 마칩니다. 실패하면 이전 단계로 돌아가 제공업체·모델·키를 바로 수정할 수 있습니다.",
  },
];

const quickChecks = [
  ["401 · 인증 실패", "키가 잘못되었거나 폐기되었습니다. 새 키인지 확인하세요."],
  ["404 · 모델 없음", "선택한 모델이 현재 제공업체에서 지원되는지 확인하세요."],
  ["429 · 요청 제한", "무료 한도 또는 분당 요청 수를 초과했습니다. 잠시 후 다시 시도하세요."],
  ["시간 초과", "무료 모델이 혼잡할 수 있습니다. 다시 시도하거나 다른 등록 모델로 변경하세요."],
];

export default function AiApiGuidePage() {
  return (
    <main className="manual-page api-guide-page" id="api-top">
      <header className="manual-topbar">
        <a className="brand" href="/" aria-label="Memorize Me 제품 소개로 이동">
          <img className="brand-app-icon" src="/app-icon.png" alt="" aria-hidden="true" />
          <span>Memorize Me</span>
        </a>
        <nav aria-label="AI API 가이드 메뉴">
          <a href="/">제품 소개</a>
          <a href="/manual">전체 사용 가이드</a>
          <a className="manual-nav-current" href="#api-steps">AI API 연결</a>
        </nav>
      </header>

      <section className="api-hero">
        <div className="api-hero-copy">
          <p className="eyebrow">AI SETUP · BEGINNER GUIDE</p>
          <h1>내 API로<br /><em>AI 학습을 더해요.</em></h1>
          <p>
            Memorize Me가 AI 사용료를 대신 청구하지 않습니다. 사용자가 직접 발급한
            무료 API 또는 보유한 API 키를 기기에 연결해 예문·퀴즈·문법 문제를 만듭니다.
          </p>
          <div className="api-hero-actions">
            <a className="button button-primary" href="#api-steps">3단계로 연결하기 <span>↓</span></a>
            <a className="api-text-link" href="#api-errors">오류부터 해결하기</a>
            <a className="api-text-link" href="/downloads/memorize-me-ai-api-guide.jpg" download>JPEG 안내 이미지 받기</a>
          </div>
          <div className="api-security-note">
            <strong>API 키는 기기의 보안 저장소에 보관</strong>
            <span>생성 요청은 선택한 AI 제공업체로 직접 전송됩니다.</span>
          </div>
        </div>
        <figure className="api-hero-screen">
          <img src="/media/latest/ai-settings.png" alt="Memorize Me의 최신 AI 모델과 API 설정 화면" />
          <figcaption>실제 최신 화면 · 무료 AI 추가, 보유 키 추가, 자동 대체</figcaption>
        </figure>
      </section>

      <section className="api-route-section" aria-labelledby="route-title">
        <div className="api-section-heading">
          <p className="eyebrow">CHOOSE YOUR ROUTE</p>
          <h2 id="route-title">나는 어디서 시작하면 될까요?</h2>
          <p>두 경로 모두 같은 3단계를 사용합니다. 키를 가지고 있는지만 판단하면 됩니다.</p>
        </div>
        <div className="api-route-grid">
          <article className="api-route-card api-route-recommended">
            <span className="api-route-badge">처음이라면 추천</span>
            <h3>무료 API로 시작</h3>
            <p>Gemini, Groq, Mistral, OpenRouter 등 앱이 안내하는 무료 플랜·무료 모델 중 하나를 선택합니다.</p>
            <ol>
              <li>제공업체 계정 만들기</li>
              <li>API 키 발급</li>
              <li>앱에서 연결 확인</li>
            </ol>
          </article>
          <article className="api-route-card">
            <span className="api-route-badge">이미 키가 있다면</span>
            <h3>보유한 API 키 연결</h3>
            <p>OpenAI, Claude, DeepSeek 등 이미 발급받았거나 결제 한도를 설정한 키를 연결합니다.</p>
            <ol>
              <li>제공업체와 모델 선택</li>
              <li>보유 키 붙여넣기</li>
              <li>앱에서 연결 확인</li>
            </ol>
          </article>
        </div>
        <p className="api-policy-note">
          무료 제공 범위, 모델, 요청 한도와 결제수단 요구 여부는 제공업체 정책에 따라 바뀔 수 있습니다.
          연결 직전 앱에 표시되는 최신 안내를 확인하세요.
        </p>
      </section>

      <section className="api-steps-section" id="api-steps">
        <div className="api-section-heading api-section-heading-light">
          <p className="eyebrow">THREE STEPS</p>
          <h2>화면 위 숫자만 따라가세요</h2>
          <p>각 단계에서 이전 버튼으로 되돌아가 수정할 수 있고, 닫기를 누르면 설정을 확정하지 않고 나갈 수 있습니다.</p>
        </div>

        <div className="api-progress-demo" aria-label="제공업체 선택, API 키 연결, 연결 확인의 세 단계">
          {setupSteps.map((step, index) => (
            <div className="api-progress-item" key={step.number}>
              <span className="api-progress-number">{step.number}</span>
              <span>{step.label}</span>
              {index < setupSteps.length - 1 && <i aria-hidden="true" />}
            </div>
          ))}
        </div>

        <div className="api-step-list">
          {setupSteps.map((step) => (
            <article className="api-step-card" key={step.number}>
              <div className="api-step-index">{step.number}</div>
              <div>
                <p>{step.label}</p>
                <h3>{step.title}</h3>
                <span>{step.body}</span>
              </div>
            </article>
          ))}
        </div>

        <div className="manual-gallery manual-gallery-two api-current-screens">
          <figure className="manual-figure">
            <div className="manual-image-wrap"><img src="/media/latest/ai-provider-step1.png" alt="최신 무료 API 제공업체 선택 화면" /></div>
            <figcaption>1단계 · 제공업체 선택</figcaption>
          </figure>
          <figure className="manual-figure">
            <div className="manual-image-wrap"><img src="/media/latest/ai-provider-step2.png" alt="최신 Google Gemini API 키 연결 화면" /></div>
            <figcaption>2단계 · 발급 안내와 API 키 연결</figcaption>
          </figure>
        </div>

        <div className="api-real-screen-grid">
          <figure className="api-real-screen">
            <img src="/media/latest/ai-learning.png" alt="최신 AI 학습 탭의 실제 화면" />
            <figcaption><span>01</span> AI 학습 탭에서 설정 관리로 이동</figcaption>
          </figure>
          <div className="api-callout-panel">
            <p className="eyebrow">AFTER CONNECTING</p>
            <h3>연결되면 등록된 AI가 카드로 나타납니다</h3>
            <ul>
              <li><strong>가장 위 카드</strong>가 주 모델입니다.</li>
              <li><strong>자동 대체</strong>를 켜면 아래 모델을 순서대로 시도합니다.</li>
              <li><strong>연결 테스트</strong>로 각 카드 또는 전체 모델을 다시 확인할 수 있습니다.</li>
              <li>모델 변경에서는 현재 키로 사용할 수 있는 후보를 확인합니다.</li>
            </ul>
            <a href="/manual#ai-guide">AI 문제 생성까지 이어서 보기 <span>→</span></a>
          </div>
        </div>
      </section>

      <section className="api-errors-section" id="api-errors">
        <div className="api-section-heading">
          <p className="eyebrow">QUICK FIX</p>
          <h2>연결이 안 될 때는 오류 종류부터 봅니다</h2>
        </div>
        <div className="api-error-grid">
          {quickChecks.map(([title, body]) => (
            <article key={title}>
              <h3>{title}</h3>
              <p>{body}</p>
            </article>
          ))}
        </div>
        <div className="api-safety-box">
          <div><strong>키를 문의 글에 붙이지 마세요</strong><p>전체 API 키, 비밀번호, 결제 정보는 고객지원이나 화면 캡처에 포함하지 않습니다.</p></div>
          <div><strong>무료 모델은 느릴 수 있어요</strong><p>응답 지연, 시간 초과, 토큰·분당·일일 요청 한도는 앱 오류가 아닐 수 있습니다.</p></div>
          <div><strong>생성 결과를 확인하세요</strong><p>AI가 만든 문제·정답·해설은 베타 기능이며 학습 전에 직접 검토해야 합니다.</p></div>
        </div>
      </section>

      <section className="api-end-section">
        <div>
          <p>연결 준비가 끝났습니다.</p>
          <h2>API를 연결하고<br />내 단어장으로 문제를 만드세요.</h2>
        </div>
        <div>
          <a className="button button-light" href="#api-top">처음부터 다시 보기 <span>↑</span></a>
          <a className="api-end-link" href="/manual">전체 사용 가이드 보기</a>
        </div>
      </section>
    </main>
  );
}
