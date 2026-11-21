"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, KeyboardEvent as ReactKeyboardEvent } from "react";
import { faqItems, journeySteps, studyModes, type JourneyKey, type MotionVideo, type StudyModeIconName } from "./home-content";
import { CopyLines } from "./copy-lines";
import styles from "./home-v2.module.css";

type HomeLandingProps = { googlePlayUrl?: string; supportEmail?: string };
type LightboxImage = { src: string; alt: string; label: string };

const benefits = [
  ["01", "다시 입력하지 않고 가져오기", "정리한 단어장을 학습에 바로 활용합니다."],
  ["02", "카드와 퀴즈로 확인하기", "뜻을 알아보는 것에서 직접 답하는 것까지 이어집니다."],
  ["03", "오늘 복습할 단어만 모아보기", "학습 결과에 맞춰 필요한 단어만 다시 확인합니다."],
] as const;

function MotionFrame({ poster, alt, video }: { poster: string; alt: string; video?: MotionVideo }) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const element = videoRef.current;
    if (!element || !video) return;

    const startAt = video.startAt ?? 0;
    const endAt = video.endAt;
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const moveToStart = () => {
      if (Math.abs(element.currentTime - startAt) > 0.2) element.currentTime = startAt;
    };
    const play = () => {
      if (reducedMotion) return;
      void element.play().catch(() => undefined);
    };
    const onLoadedMetadata = () => {
      moveToStart();
      play();
    };
    const onTimeUpdate = () => {
      if (endAt !== undefined && element.currentTime >= endAt) {
        element.currentTime = startAt;
        play();
      }
    };

    element.addEventListener("loadedmetadata", onLoadedMetadata);
    element.addEventListener("timeupdate", onTimeUpdate);

    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        if (element.currentTime < startAt || (endAt !== undefined && element.currentTime >= endAt)) moveToStart();
        play();
      } else {
        element.pause();
      }
    }, { threshold: 0.2 });
    observer.observe(element);

    if (element.readyState >= 1) onLoadedMetadata();

    return () => {
      observer.disconnect();
      element.removeEventListener("loadedmetadata", onLoadedMetadata);
      element.removeEventListener("timeupdate", onTimeUpdate);
      element.pause();
    };
  }, [video]);

  const sourceWidth = video?.sourceWidth ?? 1080;
  const sourceHeight = video?.sourceHeight ?? 2340;
  const cropLeft = video?.cropLeft ?? 0;
  const cropRight = video?.cropRight ?? 0;
  const cropTop = video?.cropTop ?? 0;
  const cropBottom = video?.cropBottom ?? 0;
  const visibleWidth = sourceWidth - cropLeft - cropRight;
  const visibleHeight = sourceHeight - cropTop - cropBottom;
  const cropStyle = {
    "--video-aspect": `${visibleWidth} / ${visibleHeight}`,
  } as CSSProperties;
  const videoStyle = {
    width: `${(sourceWidth / visibleWidth) * 100}%`,
    height: `${(sourceHeight / visibleHeight) * 100}%`,
    left: `-${(cropLeft / visibleWidth) * 100}%`,
    top: `-${(cropTop / visibleHeight) * 100}%`,
  } as CSSProperties;

  return (
    <div className={styles.motionFrame}>
      {video ? (
        <div className={styles.videoViewport}>
          <div className={styles.videoCrop} style={cropStyle}>
            <video ref={videoRef} muted playsInline preload="metadata" poster={poster} aria-label={alt} style={videoStyle}>
              <source src={video.src} type="video/mp4" />
            </video>
          </div>
        </div>
      ) : <img src={poster} alt={alt} width="720" height="1080" loading="lazy" decoding="async" />}
    </div>
  );
}

function FormatIcon({ type }: { type: "sheets" | "csv" | "xlsx" }) {
  if (type === "sheets") {
    return <span className={`${styles.formatIconBox} ${styles.sheetsIcon}`}><svg viewBox="0 0 32 38" aria-hidden="true"><path fill="#0f9d58" d="M4 0h16l8 8v27a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3Z"/><path fill="#87d6aa" d="M20 0v8h8Z"/><path fill="#fff" d="M7 14h15v15H7Zm3 3v3h3v-3Zm5 0v3h4v-3Zm-5 5v4h3v-4Zm5 0v4h4v-4Z"/></svg></span>;
  }
  if (type === "csv") {
    return <span className={`${styles.formatIconBox} ${styles.csvIcon}`}><svg viewBox="0 0 32 38" aria-hidden="true"><path fill="#607086" d="M4 0h16l8 8v27a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3Z"/><path fill="#b8c2cf" d="M20 0v8h8Z"/><path fill="#fff" d="M5 17h19v12H5Z"/><text x="14.5" y="25.8" textAnchor="middle" fontSize="7.2" fontWeight="900" fill="#607086">CSV</text></svg></span>;
  }
  return <span className={`${styles.formatIconBox} ${styles.xlsxIcon}`}><svg viewBox="0 0 32 38" aria-hidden="true"><path fill="#107c41" d="M4 0h16l8 8v27a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3Z"/><path fill="#54aa78" d="M20 0v8h8Z"/><path fill="#fff" d="m8 14 4.2 7L8 28h4l2.4-4.3L17 28h4l-4.4-7 4.2-7h-4l-2.2 4-2.3-4Z"/></svg></span>;
}

function StudyModeIcon({ type }: { type: StudyModeIconName }) {
  if (type === "flashcard") {
    return <span className={`${styles.studyModeIcon} ${styles.flashcardModeIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m5 7 7-3 7 3-7 3-7-3Z"/><path d="m5 11 7 3 7-3M5 15l7 3 7-3"/></svg></span>;
  }
  if (type === "choice") {
    return <span className={`${styles.studyModeIcon} ${styles.choiceModeIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="3"/><path d="m7.5 9 1.3 1.3L11 8M13.5 9H17M7.5 15l1.3 1.3L11 14M13.5 15H17"/></svg></span>;
  }
  if (type === "spelling") {
    return <span className={`${styles.studyModeIcon} ${styles.spellingModeIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m5 17-.6 3.2 3.2-.6L18.7 8.5a2.1 2.1 0 0 0-3-3L5 17Z"/><path d="m13.8 7.4 2.8 2.8M4 20h16"/></svg></span>;
  }
  if (type === "mistakes") {
    return <span className={`${styles.studyModeIcon} ${styles.mistakesModeIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M7 3h8l4 4v14H7z"/><path d="M15 3v5h5M10 12l5 5M15 12l-5 5"/></svg></span>;
  }
  if (type === "review") {
    return <span className={`${styles.studyModeIcon} ${styles.reviewModeIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M19 8V4l-2 2a8 8 0 1 0 2 9"/><path d="M19 4h-4"/></svg></span>;
  }
  return <span className={`${styles.studyModeIcon} ${styles.testModeIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M6 3h9l4 4v14H6z"/><path d="M15 3v5h5M9 12h7M9 16h7"/></svg></span>;
}

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
  const [activeJourney, setActiveJourney] = useState<JourneyKey>("import");
  const [activeMode, setActiveMode] = useState(0);
  const [lightboxImage, setLightboxImage] = useState<LightboxImage | null>(null);
  const modeTouchStartX = useRef<number | null>(null);
  const modeTabsRef = useRef<HTMLDivElement>(null);
  const journeyRefs = useRef<Record<JourneyKey, HTMLElement | null>>({ import: null, learn: null, review: null });
  const activeJourneyStep = useMemo(() => journeySteps.find((step) => step.key === activeJourney) ?? journeySteps[0], [activeJourney]);
  const activeStudyMode = studyModes[activeMode];

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
    const container = modeTabsRef.current;
    const selected = container?.querySelector<HTMLElement>("[aria-selected='true']");
    if (!container || !selected || container.scrollWidth <= container.clientWidth) return;
    container.scrollTo({
      left: selected.offsetLeft - container.offsetLeft - (container.clientWidth - selected.offsetWidth) / 2,
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
    });
  }, [activeMode]);

  useEffect(() => {
    let frame = 0;

    const updateActiveStep = () => {
      frame = 0;
      const readingLine = window.innerHeight * 0.52;
      let nextStep: JourneyKey = "import";

      for (const step of journeySteps) {
        const node = journeyRefs.current[step.key];
        if (!node) continue;

        const bounds = node.getBoundingClientRect();
        const contentFocusPoint =
          bounds.top + Math.min(bounds.height * 0.38, 240);

        if (contentFocusPoint <= readingLine) {
          nextStep = step.key;
        }
      }

      setActiveJourney((current) => current === nextStep ? current : nextStep);
    };

    const scheduleUpdate = () => {
      if (frame) return;
      frame = window.requestAnimationFrame(updateActiveStep);
    };

    updateActiveStep();
    window.addEventListener("scroll", scheduleUpdate, { passive: true });
    window.addEventListener("resize", scheduleUpdate);

    return () => {
      window.removeEventListener("scroll", scheduleUpdate);
      window.removeEventListener("resize", scheduleUpdate);
      if (frame) window.cancelAnimationFrame(frame);
    };
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
          <nav className={styles.desktopNav} aria-label="주요 메뉴"><a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><a href="#faq">FAQ</a><a className={styles.guideLink} href="/manual">사용자 가이드</a><a className={`${styles.primaryCta} ${styles.compactCta}`} href="/feedback">의견 게시판 <span aria-hidden="true">→</span></a></nav>
          <button type="button" className={styles.menuButton} aria-expanded={menuOpen} aria-controls="mobile-menu" onClick={() => setMenuOpen((open) => !open)}><span aria-hidden="true">{menuOpen ? "×" : "☰"}</span><span className={styles.srOnly}>{menuOpen ? "메뉴 닫기" : "메뉴 열기"}</span></button>
        </div>
        {menuOpen ? <nav id="mobile-menu" className={styles.mobileMenu} aria-label="모바일 메뉴"><a href="#journey" onClick={closeMenu}>시작하기</a><a href="#learning" onClick={closeMenu}>학습 방식</a><a href="#ai" onClick={closeMenu}>AI 학습</a><a href="#faq" onClick={closeMenu}>FAQ</a><a href="/manual" onClick={closeMenu}>사용자 가이드</a><a className={styles.primaryCta} href="/feedback" onClick={closeMenu}>의견 게시판 <span aria-hidden="true">→</span></a></nav> : null}
      </header>

      <div id="main-content">
        <section className={styles.hero} aria-labelledby="hero-title">
          <div className={styles.heroInner}>
            <div className={styles.heroCopy}>
              <p className={styles.kicker}>내 단어장으로 시작하는 학습</p>
              <h1 id="hero-title"><CopyLines lines={["이미 만든 단어장,", <strong key="hero-strong">그대로 외우세요.</strong>]} /></h1>
              <p className={styles.heroDescription}><CopyLines lines={["정리해 둔 단어는 다시 입력하지 마세요.", "가져온 단어장으로 익히고 퀴즈로 확인하세요.", "필요한 때 다시 볼 단어까지 앱이 정리합니다."]} /></p>
              <ul className={styles.formatList} aria-label="가져올 수 있는 단어장 형식">
                <li><FormatIcon type="sheets" /><span>Google Sheets</span></li>
                <li><FormatIcon type="csv" /><span>CSV</span></li>
                <li><FormatIcon type="xlsx" /><span>XLSX</span></li>
              </ul>
              {!googlePlayUrl ? <p className={styles.releaseNote}><span aria-hidden="true" />Android · Google Play 출시 준비 중</p> : null}
            </div>
          </div>
        </section>

        <section className={styles.benefits} aria-labelledby="benefits-title">
          <div className={styles.sectionInner}>
            <div className={styles.sectionHeading}><p className={styles.kicker}>왜 Memorize Me인가요?</p><h2 id="benefits-title"><CopyLines lines={["가져온 단어가", "학습과 복습으로", "이어집니다."]} /></h2></div>
            <div className={styles.benefitGrid}>{benefits.map(([number, title, body]) => <article key={number}><span>{number}</span><h3>{title}</h3><p>{body}</p></article>)}</div>
          </div>
        </section>

        <section className={styles.journey} id="journey" aria-labelledby="journey-title">
          <div className={styles.sectionInner}>
            <div className={styles.sectionHeading}><p className={styles.kicker}>처음 시작하기</p><h2 id="journey-title"><CopyLines lines={["세 단계면", "학습이 시작됩니다."]} /></h2><p><CopyLines lines={["단어장을 가져와 학습하고,", "오늘 필요한 단어를 다시 봅니다."]} /></p></div>
            <div className={styles.journeyLayout}>
              <div className={styles.journeySteps}>{journeySteps.map((step) => <article key={step.key} data-step={step.key} ref={(node) => { journeyRefs.current[step.key] = node; }} className={activeJourney === step.key ? styles.activeJourney : ""}><p>{step.label}</p><h3><CopyLines lines={step.titleLines} /></h3><p><CopyLines lines={step.descriptionLines} /></p><ul>{step.points.map((point) => <li key={point}>{point}</li>)}</ul><div className={styles.mobileJourneyImage}><MotionFrame poster={step.image} alt={step.imageAlt} video={step.video} /></div></article>)}</div>
              <div className={styles.journeySticky} aria-live="polite"><MotionFrame key={activeJourneyStep.key} poster={activeJourneyStep.image} alt={activeJourneyStep.imageAlt} video={activeJourneyStep.video} /><p>{activeJourneyStep.label}</p></div>
            </div>
          </div>
        </section>

        <section className={styles.learning} id="learning" aria-labelledby="learning-title">
          <div className={styles.learningInner}>
            <div className={styles.learningHeading}><p className={styles.kicker}>학습 방식</p><h2 id="learning-title"><CopyLines lines={["익히고, 직접 답하고,", "필요할 때 다시 봅니다."]} /></h2><p><CopyLines lines={["같은 단어를 여러 방식으로 확인하고,", "그 기록을 다음 복습으로 연결합니다."]} /></p></div>
            <div className={styles.learningAxis}>
              <div className={styles.modeCopy}>
                <div className={styles.modeTitleRow}><StudyModeIcon type={activeStudyMode.icon} /><h3>{activeStudyMode.title}</h3></div>
                <p><CopyLines lines={activeStudyMode.bodyLines} /></p>
                <div ref={modeTabsRef} id="mode-tabs" className={styles.modeTabs} role="tablist" aria-label="학습과 복습 기능 선택" onKeyDown={(event) => tabKeyHandler(event, activeMode, studyModes.length, selectMode)}>{studyModes.map((mode, index) => <button id={`mode-tabs-tab-${index}`} key={mode.title} type="button" role="tab" aria-selected={activeMode === index} aria-controls={`mode-panel-${index}`} tabIndex={activeMode === index ? 0 : -1} onClick={() => selectMode(index)}><StudyModeIcon type={mode.icon} /><span>{mode.title}</span></button>)}</div>
              </div>
              <div className={styles.modeCarousel} role="region" aria-roledescription="carousel" aria-label="학습과 복습 기능 화면. 모바일에서는 좌우로 밀어 전환할 수 있습니다." onTouchStart={(event) => { modeTouchStartX.current = event.changedTouches[0]?.clientX ?? null; }} onTouchEnd={(event) => { const startX = modeTouchStartX.current; const endX = event.changedTouches[0]?.clientX; modeTouchStartX.current = null; if (startX === null || endX === undefined) return; const distance = endX - startX; if (Math.abs(distance) >= 48) selectMode(activeMode + (distance < 0 ? 1 : -1)); }}>
                <div id={`mode-panel-${activeMode}`} key={activeStudyMode.title} role="tabpanel" aria-labelledby={`mode-tabs-tab-${activeMode}`} className={styles.modePanel}><div role="group" aria-label={`${activeMode + 1}/${studyModes.length}`}><MotionFrame poster={activeStudyMode.image} alt={activeStudyMode.imageAlt} video={activeStudyMode.video} /></div></div>
                <div className={styles.carouselControls}><button type="button" onClick={() => selectMode(activeMode - 1)} aria-label="이전 학습 방식">←</button><div>{studyModes.map((mode, index) => <button key={mode.title} type="button" aria-label={`${mode.title} 보기`} aria-current={activeMode === index ? "true" : undefined} onClick={() => selectMode(index)}><span /></button>)}</div><button type="button" onClick={() => selectMode(activeMode + 1)} aria-label="다음 학습 방식">→</button></div>
                <button className={styles.expandButton} type="button" onClick={() => showImage({ src: activeStudyMode.image, alt: activeStudyMode.imageAlt, label: activeStudyMode.title })}>화면 크게 보기</button>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.aiSection} id="ai" aria-labelledby="ai-title">
          <div className={styles.sectionInner}>
            <div className={styles.aiLayout}>
              <div className={styles.aiCopy}><p className={styles.kicker}>선택 기능 · AI 학습</p><h2 id="ai-title"><CopyLines lines={["내 API가 있을 때,", "학습을 더 넓게."]} /></h2><p><CopyLines lines={["기본 학습은 AI 연결 없이", "사용할 수 있습니다.", "개인 API로 예문과 뜻을 보강하고,", "난이도별 문제를 만들 수 있습니다."]} /></p><ul><li><span aria-hidden="true">✓</span>예문과 뜻 보강</li><li><span aria-hidden="true">✓</span>단어·독해·문법 문제 생성</li><li><span aria-hidden="true">✓</span>PDF·HTML 시험지 저장·내보내기</li></ul><p className={styles.aiNotice}><CopyLines lines={["AI 기능에는 직접 발급한", "API 키가 필요합니다.", "요금은 연결한 서비스 정책에 따르며,", "무료 이용은 사용량 제한이나", "응답 지연이 있을 수 있습니다."]} /></p><div className={styles.aiLinks}><a href="/ai-api">AI API 연결 가이드</a></div></div>
              <div className={styles.aiVisual}><MotionFrame poster="/media/showcase/ai-menu.jpg" alt="AI 학습 기능과 개인 API 안내를 보여주는 화면" /><div className={styles.aiResultCard}><span>생성 후 활용</span><strong>PDF · HTML 저장</strong></div></div>
            </div>
          </div>
        </section>

        <section className={styles.faqSection} id="faq" aria-labelledby="faq-title">
          <div className={styles.sectionInner}>
            <div className={styles.faqLayout}><div className={styles.helpPanel}><p className={styles.kicker}>도움말</p><h2><CopyLines lines={["필요한 안내를", "바로 찾아보세요."]} /></h2><p><CopyLines lines={["실제 조작은 사용자 가이드에서 확인하고,", "발견한 내용은 의견 게시판에 남겨주세요."]} /></p><a href="/manual">사용자 가이드 →</a><a href="/feedback">의견 게시판 →</a>{supportEmail ? <a href={`mailto:${supportEmail}`}>문의 {supportEmail}</a> : null}</div><div className={styles.faq}><p className={styles.kicker}>자주 묻는 질문</p><h2 id="faq-title">시작 전에 확인하세요.</h2>{faqItems.map((item, index) => <details key={item.question} open={index === 0}><summary>{item.question}<b aria-hidden="true" /></summary><p>{item.answer}</p></details>)}</div></div>
          </div>
        </section>

        <section className={styles.finalCta} aria-labelledby="final-title"><div><p className={styles.kicker}>내 단어장으로 시작하기</p><h2 id="final-title"><CopyLines lines={["이미 정리한 단어장으로,", "오늘의 학습을 준비하세요."]} /></h2><p>{googlePlayUrl ? "Google Play에서 앱을 설치하고 학습을 시작하세요." : "출시 알림을 신청하거나 사용자 가이드에서 학습 방법을 미리 확인하세요."}</p><div className={styles.finalActions}><PrimaryCta googlePlayUrl={googlePlayUrl} supportEmail={supportEmail} /><a href="/manual">사용자 가이드 보기 <span aria-hidden="true">→</span></a></div></div></section>
      </div>

      <footer className={styles.footer}><div className={styles.footerInner}><div className={styles.footerBrand}><a className={styles.brand} href="#top"><img src="/app-icon-192.png" width="42" height="42" alt="" /><span>Memorize Me</span></a><p>내 단어장으로 시작하는 학습</p></div><nav aria-label="서비스"><strong>서비스</strong><a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><a href="#faq">FAQ</a></nav><nav aria-label="지원"><strong>지원</strong><a href="/manual">사용자 가이드</a><a href="/feedback">의견 게시판</a>{supportEmail ? <a href={`mailto:${supportEmail}`}>문의 이메일</a> : null}</nav><nav aria-label="정책"><strong>정책</strong><a href="/privacy">개인정보 처리방침</a><a href="/account-deletion">계정 삭제 안내</a></nav><div><strong>앱</strong><p>{googlePlayUrl ? "Google Play에서 제공" : "Google Play 출시 준비 중"}</p></div></div><div className={styles.footerBottom}>© 2026 Memorize Me</div></footer>

      {lightboxImage ? <div className={styles.lightbox} role="dialog" aria-modal="true" aria-label={`${lightboxImage.label} 화면 확대`} onMouseDown={(event) => { if (event.target === event.currentTarget) setLightboxImage(null); }}><button type="button" onClick={() => setLightboxImage(null)} aria-label="확대 화면 닫기">닫기 ×</button><figure><img src={lightboxImage.src} alt={lightboxImage.alt} /><figcaption>{lightboxImage.label}</figcaption></figure></div> : null}
    </main>
  );
}
