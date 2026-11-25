import type { Metadata } from "next";
import { CopyLines } from "../copy-lines";
import { ApiGuideHeader } from "./api-guide-header";
import { ApiSetupGuide } from "./api-setup-guide";

export const metadata: Metadata = {
  title: "AI API 연결 가이드 | Memorize Me",
  description:
    "무료 API 또는 보유한 API 키를 Memorize Me에 연결하는 3단계 사용 가이드입니다.",
};

const quickChecks = [
  ["401 · 인증 실패", "키가 잘못되었거나 폐기되었습니다. 새 키인지 확인하세요."],
  ["404 · 모델 없음", "선택한 모델이 현재 제공업체에서 지원되는지 확인하세요."],
  ["429 · 요청 제한", "무료 한도 또는 분당 요청 수를 초과했습니다. 잠시 후 다시 시도하세요."],
  ["시간 초과", "무료 모델이 혼잡할 수 있습니다. 다시 시도하거나 다른 등록 모델로 변경하세요."],
];

export default function AiApiGuidePage() {
  return (
    <main className="manual-page api-guide-page" id="api-top">
      <ApiGuideHeader />

      <section className="api-hero">
        <div className="api-hero-question-cloud" aria-hidden="true">
          <figure className="api-question-card api-question-card-one"><img src="/media/api-guide/ai-quiz-overview.jpg" alt="" /></figure>
          <figure className="api-question-card api-question-card-two"><img src="/media/api-guide/ai-reading.jpg" alt="" /></figure>
          <figure className="api-question-card api-question-card-three"><img src="/media/api-guide/ai-vocabulary.jpg" alt="" /></figure>
        </div>
        <div className="api-hero-copy">
          <p className="eyebrow">내 API로 확장하는 학습</p>
          <h1><CopyLines lines={["내 단어장에", <em key="api-hero-1">AI 학습을 더해요.</em>]} /></h1>
          <p><CopyLines lines={["보유한 API 키를 연결해", "예문과 맞춤 문제를 만드세요."]} /></p>
          <div className="api-security-note">
            <strong>API 키는 기기의 보안 저장소에 보관</strong>
            <span>이용 요금과 한도는 연결한 AI 제공업체 정책을 따릅니다.</span>
          </div>
        </div>
      </section>

      <section className="api-route-section" id="api-routes" aria-labelledby="route-title">
        <div className="api-section-heading">
          <p className="eyebrow">CHOOSE YOUR ROUTE</p>
          <h2 id="route-title"><CopyLines lines={["나는 어디서", "시작하면 될까요?"]} /></h2>
          <p><CopyLines lines={["두 경로 모두 같은 3단계를 사용합니다.", "키를 가지고 있는지만 확인하면 됩니다."]} /></p>
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
          <article className="api-route-card api-route-owned">
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
          <p className="eyebrow">APP SETUP GUIDE</p>
          <h2><CopyLines lines={["앱에서 연결하는", "순서만 확인하세요"]} /></h2>
          <p><CopyLines lines={["설정 화면을 여는 위치부터", "등록된 AI를 확인하는 과정까지 이어집니다."]} /></p>
        </div>
        <ApiSetupGuide />
      </section>

      <section className="api-errors-section" id="api-errors">
        <div className="api-section-heading">
          <p className="eyebrow">QUICK FIX</p>
          <h2><CopyLines lines={["연결이 안 될 때는", "오류 종류부터 봅니다"]} /></h2>
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
          <h2><CopyLines lines={["API를 연결하고", "내 단어장으로", "문제를 만드세요."]} /></h2>
        </div>
        <div>
          <a className="button button-light" href="#api-top">처음부터 다시 보기</a>
        </div>
      </section>
    </main>
  );
}
