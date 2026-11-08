"use client";

import { useEffect, useRef, useState } from "react";
import type { CSSProperties } from "react";
import { faqItems, journeySteps, studyModes, type JourneyKey } from "./home-content";
import styles from "./home-v2.module.css";

type HomeLandingProps = { googlePlayUrl?: string; supportEmail?: string };
type LightboxImage = { src: string; alt: string; label: string };

const heroScenes = [
  { key: "home", label: "오늘 학습", title: "오늘 할 만큼만 한눈에", description: "학습할 범위와 다음 복습 일정을 바로 확인합니다.", src: "/media/latest/home-progress.png", alt: "오늘 학습 범위와 학습 흐름을 보여주는 최신 Memorize Me 홈 화면" },
  { key: "learn", label: "카드 학습", title: "단어를 보고 기억을 꺼내기", description: "플래시카드로 익히고 결과를 기억 단계에 반영합니다.", src: "/media/current-20261107/flashcard-learning.jpg", alt: "학습 진행률과 기억 단계를 보여주는 최신 플래시카드 학습 화면" },
  { key: "review", label: "맞춤 복습", title: "필요한 단어가 다시 나타나기", description: "학습 기록에 맞춰 오늘과 앞으로의 복습을 정리합니다.", src: "/media/current-20261107/stats-word2.jpg", alt: "기억 현황과 복습 일정을 보여주는 최신 통계 화면" },
] as const;

function PrimaryCta({ googlePlayUrl, compact = false }: { googlePlayUrl?: string; compact?: boolean }) {
  const label = googlePlayUrl ? "Google Play에서 받기" : "사용자 가이드 보기";
  return <a className={`${styles.primaryCta} ${compact ? styles.compactCta : ""}`} href={googlePlayUrl || "/manual"} target={googlePlayUrl ? "_blank" : undefined} rel={googlePlayUrl ? "noreferrer" : undefined}>{label}<span aria-hidden="true">↗</span></a>;
}

export function HomeLanding({ googlePlayUrl, supportEmail }: HomeLandingProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [heroStage, setHeroStage] = useState(0);
  const [heroPlaying, setHeroPlaying] = useState(true);
  const [activeJourney, setActiveJourney] = useState<JourneyKey>("import");
  const [activeMode, setActiveMode] = useState(0);
  const [lightboxImage, setLightboxImage] = useState<LightboxImage | null>(null);
  const journeyCarouselRef = useRef<HTMLDivElement>(null);

  useEffect(() => { if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) setHeroPlaying(false); }, []);
  useEffect(() => {
    if (!heroPlaying) return;
    const timer = window.setInterval(() => setHeroStage((current) => (current + 1) % heroScenes.length), 4200);
    return () => window.clearInterval(timer);
  }, [heroPlaying]);
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => { if (event.key === "Escape") { setMenuOpen(false); setLightboxImage(null); } };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);
  useEffect(() => {
    if (!lightboxImage) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previousOverflow; };
  }, [lightboxImage]);

  const selectJourney = (key: JourneyKey) => {
    const index = journeySteps.findIndex((step) => step.key === key);
    setActiveJourney(key);
    const carousel = journeyCarouselRef.current;
    if (carousel && index >= 0) carousel.scrollTo({ left: carousel.clientWidth * index, behavior: "smooth" });
  };
  const syncJourneyFromScroll = () => {
    const carousel = journeyCarouselRef.current;
    if (!carousel || carousel.clientWidth === 0) return;
    const index = Math.max(0, Math.min(journeySteps.length - 1, Math.round(carousel.scrollLeft / carousel.clientWidth)));
    setActiveJourney(journeySteps[index].key);
  };
  const showImage = (image: LightboxImage) => setLightboxImage(image);
  const activeHero = heroScenes[heroStage];
  const activeStudyMode = studyModes[activeMode];

  return (
    <main className={styles.page} id="top">
      <a className={styles.skipLink} href="#main-content">본문으로 건너뛰기</a>
      <header className={styles.header}>
        <a className={styles.brand} href="#top" aria-label="Memorize Me 처음으로"><img src="/app-icon.png" alt="" aria-hidden="true" /><span>Memorize Me</span></a>
        <nav className={styles.desktopNav} aria-label="주요 메뉴"><a href="#difference">핵심 장점</a><a href="#learning">학습과 복습</a><a href="#journey">시작 안내</a><a href="#ai">AI 학습</a><a href="#faq">도움말</a><a className={styles.navCta} href="/manual">사용자 가이드</a></nav>
        <button type="button" className={styles.menuButton} aria-expanded={menuOpen} aria-controls="mobile-menu" onClick={() => setMenuOpen((value) => !value)}><span aria-hidden="true">{menuOpen ? "×" : "☰"}</span><span className={styles.srOnly}>{menuOpen ? "메뉴 닫기" : "메뉴 열기"}</span></button>
        {menuOpen ? <nav id="mobile-menu" className={styles.mobileMenu} aria-label="모바일 메뉴"><a href="#difference" onClick={() => setMenuOpen(false)}>핵심 장점</a><a href="#learning" onClick={() => setMenuOpen(false)}>학습과 복습</a><a href="#journey" onClick={() => setMenuOpen(false)}>시작 안내</a><a href="#ai" onClick={() => setMenuOpen(false)}>AI 학습</a><a href="/manual" onClick={() => setMenuOpen(false)}>사용자 가이드</a><a href="/feedback" onClick={() => setMenuOpen(false)}>의견 게시판</a></nav> : null}
      </header>

      <div id="main-content">
        <section className={styles.hero} aria-labelledby="hero-title">
          <div className={styles.heroCopy}>
            <p className={styles.eyebrow}>MY WORDS · TODAY&apos;S LEARNING</p>
            <h1 id="hero-title">이미 만든 단어장,<strong>그대로 외우세요.</strong></h1>
            <p className={styles.heroDescription}>구글 시트나 엑셀에 정리한 단어장을 다시 입력하지 마세요. 가져온 단어를 카드와 퀴즈로 익히고, 학습 결과에 맞춰 필요한 단어를 복습하세요.</p>
            <div className={styles.heroActions}><PrimaryCta googlePlayUrl={googlePlayUrl} /><a className={styles.secondaryCta} href="#learning">학습 방식 살펴보기 <span aria-hidden="true">↓</span></a></div>
            <div className={styles.heroMeta}>{!googlePlayUrl ? <span><i />Android 출시 준비 중</span> : null}<span>AI 연결 없이 기본 학습 가능</span></div>
          </div>

          <div className={styles.heroDemo} aria-label="Memorize Me 학습 흐름 데모">
            <div className={styles.demoTopbar}><div><span /><span /><span /></div><p>실제 최신 앱 화면</p><button type="button" onClick={() => setHeroPlaying((playing) => !playing)} aria-label={heroPlaying ? "자동 전환 일시정지" : "자동 전환 재생"}>{heroPlaying ? "Ⅱ" : "▶"}</button></div>
            <button type="button" className={styles.heroViewport} onClick={() => showImage({ src: activeHero.src, alt: activeHero.alt, label: activeHero.label })} aria-label={`${activeHero.label} 전체 화면 보기`}>
              {heroScenes.map((scene, index) => <img key={scene.key} className={index === heroStage ? styles.activeHeroImage : ""} src={scene.src} alt={index === heroStage ? scene.alt : ""} aria-hidden={index !== heroStage} />)}
              <span className={styles.viewportHint}>전체 화면 보기 ↗</span>
            </button>
            <div className={styles.heroDemoCaption} aria-live="polite"><div><span>{String(heroStage + 1).padStart(2, "0")}</span><strong>{activeHero.title}</strong></div><p>{activeHero.description}</p></div>
            <div className={styles.heroTabs} role="tablist" aria-label="학습 흐름 화면 선택">{heroScenes.map((scene, index) => <button key={scene.key} type="button" role="tab" aria-selected={heroStage === index} className={heroStage === index ? styles.activeHeroTab : ""} onClick={() => setHeroStage(index)}>{scene.label}</button>)}</div>
          </div>
        </section>

        <section className={styles.benefits} id="difference" aria-labelledby="benefits-title">
          <div className={styles.sectionIntro}><p className={styles.eyebrow}>WHY MEMORIZE ME</p><h2 id="benefits-title">단어장을 다시 만드는 대신,<br />바로 학습을 시작하세요.</h2></div>
          <div className={styles.benefitGrid}>
            <article className={styles.benefitCard}><div className={styles.benefitCopy}><span>01</span><h3>다시 입력하지 않고 가져오기</h3><p>Google Sheets와 기기 안의 CSV·XLSX를 그대로 사용하고, 앱에서 직접 만들 수도 있습니다.</p></div><div className={`${styles.benefitVisual} ${styles.importVisual}`} aria-hidden="true"><div className={styles.sheetRows}><span>resilient</span><span>practical</span><span>approach</span></div><b>→</b><div className={styles.wordbookMini}><strong>나의 단어장</strong><span>3개 단어 준비 완료</span></div></div></article>
            <article className={styles.benefitCard}><div className={styles.benefitCopy}><span>02</span><h3>카드와 퀴즈로 확인하기</h3><p>뜻을 알아보는 학습에서 직접 고르고 입력하는 확인까지 자연스럽게 이어집니다.</p></div><div className={`${styles.benefitVisual} ${styles.quizVisual}`} aria-hidden="true"><div><small>단어</small><strong>attention</strong><span>주의, 주목, 관심</span></div><div className={styles.answerPulse}>B</div></div></article>
            <article className={styles.benefitCard}><div className={styles.benefitCopy}><span>03</span><h3>오늘 복습할 단어만 모아보기</h3><p>무엇을 다시 볼지 따로 고르지 않아도 학습 결과에 맞춰 필요한 단어를 보여줍니다.</p></div><div className={`${styles.benefitVisual} ${styles.reviewVisual}`} aria-hidden="true"><div className={styles.reviewRing}><strong>11</strong><span>오늘 복습</span></div><div className={styles.reviewBars}><span style={{ "--bar": "42%" } as CSSProperties}>오늘</span><span style={{ "--bar": "76%" } as CSSProperties}>내일</span><span style={{ "--bar": "24%" } as CSSProperties}>7일 내</span></div></div></article>
          </div>
        </section>

        <section className={styles.learning} id="learning" aria-labelledby="learning-title">
          <div className={styles.learningHeader}><div className={styles.sectionIntro}><p className={styles.eyebrow}>LEARN · CHECK · REVIEW</p><h2 id="learning-title">익히고, 직접 답하고,<br />필요할 때 다시 봅니다.</h2></div><p>같은 단어를 여러 각도에서 확인하고, 그 기록을 다음 복습으로 연결합니다.</p></div>
          <div className={styles.modeShowcase}>
            <div className={styles.modeList} role="tablist" aria-label="학습 방식 선택">
              {studyModes.map((mode, index) => <button type="button" role="tab" aria-selected={activeMode === index} className={activeMode === index ? styles.activeMode : ""} key={mode.title} onClick={() => setActiveMode(index)}><span>{String(index + 1).padStart(2, "0")}</span><div><strong>{mode.title}</strong><p>{mode.body}</p></div><i aria-hidden="true">→</i></button>)}
              <div className={styles.reviewNote}><span>복습</span><p>학습 결과에 맞춰 오늘 다시 볼 단어를 보여줍니다.</p></div>
            </div>
            <button type="button" className={styles.modeStage} onClick={() => showImage({ src: activeStudyMode.image, alt: activeStudyMode.imageAlt, label: activeStudyMode.title })} aria-label={`${activeStudyMode.title} 전체 화면 보기`}>
              {studyModes.map((mode, index) => <img key={mode.title} className={activeMode === index ? styles.activeModeImage : ""} src={mode.image} alt={activeMode === index ? mode.imageAlt : ""} aria-hidden={activeMode !== index} />)}
              <div className={styles.modeStageLabel}><span>0{activeMode + 1}</span><strong>{activeStudyMode.title}</strong><em>실제 화면 ↗</em></div>
            </button>
          </div>
          <div className={styles.reviewStory}>
            <div className={styles.reviewStoryCopy}><p className={styles.eyebrow}>REVIEW, WHEN IT MATTERS</p><h3>오늘 복습할 단어를<br />따로 고르지 않아도 됩니다.</h3><p>기억 단계와 학습 결과를 바탕으로 오늘·내일·7일 안의 복습을 한눈에 보여줍니다.</p><div><span>진입</span><i>→</i><span>학습 중</span><i>→</i><span>복습 예정</span><i>→</i><span>안정 기억</span></div></div>
            <button type="button" className={styles.reviewCrop} onClick={() => showImage({ src: "/media/current-20261107/stats-word2.jpg", alt: "기억 현황과 복습 일정을 보여주는 최신 통계 화면", label: "복습 일정" })}><img src="/media/current-20261107/stats-word2.jpg" alt="기억 현황과 복습 일정을 보여주는 최신 통계 화면" /><span>복습 일정 전체 보기 ↗</span></button>
          </div>
        </section>

        <section className={styles.journey} id="journey" aria-labelledby="journey-title">
          <div className={styles.sectionIntro}><p className={styles.eyebrow}>GET STARTED</p><h2 id="journey-title">처음 시작하는 3단계</h2><p>필요한 작업만 순서대로 확인하세요. 자세한 조작은 각 단계의 사용자 가이드로 연결됩니다.</p></div>
          <div className={styles.journeyTabs} role="tablist" aria-label="처음 시작하는 단계">{journeySteps.map((step, index) => <button key={step.key} type="button" role="tab" aria-selected={activeJourney === step.key} className={activeJourney === step.key ? styles.activeJourneyTab : ""} onClick={() => selectJourney(step.key)}><span>{String(index + 1).padStart(2, "0")}</span>{step.shortLabel}</button>)}</div>
          <div className={styles.journeyCarousel} ref={journeyCarouselRef} onScroll={syncJourneyFromScroll}>
            {journeySteps.map((step, index) => <article className={styles.journeyPanel} key={step.key} aria-hidden={activeJourney !== step.key} inert={activeJourney !== step.key}><div className={styles.journeyCopy}><p>STEP {String(index + 1).padStart(2, "0")}</p><h3>{step.title}</h3><p>{step.description}</p><ul>{step.points.map((point) => <li key={point}>{point}</li>)}</ul><a href={step.guideHref}>이 단계 자세히 보기 <span aria-hidden="true">→</span></a></div><button type="button" className={styles.journeyVisual} onClick={() => showImage({ src: step.image, alt: step.imageAlt, label: step.imageLabel })} aria-label={`${step.imageLabel} 전체 화면 보기`}><img src={step.image} alt={step.imageAlt} /><span>{step.imageLabel} · 전체 화면 ↗</span></button></article>)}
          </div>
          <div className={styles.journeyDots} aria-hidden="true">{journeySteps.map((step) => <span key={step.key} className={activeJourney === step.key ? styles.activeDot : ""} />)}</div>
        </section>

        <section className={styles.aiSection} id="ai" aria-labelledby="ai-title">
          <div className={styles.aiHeading}><p className={styles.eyebrow}>OPTIONAL · AI LEARNING</p><h2 id="ai-title">내 API가 있을 때,<br />학습을 더 넓게.</h2><p>기본 학습은 AI 없이 사용할 수 있습니다. 개인 API를 연결한 경우에만 예문 보강과 문제 생성을 이용합니다.</p><div className={styles.aiActions}><a href="/ai-api">AI API 연결 가이드 →</a><a href="/manual#ai">AI 학습 사용법 →</a></div></div>
          <div className={styles.aiFlow}><article><div><span>01</span><strong>예문·뜻 보강</strong></div><figure><img src="/media/latest/ai-learning.png" alt="최신 AI 학습 메뉴 화면" /></figure></article><article><div><span>02</span><strong>난이도별 문제 생성</strong></div><figure><img src="/media/manual/ai-quiz-current.jpg" alt="최신 AI 퀴즈 생성 화면" /></figure></article><article><div><span>03</span><strong>PDF·HTML 내보내기</strong></div><figure><img src="/media/manual/pdf-result.jpg" alt="생성한 시험지 내보내기 결과 화면" /></figure></article></div>
          <p className={styles.aiNotice}>AI 기능에는 직접 발급한 API 키가 필요합니다. 이용 요금은 연결한 서비스 정책에 따르며, 무료 이용에는 사용량 제한이나 응답 지연이 있을 수 있습니다.</p>
        </section>

        <section className={styles.faqSection} id="faq" aria-labelledby="faq-title">
          <aside className={styles.helpPanel}><p className={styles.eyebrow}>HELP & FEEDBACK</p><h2>필요한 안내를<br />바로 찾아보세요.</h2><p>소개 페이지는 핵심만 보여줍니다. 실제 조작은 사용자 가이드에서 확인하고, 테스트 중 발견한 내용은 의견 게시판에 남겨주세요.</p><div><a href="/manual">사용자 가이드 →</a><a href="/feedback">테스터 의견 게시판 →</a></div></aside>
          <div className={styles.faq}><p className={styles.eyebrow}>BEFORE YOU START</p><h2 id="faq-title">자주 묻는 질문</h2>{faqItems.map((item, index) => <details key={item.question} open={index === 0}><summary>{item.question}<span aria-hidden="true">＋</span></summary><p>{item.answer}</p></details>)}</div>
        </section>

        <section className={styles.finalCta} aria-labelledby="final-title"><p className={styles.eyebrow}>START WITH YOUR WORDS</p><h2 id="final-title">이미 정리한 단어장에서,<br />오늘의 학습을 시작하세요.</h2><p>{googlePlayUrl ? "Google Play에서 앱을 설치하고 내 단어장으로 학습을 시작하세요." : "출시 전에는 사용자 가이드에서 가져오기·학습·복습 방법을 미리 확인할 수 있습니다."}</p><div className={styles.finalActions}><PrimaryCta googlePlayUrl={googlePlayUrl} /><a href="/feedback">테스트 중이라면 의견 남기기 →</a></div>{supportEmail ? <a className={styles.supportEmail} href={`mailto:${supportEmail}`}>문의 {supportEmail}</a> : null}</section>
      </div>

      <footer className={styles.footer}><a className={styles.brand} href="#top"><img src="/app-icon.png" alt="" aria-hidden="true" /><span>Memorize Me</span></a><nav aria-label="정책 및 지원"><a href="/privacy">개인정보 처리방침</a><a href="/account-deletion">계정 삭제</a><a href="/manual">사용자 가이드</a><a href="/feedback">의견 게시판</a></nav><p>© 2026 Memorize Me</p></footer>

      {lightboxImage ? <div className={styles.lightbox} role="dialog" aria-modal="true" aria-label={`${lightboxImage.label} 화면 확대`} onMouseDown={(event) => { if (event.target === event.currentTarget) setLightboxImage(null); }}><button type="button" onClick={() => setLightboxImage(null)} aria-label="확대 화면 닫기">닫기 ×</button><figure><img src={lightboxImage.src} alt={lightboxImage.alt} /><figcaption>{lightboxImage.label}</figcaption></figure></div> : null}
    </main>
  );
}
