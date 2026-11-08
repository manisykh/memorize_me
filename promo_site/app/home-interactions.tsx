"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { KeyboardEvent as ReactKeyboardEvent } from "react";
import { faqItems, journeySteps, studyModes, type JourneyKey } from "./home-content";
import styles from "./home-v2.module.css";

type HomeLandingProps = { googlePlayUrl?: string; supportEmail?: string };
type LightboxImage = { src: string; alt: string; label: string };

const heroScenes = [
  { key: "import", label: "가져오기", src: "/media/feature/sheet-selection-current.svg", alt: "Google Sheets에서 학습할 시트를 선택하는 화면" },
  { key: "learn", label: "학습", src: "/media/showcase/flashcard-action.jpg", alt: "단어를 보고 알아요 또는 몰라요로 답하는 플래시카드 화면" },
  { key: "review", label: "복습", src: "/media/showcase/review-today.jpg", alt: "오늘 복습할 단어와 복습 시작 버튼을 보여주는 화면" },
] as const;

const benefits = [
  ["01", "다시 입력하지 않고 가져오기", "정리한 단어장을 학습에 바로 활용합니다.", "/manual#wordbook"],
  ["02", "카드와 퀴즈로 확인하기", "뜻을 알아보는 것에서 직접 답하는 것까지 이어집니다.", "/manual#daily"],
  ["03", "오늘 복습할 단어만 모아보기", "학습 결과에 맞춰 필요한 단어만 다시 확인합니다.", "/manual#review"],
] as const;

function tabKeyHandler(event: ReactKeyboardEvent<HTMLDivElement>, current: number, count: number, select: (index: number) => void) {
  let next = current;
  if (event.key === "ArrowRight" || event.key === "ArrowDown") next = (current + 1) % count;
  else if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = (current - 1 + count) % count;
  else if (event.key === "Home") next = 0;
  else if (event.key === "End") next = count - 1;
  else return;
  event.preventDefault();
  select(next);
  requestAnimationFrame(() => document.getElementById(`${event.currentTarget.id}-tab-${next}`)?.focus());
}

function PrimaryCta({ googlePlayUrl, supportEmail, compact = false }: HomeLandingProps & { compact?: boolean }) {
  if (googlePlayUrl) {
    return <a className={`${styles.primaryCta} ${compact ? styles.compactCta : ""}`} href={googlePlayUrl} target="_blank" rel="noreferrer">Google Play에서 받기 <span aria-hidden="true">↗</span></a>;
  }
  if (supportEmail) {
    const href = `mailto:${supportEmail}?subject=${encodeURIComponent("Memorize Me Android 출시 알림 신청")}`;
    return <a className={`${styles.primaryCta} ${compact ? styles.compactCta : ""}`} href={href}>Android 출시 알림 받기 <span aria-hidden="true">→</span></a>;
  }
  return <a className={`${styles.primaryCta} ${compact ? styles.compactCta : ""}`} href="#journey">시작 방법 보기 <span aria-hidden="true">→</span></a>;
}

export function HomeLanding({ googlePlayUrl, supportEmail }: HomeLandingProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [heroStage, setHeroStage] = useState(0);
  const [activeJourney, setActiveJourney] = useState<JourneyKey>("import");
  const [activeMode, setActiveMode] = useState(0);
  const [lightboxImage, setLightboxImage] = useState<LightboxImage | null>(null);
  const journeyRefs = useRef<Record<JourneyKey, HTMLElement | null>>({ import: null, learn: null, review: null });
  const activeJourneyStep = useMemo(() => journeySteps.find((step) => step.key === activeJourney) ?? journeySteps[0], [activeJourney]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMenuOpen(false);
        setLightboxImage(null);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    if (!menuOpen && !lightboxImage) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previous; };
  }, [menuOpen, lightboxImage]);

  useEffect(() => {
    const observer = new IntersectionObserver((entries) => {
      const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
      if (visible) setActiveJourney(visible.target.getAttribute("data-step") as JourneyKey);
    }, { rootMargin: "-35% 0px -35% 0px", threshold: [0, .25, .5, .75] });
    Object.values(journeyRefs.current).forEach((node) => { if (node) observer.observe(node); });
    return () => observer.disconnect();
  }, []);

  const showImage = (image: LightboxImage) => setLightboxImage(image);
  const selectMode = (index: number) => setActiveMode((index + studyModes.length) % studyModes.length);
  const closeMenu = () => setMenuOpen(false);

  return (
    <main className={styles.page} id="top">
      <a className={styles.skipLink} href="#main-content">본문으로 건너뛰기</a>

      <header className={styles.header}>
        <div className={styles.headerInner}>
          <a className={styles.brand} href="#top" aria-label="Memorize Me 처음으로"><img src="/app-icon-192.png" width="42" height="42" alt="" /><span>Memorize Me</span></a>
          <nav className={styles.desktopNav} aria-label="주요 메뉴"><a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><a href="#faq">FAQ</a><a className={styles.guideLink} href="/manual">사용자 가이드</a><PrimaryCta googlePlayUrl={googlePlayUrl} supportEmail={supportEmail} compact /></nav>
          <button type="button" className={styles.menuButton} aria-expanded={menuOpen} aria-controls="mobile-menu" onClick={() => setMenuOpen((open) => !open)}><span aria-hidden="true">{menuOpen ? "×" : "☰"}</span><span className={styles.srOnly}>{menuOpen ? "메뉴 닫기" : "메뉴 열기"}</span></button>
        </div>
        {menuOpen ? <nav id="mobile-menu" className={styles.mobileMenu} aria-label="모바일 메뉴"><a href="#journey" onClick={closeMenu}>시작하기</a><a href="#learning" onClick={closeMenu}>학습 방식</a><a href="#ai" onClick={closeMenu}>AI 학습</a><a href="#faq" onClick={closeMenu}>FAQ</a><a href="/manual" onClick={closeMenu}>사용자 가이드</a><PrimaryCta googlePlayUrl={googlePlayUrl} supportEmail={supportEmail} /></nav> : null}
      </header>

      <div id="main-content">
        <section className={styles.hero} aria-labelledby="hero-title">
          <div className={styles.heroInner}>
            <div className={styles.heroCopy}>
              <p className={styles.kicker}>내 단어장으로 시작하는 학습</p>
              <h1 id="hero-title">이미 만든 단어장,<strong>그대로 외우세요.</strong></h1>
              <p className={styles.heroDescription}>구글 시트나 엑셀에 정리한 단어장을 그대로 가져오세요. 카드와 퀴즈로 공부하고, 학습 결과에 맞춰 필요한 단어를 복습하세요.</p>
              <div className={styles.formatBadges} aria-label="지원 형식"><span>Google Sheets</span><span>CSV</span><span>XLSX</span></div>
              <div className={styles.heroActions}><PrimaryCta googlePlayUrl={googlePlayUrl} supportEmail={supportEmail} /><a className={styles.textLink} href="/manual">사용자 가이드 보기 <span aria-hidden="true">→</span></a></div>
              {!googlePlayUrl ? <p className={styles.releaseNote}><span aria-hidden="true" />Android · Google Play 출시 준비 중</p> : null}
            </div>

            <div className={styles.heroShowcase}>
              <div className={styles.heroPanels}>
                {heroScenes.map((scene, index) => <div id={`hero-panel-${index}`} key={scene.key} role="tabpanel" aria-labelledby={`hero-tabs-tab-${index}`} hidden={heroStage !== index} className={styles.heroPanel}><div className={styles.device}><img src={scene.src} alt={scene.alt} width="720" height="1080" loading={index === 0 ? "eager" : "lazy"} fetchPriority={index === 0 ? "high" : undefined} decoding="async" /></div></div>)}
              </div>
              <div id="hero-tabs" className={styles.heroTabs} role="tablist" aria-label="앱 화면 선택" onKeyDown={(event) => tabKeyHandler(event, heroStage, heroScenes.length, setHeroStage)}>{heroScenes.map((scene, index) => <button id={`hero-tabs-tab-${index}`} key={scene.key} type="button" role="tab" aria-selected={heroStage === index} aria-controls={`hero-panel-${index}`} tabIndex={heroStage === index ? 0 : -1} onClick={() => setHeroStage(index)}>{scene.label}</button>)}</div>
            </div>
          </div>
        </section>

        <section className={styles.benefits} aria-labelledby="benefits-title">
          <div className={styles.sectionInner}>
            <div className={styles.sectionHeading}><p className={styles.kicker}>왜 Memorize Me인가요?</p><h2 id="benefits-title">단어장을 다시 만드는 대신,<br />바로 학습을 시작하세요.</h2></div>
            <div className={styles.benefitGrid}>{benefits.map(([number, title, body, href]) => <article key={number}><span>{number}</span><h3>{title}</h3><p>{body}</p><a href={href} aria-label={`${title} 자세히 보기`}>자세히 보기 <span aria-hidden="true">→</span></a></article>)}</div>
          </div>
        </section>

        <section className={styles.journey} id="journey" aria-labelledby="journey-title">
          <div className={styles.sectionInner}>
            <div className={styles.sectionHeading}><p className={styles.kicker}>처음 시작하기</p><h2 id="journey-title">세 단계면 학습이 시작됩니다.</h2><p>가져오고, 학습하고, 오늘 필요한 단어를 다시 봅니다.</p></div>
            <div className={styles.journeyLayout}>
              <div className={styles.journeySteps}>{journeySteps.map((step, index) => <article key={step.key} data-step={step.key} ref={(node) => { journeyRefs.current[step.key] = node; }} className={activeJourney === step.key ? styles.activeJourney : ""}><p>0{index + 1} · {step.label}</p><h3>{step.title}</h3><p>{step.description}</p><ul>{step.points.map((point) => <li key={point}>{point}</li>)}</ul><a href={step.guideHref} aria-label={`${index + 1}단계 ${step.label} 자세히 보기`}>이 단계 자세히 보기 <span aria-hidden="true">→</span></a><div className={styles.mobileJourneyImage}><div className={styles.device}><img src={step.image} alt={step.imageAlt} width="720" height="1080" loading="lazy" decoding="async" /></div></div></article>)}</div>
              <div className={styles.journeySticky} aria-live="polite"><div className={styles.device}><img key={activeJourneyStep.key} src={activeJourneyStep.image} alt={activeJourneyStep.imageAlt} width="720" height="1080" loading="lazy" decoding="async" /></div><p>{activeJourneyStep.label}</p></div>
            </div>
          </div>
        </section>

        <section className={styles.learning} id="learning" aria-labelledby="learning-title">
          <div className={styles.learningInner}>
            <div className={styles.learningHeading}><p className={styles.kicker}>학습 방식</p><h2 id="learning-title">익히고, 직접 답하고,<br />필요할 때 다시 봅니다.</h2><p>같은 단어를 여러 각도에서 확인하고, 그 기록을 다음 복습으로 연결합니다.</p></div>
            <div className={styles.learningAxis}>
              <div className={styles.modeCopy}>
                <p className={styles.axisLabel}>01 · {studyModes[activeMode].axis}</p>
                <h3>{studyModes[activeMode].title}</h3>
                <p>{studyModes[activeMode].body}</p>
                <a href={studyModes[activeMode].guideHref}>{studyModes[activeMode].title} 사용법 <span aria-hidden="true">→</span></a>
                <div id="mode-tabs" className={styles.modeTabs} role="tablist" aria-label="학습 방식 선택" onKeyDown={(event) => tabKeyHandler(event, activeMode, studyModes.length, selectMode)}>{studyModes.map((mode, index) => <button id={`mode-tabs-tab-${index}`} key={mode.title} type="button" role="tab" aria-selected={activeMode === index} aria-controls={`mode-panel-${index}`} tabIndex={activeMode === index ? 0 : -1} onClick={() => selectMode(index)}>{mode.title}</button>)}</div>
              </div>
              <div className={styles.modeCarousel} role="region" aria-roledescription="carousel" aria-label="학습 방식 화면">
                {studyModes.map((mode, index) => <div id={`mode-panel-${index}`} key={mode.title} role="tabpanel" aria-labelledby={`mode-tabs-tab-${index}`} hidden={activeMode !== index} className={styles.modePanel}><div role="group" aria-label={`${index + 1}/${studyModes.length}`} className={styles.device}><img src={mode.image} alt={mode.imageAlt} width="720" height="1080" loading="lazy" decoding="async" /></div></div>)}
                <div className={styles.carouselControls}><button type="button" onClick={() => selectMode(activeMode - 1)} aria-label="이전 학습 방식">←</button><div>{studyModes.map((mode, index) => <button key={mode.title} type="button" aria-label={`${mode.title} 보기`} aria-current={activeMode === index ? "true" : undefined} onClick={() => selectMode(index)}><span /></button>)}</div><button type="button" onClick={() => selectMode(activeMode + 1)} aria-label="다음 학습 방식">→</button></div>
                <button className={styles.expandButton} type="button" onClick={() => showImage({ src: studyModes[activeMode].image, alt: studyModes[activeMode].imageAlt, label: studyModes[activeMode].title })}>화면 크게 보기</button>
              </div>
            </div>
            <div className={`${styles.learningAxis} ${styles.reviewAxis}`}>
              <div className={styles.modeCopy}><p className={styles.axisLabel}>03 · 복습하기</p><h3>오늘 필요한 단어만 다시 보세요</h3><p>기억 단계와 학습 결과에 맞춰 오늘·내일·7일 안의 복습 일정을 보여줍니다.</p><a href="/manual#review">복습 사용법 <span aria-hidden="true">→</span></a></div>
              <div className={styles.reviewVisual}><img src="/media/showcase/stats-memory.jpg" alt="기억 단계별 단어 수" width="720" height="640" loading="lazy" decoding="async" /><img src="/media/showcase/stats-schedule.jpg" alt="오늘과 앞으로의 복습 일정" width="720" height="640" loading="lazy" decoding="async" /><span>오늘 복습할 단어를 따로 고르지 않아도 됩니다.</span></div>
            </div>
          </div>
        </section>

        <section className={styles.aiSection} id="ai" aria-labelledby="ai-title">
          <div className={styles.sectionInner}>
            <div className={styles.aiLayout}>
              <div className={styles.aiCopy}><p className={styles.kicker}>선택 기능 · AI 학습</p><h2 id="ai-title">내 API가 있을 때,<br />학습을 더 넓게.</h2><p>기본 학습은 AI 연결 없이 사용할 수 있습니다. 개인 API를 연결하면 단어장의 예문과 뜻을 보강하고, 난이도별 문제를 만들 수 있습니다.</p><ul><li><span aria-hidden="true">✓</span>예문과 뜻 보강</li><li><span aria-hidden="true">✓</span>단어·독해·문법 문제 생성</li><li><span aria-hidden="true">✓</span>PDF·HTML 시험지 내보내기</li></ul><p className={styles.aiNotice}>AI 기능에는 직접 발급한 API 키가 필요합니다. 이용 요금은 연결한 서비스 정책에 따르며, 무료 이용에는 사용량 제한이나 응답 지연이 있을 수 있습니다.</p><div className={styles.aiLinks}><a href="/ai-api">AI API 연결 가이드</a><a href="/manual#ai">AI 학습 사용법 →</a></div></div>
              <div className={styles.aiVisual}><div className={styles.device}><img src="/media/showcase/ai-menu.jpg" alt="AI 학습 기능과 개인 API 안내를 보여주는 화면" width="720" height="1080" loading="lazy" decoding="async" /></div><div className={styles.aiResultCard}><span>생성 후 활용</span><strong>PDF · HTML</strong></div></div>
            </div>
          </div>
        </section>

        <section className={styles.faqSection} id="faq" aria-labelledby="faq-title">
          <div className={styles.sectionInner}>
            <div className={styles.faqLayout}><div className={styles.helpPanel}><p className={styles.kicker}>도움말</p><h2>필요한 안내를<br />바로 찾아보세요.</h2><p>실제 조작은 사용자 가이드에서 확인하고, 테스트 중 발견한 내용은 의견 게시판에 남겨주세요.</p><a href="/manual">사용자 가이드 →</a><a href="/feedback"><span>테스트 참여자용</span> 의견 게시판 →</a>{supportEmail ? <a href={`mailto:${supportEmail}`}>문의 {supportEmail}</a> : null}</div><div className={styles.faq}><p className={styles.kicker}>자주 묻는 질문</p><h2 id="faq-title">시작 전에 확인하세요.</h2>{faqItems.map((item, index) => <details key={item.question} open={index === 0}><summary>{item.question}<b aria-hidden="true" /></summary><p>{item.answer}</p></details>)}</div></div>
          </div>
        </section>

        <section className={styles.finalCta} aria-labelledby="final-title"><div><p className={styles.kicker}>내 단어장으로 시작하기</p><h2 id="final-title">이미 정리한 단어장으로,<br />오늘의 학습을 준비하세요.</h2><p>{googlePlayUrl ? "Google Play에서 앱을 설치하고 학습을 시작하세요." : "출시 알림을 신청하거나 사용자 가이드에서 학습 방법을 미리 확인하세요."}</p><div className={styles.finalActions}><PrimaryCta googlePlayUrl={googlePlayUrl} supportEmail={supportEmail} /><a href="/manual">사용자 가이드 보기 <span aria-hidden="true">→</span></a></div></div></section>
      </div>

      <footer className={styles.footer}><div className={styles.footerInner}><div className={styles.footerBrand}><a className={styles.brand} href="#top"><img src="/app-icon-192.png" width="42" height="42" alt="" /><span>Memorize Me</span></a><p>내 단어장으로 시작하는 학습</p></div><nav aria-label="서비스"><strong>서비스</strong><a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><a href="#faq">FAQ</a></nav><nav aria-label="지원"><strong>지원</strong><a href="/manual">사용자 가이드</a><a href="/feedback">테스터 의견</a>{supportEmail ? <a href={`mailto:${supportEmail}`}>문의 이메일</a> : null}</nav><nav aria-label="정책"><strong>정책</strong><a href="/privacy">개인정보 처리방침</a><a href="/account-deletion">계정 삭제 안내</a></nav><div><strong>앱</strong><p>{googlePlayUrl ? "Google Play에서 제공" : "Google Play 출시 준비 중"}</p></div></div><div className={styles.footerBottom}>© 2026 Memorize Me</div></footer>

      {lightboxImage ? <div className={styles.lightbox} role="dialog" aria-modal="true" aria-label={`${lightboxImage.label} 화면 확대`} onMouseDown={(event) => { if (event.target === event.currentTarget) setLightboxImage(null); }}><button type="button" onClick={() => setLightboxImage(null)} aria-label="확대 화면 닫기">닫기 ×</button><figure><img src={lightboxImage.src} alt={lightboxImage.alt} /><figcaption>{lightboxImage.label}</figcaption></figure></div> : null}
    </main>
  );
}
