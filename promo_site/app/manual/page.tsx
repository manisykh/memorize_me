/* eslint-disable @next/next/no-html-link-for-pages */
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Memorize Me 사용 가이드",
  description: "현재 앱 화면을 기준으로 단어장 준비, 오늘 학습, 복습, AI API 연결과 설정을 설명하는 사용 가이드입니다.",
};

type FigureProps = { src: string; alt: string; caption: string; className?: string };

function AppFigure({ src, alt, caption, className = "" }: FigureProps) {
  const imageSrc = src.startsWith("/") ? src : `/media/latest/${src}`;
  return (
    <figure className={`manual-figure ${className}`.trim()}>
      <div className="manual-image-wrap"><img src={imageSrc} alt={alt} loading="lazy" /></div>
      <figcaption>{caption}</figcaption>
    </figure>
  );
}

function Step({ number, title, children }: { number: string; title: string; children: React.ReactNode }) {
  return <li className="manual-step"><span className="manual-step-number">{number}</span><div><h3>{title}</h3><p>{children}</p></div></li>;
}

export default function ManualPage() {
  return (
    <main className="manual-page" id="manual-top">
      <header className="manual-topbar">
        <a className="brand" href="/"><img className="brand-app-icon" src="/app-icon.png" alt="" /><span>Memorize Me</span></a>
        <nav><a href="/">홈으로 돌아가기</a></nav>
      </header>

      <section className="manual-hero">
        <div className="manual-hero-copy">
          <p className="eyebrow">CURRENT APP GUIDE · 2026</p>
          <h1>지금 화면 그대로,<br />처음부터 따라가기.</h1>
          <p>현재 배포 준비 중인 최신 앱 화면을 기준으로 만들었습니다. 단어장 준비부터 오늘 학습, 복습, AI 연결까지 실제 버튼 이름과 순서대로 안내합니다.</p>
          <div className="manual-hero-links"><a href="#first-open">처음부터 보기 <span>↓</span></a><a href="/ai-api">AI API만 보기 <span>→</span></a><a href="/downloads/memorize-me-app-guide.jpg" download>앱 사용 JPEG <span>↓</span></a><a href="/downloads/memorize-me-learning-guide.jpg" download>학습 기능 JPEG <span>↓</span></a></div>
        </div>
        <figure className="manual-hero-image"><img src="/media/latest/home-progress.png" alt="오늘 학습 진행 상황을 보여주는 최신 Memorize Me 홈 화면" /><figcaption>실제 최신 앱 화면 · 오늘 학습과 기억 흐름</figcaption></figure>
      </section>

      <div className="manual-layout">
        <aside className="manual-sidebar">
          <p>사용 가이드</p>
          <ol>
            <li><a href="#first-open"><span>01</span>첫 실행</a></li>
            <li><a href="#wordbook"><span>02</span>단어장 준비</a></li>
            <li><a href="#daily"><span>03</span>오늘 학습</a></li>
            <li><a href="#review"><span>04</span>학습·복습</a></li>
            <li><a href="#ai"><span>05</span>AI 학습 Beta</a></li>
            <li><a href="#settings"><span>06</span>설정</a></li>
          </ol>
          <div className="manual-sidebar-note"><strong>최신 UI 기준</strong><span>현재 앱에서 사용하는 실제 화면을 기준으로 안내합니다.</span></div>
        </aside>

        <article className="manual-content">
          <section className="manual-chapter" id="first-open">
            <header className="manual-chapter-heading"><span>01</span><div><p>FIRST OPEN</p><h2>현재 앱 화면으로 전체 흐름을 먼저 봅니다</h2><p>단어장을 준비하고 학습한 뒤, 기억 상태에 맞춰 복습하는 순서입니다.</p></div></header>
            <div className="manual-onboarding-strip">
              <AppFigure src="home.png" alt="단어장을 선택하기 전 최신 홈 화면" caption="1. 단어장 준비" />
              <AppFigure src="home-progress.png" alt="오늘 학습 진행 상황을 보여주는 최신 홈 화면" caption="2. 오늘 학습" />
              <AppFigure src="flashcard-current.png" alt="최신 플래시카드 학습 화면" caption="3. 플래시카드" />
              <AppFigure src="learning-current.png" alt="오늘의 복습과 학습 기록 화면" caption="4. 학습·복습" />
              <AppFigure src="ai-learning.png" alt="최신 AI 학습 탭" caption="5. AI 선택 기능" />
            </div>
            <ol className="manual-steps">
              <Step number="1" title="단어를 가져올 방식을 확인합니다">Google Sheets, CSV, XLSX 중 가지고 있는 자료에 맞는 방식을 고릅니다.</Step>
              <Step number="2" title="학습과 복습 구조를 살펴봅니다">플래시카드와 문제 풀이 결과가 이후의 복습 일정에 반영됩니다.</Step>
              <Step number="3" title="마지막 화면에서 시작 방식을 고릅니다">기본 단어장으로 둘러보거나 ‘단어장 추가하고 시작’을 눌러 내 자료부터 연결합니다.</Step>
            </ol>
          </section>

          <section className="manual-chapter" id="wordbook">
            <header className="manual-chapter-heading"><span>02</span><div><p>PREPARE YOUR WORDS</p><h2>먼저 학습할 단어장을 준비합니다</h2><p>홈 상단의 단어장 선택 영역 또는 ‘단어장 만들기’ 버튼에서 시작합니다.</p></div></header>
            <div className="manual-spread">
              <AppFigure src="home.png" alt="단어장을 선택하기 전 최신 홈 화면" caption="최신 홈 · 단어장 선택 전" className="manual-figure-large" />
              <div><ol className="manual-steps manual-steps-compact">
                <Step number="1" title="단어장 만들기">빈 홈에서는 파란 ‘단어장 만들기’ 버튼이 바로 다음 행동을 안내합니다.</Step>
                <Step number="2" title="자료 가져오기">Google Sheets, CSV, XLSX 중 원하는 방식을 고릅니다.</Step>
                <Step number="3" title="현재 학습 단어장 지정">가져온 단어장을 현재 학습 대상으로 선택하면 오늘 범위와 학습 흐름이 계산됩니다.</Step>
              </ol><div className="manual-note"><strong>Google 연결은 필요한 경우에만</strong><span>Google Sheets를 사용할 때만 계정을 연결합니다. CSV와 XLSX는 기기에서 바로 가져올 수 있습니다.</span></div></div>
            </div>
          </section>

          <section className="manual-chapter" id="daily">
            <header className="manual-chapter-heading"><span>03</span><div><p>TODAY</p><h2>홈에서는 오늘 처리할 학습을 봅니다</h2><p>단어장을 선택하면 기본 학습과 추가 복습, 완료 수와 남은 수가 한 화면에 정리됩니다.</p></div></header>
            <div className="manual-two-column-copy">
              <div><strong>기본</strong><p>원래 오늘 학습하기로 정한 범위입니다.</p></div>
              <div><strong>추가</strong><p>퀴즈 오답이나 복습 일정 때문에 오늘 범위에 더해진 단어입니다. 추가가 없으면 표시하지 않습니다.</p></div>
              <div><strong>완료 · 남음</strong><p>같은 단어가 여러 경로에 겹쳐도 한 번만 계산한 오늘의 진행 상황입니다.</p></div>
              <div><strong>학습 흐름</strong><p>오늘 학습 뒤 기억 상태에 따라 내일과 이후의 복습 일정이 달라집니다.</p></div>
            </div>
          </section>

          <section className="manual-chapter" id="review">
            <header className="manual-chapter-heading"><span>04</span><div><p>LEARN AND REVIEW</p><h2>익히고, 문제로 확인하고, 다시 봅니다</h2><p>객관식, 주관식·스펠링, 시험지 생성까지 같은 단어를 다른 방식으로 확인할 수 있습니다.</p></div></header>
            <div className="manual-gallery manual-gallery-three">
              <AppFigure src="flashcard-current.png" alt="최신 플래시카드 학습 화면" caption="플래시카드" />
              <AppFigure src="/media/feature/quiz-multiple-choice-current.jpg" alt="최신 객관식 퀴즈 화면" caption="객관식 퀴즈" />
              <AppFigure src="/media/feature/quiz-spelling-current.jpg" alt="최신 스펠링 퀴즈 화면" caption="스펠링 퀴즈" />
            </div>
          </section>

          <section className="manual-chapter" id="ai">
            <header className="manual-chapter-heading"><span>05</span><div><p>AI LEARNING · BETA</p><h2>AI 기능은 내 API를 연결한 뒤 사용합니다</h2><p>앱이 AI 사용료를 대신 부담하는 구조가 아닙니다. 무료 API를 발급받거나 이미 보유한 키를 연결합니다.</p></div></header>
            <div className="manual-spread">
              <AppFigure src="ai-learning.png" alt="최신 AI 학습 탭" caption="최신 AI 학습 탭 · API 미등록 상태" className="manual-figure-large" />
              <div><ol className="manual-steps manual-steps-compact">
                <Step number="1" title="시작 경로 선택">처음이면 ‘무료 API로 시작’, 이미 키가 있으면 ‘보유한 API 키 연결’을 누릅니다.</Step>
                <Step number="2" title="3단계 등록">제공업체 선택 → API 키 연결 → 연결 확인 순서로 진행합니다.</Step>
                <Step number="3" title="AI 학습 기능 사용">예문·뜻 보강, 퀴즈 생성, 문법 문제 생성에서 등록 모델을 사용합니다.</Step>
              </ol><a className="button button-primary" href="/ai-api">AI API 연결 상세 가이드 →</a></div>
            </div>
            <div className="manual-note manual-note-warning"><strong>AI 생성은 Beta</strong><span>개인 API 키가 필요하며 무료 모델은 응답 지연, 시간 초과, 토큰·분당·일일 요청 한도가 있을 수 있습니다. 생성된 문제와 정답은 학습 전에 직접 확인하세요.</span></div>
          </section>

          <section className="manual-chapter" id="settings">
            <header className="manual-chapter-heading"><span>06</span><div><p>SETTINGS</p><h2>설정은 필요한 항목만 펼쳐 관리합니다</h2><p>계정과 Google 시트, 디자인, 가이드, 소리와 음성, AI 모델과 API를 한 화면에서 찾을 수 있습니다.</p></div></header>
            <div className="manual-gallery manual-gallery-two">
              <AppFigure src="settings.png" alt="최신 앱 설정 화면" caption="앱 설정 · 항목별 펼치기" />
              <AppFigure src="ai-settings.png" alt="최신 AI 모델과 API 설정 화면" caption="무료 AI 추가 · 보유 키 추가 · 자동 대체" />
            </div>
            <div className="manual-two-column-copy">
              <div><strong>등록된 AI</strong><p>추가가 끝나면 제공업체와 모델이 카드로 표시됩니다.</p></div>
              <div><strong>우선순위</strong><p>가장 위 카드가 주 모델이며 드래그로 순서를 바꿉니다.</p></div>
              <div><strong>자동 대체</strong><p>주 모델 실패 시 아래 모델을 순서대로 시도합니다. 끄면 대체 카드가 회색으로 표시됩니다.</p></div>
              <div><strong>연결 테스트</strong><p>카드별 또는 등록된 AI 전체의 연결 상태를 다시 확인할 수 있습니다.</p></div>
            </div>
          </section>

          <section className="manual-end"><p>최신 화면 기준 안내를 모두 확인했습니다.</p><h2>단어장을 준비하고<br />오늘의 학습을 시작하세요.</h2><a href="#manual-top">가이드 처음으로 <span>↑</span></a></section>
        </article>
      </div>
    </main>
  );
}
