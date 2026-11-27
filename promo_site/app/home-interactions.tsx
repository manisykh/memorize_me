"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import type { CSSProperties, KeyboardEvent as ReactKeyboardEvent } from "react";
import { faqItems, preparationOptions, preparationVisual, studyModes, type MotionVideo, type PreparationIconName, type StudyModeIconName } from "./home-content";
import { CopyLines } from "./copy-lines";
import { ProductMediaFrame } from "./product-media-frame";
import styles from "./home-v2.module.css";
import testing from "./testing.module.css";
import { EnrollmentModal, ReleaseAction, type EnrollmentMode } from "./testing-enrollment";
import { releasePresentation, type ReleaseConfig } from "../lib/site-release";

type HomeLandingProps = { releaseConfig: ReleaseConfig };

function MailIcon() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="3" /><path d="m4 7 8 6 8-6" strokeLinejoin="round" /></svg>;
}

const benefits = [
  ["01", ["다시 입력하지", "않고 가져오기"], "정리한 단어장을 학습에 바로 활용합니다."],
  ["02", ["카드와 퀴즈로", "확인하기"], "뜻을 알아보는 것에서 직접 답하는 것까지 이어집니다."],
  ["03", ["오늘 복습할", "단어만 모아보기"], "학습 결과에 맞춰 필요한 단어만 다시 확인합니다."],
] as const;

const aiFeatures = [
  {
    title: "예문·뜻 보강",
    subtitle: "예문·뜻·오타를 한 번에 보강해요.",
    icon: "doc_text",
    accent: "#087fe0",
    softAccent: "#e8f2ff",
    image: "/media/manual/ai-result.jpg",
    imageAlt: "AI가 예문과 뜻을 보강한 앱 결과 화면",
    caption: "예문과 뜻을 한 번에 보강하기",
  },
  {
    title: "퀴즈 생성",
    subtitle: "단어장 맞춤 문제를 만들어줘요.",
    icon: "list_bullet",
    accent: "#00ad7c",
    softAccent: "#e2f8f1",
    image: "/media/video/posters/ai-quiz-generation.jpg",
    imageAlt: "단어장으로 생성한 AI 맞춤 퀴즈 화면",
    video: {
      src: "/media/video/ai-quiz-generation.mp4",
      startAt: 0.05,
      endAt: 12.5,
      sourceWidth: 480,
      sourceHeight: 968,
    } satisfies MotionVideo,
    caption: "내 단어장으로 맞춤 퀴즈 만들기",
  },
  {
    title: "문법 문제 생성",
    subtitle: "문법 범위별 문제를 만들어줘요.",
    icon: "book",
    accent: "#e77b12",
    softAccent: "#fff0e3",
    image: "/media/video/posters/ai-grammar-generation.jpg",
    imageAlt: "문법 범위를 선택해 생성한 문제 화면",
    video: {
      src: "/media/video/ai-grammar-generation.mp4",
      startAt: 0.05,
      endAt: 10.35,
      sourceWidth: 480,
      sourceHeight: 968,
    } satisfies MotionVideo,
    caption: "선택한 문법 범위로 문제 만들기",
  },
  {
    title: "저장된 AI 퀴즈",
    subtitle: "저장한 문제를 다시 보거나 합쳐요.",
    icon: "rectangle_stack",
    accent: "#7257dc",
    softAccent: "#eeeaff",
    image: "/media/video/posters/ai-saved-quizzes.jpg",
    imageAlt: "저장된 AI 퀴즈를 다시 확인하는 화면",
    video: {
      src: "/media/video/ai-saved-quizzes.mp4",
      startAt: 0.05,
      endAt: 8.1,
      sourceWidth: 480,
      sourceHeight: 968,
    } satisfies MotionVideo,
    caption: "저장한 퀴즈 다시 풀고 합치기",
  },
] as const;

function MotionFrame({ poster, alt, video, active = true, onProgress }: { poster: string; alt: string; video?: MotionVideo; active?: boolean; onProgress?: (currentTime: number) => void }) {
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const element = videoRef.current;
    if (!element || !video) return;

    // Keep every learning video warm in the browser cache. Only the selected
    // panel plays, so switching modes shows motion immediately without six
    // videos competing for playback at the same time.
    if (element.readyState === HTMLMediaElement.HAVE_NOTHING) element.load();
    if (!active) {
      element.pause();
      return;
    }

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
      onProgress?.(startAt);
      play();
    };
    const onTimeUpdate = () => {
      if (endAt !== undefined && element.currentTime >= endAt) {
        element.currentTime = startAt;
        onProgress?.(startAt);
        play();
        return;
      }
      onProgress?.(element.currentTime);
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
  }, [video, active, onProgress]);

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
    <ProductMediaFrame className={styles.motionFrame}>
      {video ? (
        <div className={styles.videoViewport}>
          <div className={styles.videoCrop} style={cropStyle}>
            <video
              ref={videoRef}
              muted
              playsInline
              preload={active ? "auto" : "metadata"}
              poster={poster}
              aria-label={alt}
              data-start={video.startAt ?? 0}
              data-end={video.endAt}
              style={videoStyle}
            >
              <source src={video.src} type="video/mp4" />
            </video>
          </div>
        </div>
      ) : <img src={poster} alt={alt} width="720" height="1080" loading="lazy" decoding="async" />}
    </ProductMediaFrame>
  );
}

function BeforeAfterSlider({ beforeSrc, afterSrc, beforeAlt, afterAlt }: { beforeSrc: string; afterSrc: string; beforeAlt: string; afterAlt: string }) {
  const [position, setPosition] = useState(50);

  return (
    <ProductMediaFrame className={`${styles.motionFrame} ${styles.aiCompareFrame}`}>
      <div className={styles.aiCompareCanvas}>
        <div className={styles.aiCompareBefore} style={{ clipPath: `inset(0 ${100 - position}% 0 0)` }}>
          <img className={styles.aiCompareImage} src={beforeSrc} alt={beforeAlt} width="591" height="1200" loading="eager" decoding="async" />
          <span className={`${styles.aiCompareLabel} ${styles.aiCompareBeforeLabel}`} aria-hidden="true">보강 전</span>
        </div>
        <div className={styles.aiCompareAfter} style={{ clipPath: `inset(0 0 0 ${position}%)` }}>
          <img className={styles.aiCompareImage} src={afterSrc} alt={afterAlt} width="591" height="1200" loading="eager" decoding="async" />
          <span className={`${styles.aiCompareLabel} ${styles.aiCompareAfterLabel}`} aria-hidden="true">보강 후</span>
        </div>
        <span className={styles.aiCompareDivider} style={{ left: `${position}%` }} aria-hidden="true">
          <span className={styles.aiCompareHandle}>
            <svg viewBox="0 0 24 24" aria-hidden="true"><path d="m9 7-5 5 5 5M15 7l5 5-5 5" /></svg>
          </span>
        </span>
        <input
          className={styles.aiCompareRange}
          type="range"
          min="0"
          max="100"
          value={position}
          onChange={(event) => setPosition(Number(event.currentTarget.value))}
          aria-label="예문과 뜻 보강 전후 화면 비교"
          aria-valuetext={`보강 전 ${position}%, 보강 후 ${100 - position}%`}
        />
      </div>
    </ProductMediaFrame>
  );
}

function FormatIcon({ type }: { type: "sheets" | "csv" | "xlsx" }) {
  if (type === "sheets") {
    return <span className={`${styles.formatIconBox} ${styles.sheetsIcon}`}><svg viewBox="0 0 29 38" aria-hidden="true"><path fill="#0f9d58" d="M4 0h16l8 8v27a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3Z"/><path fill="#87d6aa" d="M20 0v8h8Z"/><path fill="#fff" d="M7 14h15v15H7Zm3 3v3h3v-3Zm5 0v3h4v-3Zm-5 5v4h3v-4Zm5 0v4h4v-4Z"/></svg></span>;
  }
  if (type === "csv") {
    return <span className={`${styles.formatIconBox} ${styles.csvIcon}`}><svg viewBox="0 0 29 38" aria-hidden="true"><path fill="#607086" d="M4 0h16l8 8v27a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3Z"/><path fill="#b8c2cf" d="M20 0v8h8Z"/><path fill="#fff" d="M5 17h19v12H5Z"/><text x="14.5" y="25.8" textAnchor="middle" fontSize="7.2" fontWeight="900" fill="#607086">CSV</text></svg></span>;
  }
  return <span className={`${styles.formatIconBox} ${styles.xlsxIcon}`}><svg viewBox="0 0 29 38" aria-hidden="true"><path fill="#107c41" d="M4 0h16l8 8v27a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V3a3 3 0 0 1 3-3Z"/><path fill="#54aa78" d="M20 0v8h8Z"/><path fill="#fff" d="m8 14 4.2 7L8 28h4l2.4-4.3L17 28h4l-4.4-7 4.2-7h-4l-2.2 4-2.3-4Z"/></svg></span>;
}

function PreparationIcon({ type }: { type: PreparationIconName }) {
  if (type === "import") {
    return <span className={`${styles.preparationIcon} ${styles.importPreparationIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5M12 11v7M9 15l3 3 3-3"/></svg></span>;
  }
  if (type === "create") {
    return <span className={`${styles.preparationIcon} ${styles.createPreparationIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M4 5.5A3.5 3.5 0 0 1 7.5 2H12v18H7.5A3.5 3.5 0 0 0 4 23Z"/><path d="M20 5.5A3.5 3.5 0 0 0 16.5 2H12v18h4.5a3.5 3.5 0 0 1 3.5 3ZM7 11h3M8.5 9.5v3"/></svg></span>;
  }
  return <span className={`${styles.preparationIcon} ${styles.builtinPreparationIcon}`} aria-hidden="true"><svg viewBox="0 0 24 24"><path d="m4 7 8-4 8 4-8 4-8-4Z"/><path d="m4 12 8 4 8-4M4 17l8 4 8-4"/><path d="M12 11v5"/></svg></span>;
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

function AiFeatureIcon({ feature }: { feature: (typeof aiFeatures)[number] }) {
  return (
    <span
      className={styles.aiFeatureIcon}
      style={{ "--ai-accent": feature.accent, "--ai-soft-accent": feature.softAccent } as CSSProperties}
      aria-hidden="true"
    >
      <i className={styles.cupertinoIcon}>{feature.icon}</i>
    </span>
  );
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
  const tabId = `${event.currentTarget.id}-tab-${next}`;
  requestAnimationFrame(() => document.getElementById(tabId)?.focus({ preventScroll: true }));
}

function centerSelectedTab(container: HTMLDivElement | null) {
  const selected = container?.querySelector<HTMLElement>("[aria-selected='true']");
  if (!container || !selected || container.scrollWidth <= container.clientWidth) return;
  const containerBounds = container.getBoundingClientRect();
  const selectedBounds = selected.getBoundingClientRect();
  container.scrollTo({
    left: container.scrollLeft + selectedBounds.left - containerBounds.left - (container.clientWidth - selectedBounds.width) / 2,
    behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
  });
}

export function HomeLanding({ releaseConfig }: HomeLandingProps) {
  const [liveRelease, setLiveRelease] = useState(releaseConfig);
  const [enrollmentMode, setEnrollmentMode] = useState<EnrollmentMode | null>(null);
  const release = releasePresentation(liveRelease);
  const productFaqItems = faqItems.map((item) => item.question === "지원 기기와 비용은 어떻게 되나요?" ? { ...item, answer: `${release.label}. ${item.answer.replace("현재 Android 출시를 준비하고 있습니다. ", "")}` } : item);
  const supportEmail = liveRelease.supportEmail;
  const openEnrollment = (mode: EnrollmentMode) => setEnrollmentMode(mode);
  useEffect(() => {
    const forwardTestingLink = () => {
      if (window.location.hash === "#closed-testing" || window.location.hash === "#testing-faq") {
        window.location.replace(`/testing${window.location.hash === "#testing-faq" ? "#testing-faq" : ""}`);
      }
    };
    forwardTestingLink();
    window.addEventListener("hashchange", forwardTestingLink);
    return () => window.removeEventListener("hashchange", forwardTestingLink);
  }, []);
  useEffect(() => {
    const abort = new AbortController();
    void fetch("/api/tester-applications?view=config", { cache: "no-store", signal: abort.signal }).then((response) => response.ok ? response.json() : null).then((data) => { if (data?.config) setLiveRelease(data.config); }).catch(() => undefined);
    return () => abort.abort();
  }, []);
  const [menuOpen, setMenuOpen] = useState(false);
  const [activeMode, setActiveMode] = useState(0);
  const [activePreparation, setActivePreparation] = useState(0);
  const [activeAiFeature, setActiveAiFeature] = useState(0);
  const modeTouchStartX = useRef<number | null>(null);
  const modeTabsRef = useRef<HTMLDivElement>(null);
  const aiTabsRef = useRef<HTMLDivElement>(null);
  const aiTouchStart = useRef<{ x: number; y: number } | null>(null);
  const activeStudyMode = studyModes[activeMode];
  const selectedAiFeature = aiFeatures[activeAiFeature];

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMenuOpen(false);
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previous; };
  }, [menuOpen]);

  useEffect(() => {
    centerSelectedTab(modeTabsRef.current);
  }, [activeMode]);

  useEffect(() => {
    centerSelectedTab(aiTabsRef.current);
  }, [activeAiFeature]);

  const syncPreparationToVideo = useCallback((currentTime: number) => {
    let nextIndex = 0;
    preparationOptions.forEach((option, index) => {
      if (currentTime >= option.videoStartsAt) nextIndex = index;
    });
    setActivePreparation((current) => current === nextIndex ? current : nextIndex);
  }, []);
  const selectMode = (index: number) => setActiveMode((index + studyModes.length) % studyModes.length);
  const selectAiFeature = (index: number) => setActiveAiFeature((index + aiFeatures.length) % aiFeatures.length);
  const closeMenu = () => setMenuOpen(false);

  return (
    <main className={styles.page} id="top">
      <a className={styles.skipLink} href="#main-content">본문으로 건너뛰기</a>

      <header className={styles.header}>
        <div className={styles.headerInner}>
          <a className={styles.brand} href="#top" aria-label="Memorize Me 처음으로"><img src="/app-icon-192.png" width="42" height="42" alt="" /><span>Memorize Me</span></a>
          <nav className={styles.desktopNav} aria-label="주요 메뉴"><a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><a href="#faq">FAQ</a><Link className={styles.headerPageButton} href="/testing">{liveRelease.releaseStatus === "released" ? "출시 안내" : "테스트 안내"}</Link><a className={styles.headerPageButton} href="/ai-api">AI API 연결 가이드</a><a className={`${styles.headerPageButton} ${styles.headerPageButtonPrimary}`} href="/feedback">의견 게시판</a></nav>
          <button type="button" className={styles.menuButton} aria-expanded={menuOpen} aria-controls="mobile-menu" onClick={() => setMenuOpen((open) => !open)}><span aria-hidden="true">{menuOpen ? "×" : "☰"}</span><span className={styles.srOnly}>{menuOpen ? "메뉴 닫기" : "메뉴 열기"}</span></button>
        </div>
        {menuOpen ? <nav id="mobile-menu" className={styles.mobileMenu} aria-label="모바일 메뉴"><a href="#journey" onClick={closeMenu}>시작하기</a><a href="#learning" onClick={closeMenu}>학습 방식</a><a href="#ai" onClick={closeMenu}>AI 학습</a><a href="#faq" onClick={closeMenu}>FAQ</a><Link className={styles.headerPageButton} href="/testing" onClick={closeMenu}>{liveRelease.releaseStatus === "released" ? "출시 안내" : "테스트 안내"}</Link><a className={styles.headerPageButton} href="/ai-api" onClick={closeMenu}>AI API 연결 가이드</a><a className={`${styles.headerPageButton} ${styles.headerPageButtonPrimary}`} href="/feedback" onClick={closeMenu}>의견 게시판</a></nav> : null}
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
              <p className={styles.releaseNote}><span aria-hidden="true" />{release.label}</p>
              <div className={testing.heroExtras}>
                <p>{liveRelease.releaseStatus === "released" ? "Google Play에서 Memorize Me를 만나보세요." : "정식 출시 전 Memorize Me를 먼저 경험해 보세요."}</p>
                <div className={testing.heroActions}><ReleaseAction config={liveRelease} onOpen={openEnrollment} /><Link href="/testing">{liveRelease.releaseStatus === "released" ? "출시 안내" : "테스트 안내"}</Link></div>
                {liveRelease.acceptingTesters ? <p className={testing.note}>Android 기기 · Google 계정 필요 · 최소 {liveRelease.minimumParticipationDays}일 참여</p> : null}
              </div>
            </div>
          </div>
        </section>

        <section className={styles.benefits} aria-labelledby="benefits-title">
          <div className={styles.sectionInner}>
            <div className={styles.sectionHeading}><p className={styles.kicker}>왜 Memorize Me인가요?</p><h2 id="benefits-title"><CopyLines lines={["가져온 단어가", "학습과 복습으로 이어집니다."]} /></h2></div>
            <div className={styles.benefitGrid}>{benefits.map(([number, titleLines, body]) => <article key={number}><span>{number}</span><h3><CopyLines lines={titleLines} /></h3><p>{body}</p></article>)}</div>
          </div>
        </section>

        <section className={styles.journey} id="journey" aria-labelledby="journey-title">
          <div className={styles.sectionInner}>
            <div className={styles.sectionHeading}><p className={styles.kicker}>시작하기</p><h2 id="journey-title"><CopyLines lines={["단어장만 준비하면,", "바로 시작할 수 있어요."]} /></h2><p><CopyLines lines={["이미 정리한 자료를 가져오거나", "직접 만들 수 있습니다.", "준비된 자료가 없다면", "필수 영어단어 6000으로 시작하세요."]} /></p></div>
            <div className={styles.preparationLayout}>
              <div className={styles.preparationOptions}>{preparationOptions.map((option, index) => <article key={option.title} data-active={activePreparation === index ? "true" : undefined} aria-current={activePreparation === index ? "step" : undefined}><PreparationIcon type={option.icon} /><div><h3>{option.title}</h3><p><CopyLines lines={option.descriptionLines} /></p></div></article>)}</div>
              <div className={styles.preparationVisual}><MotionFrame poster={preparationVisual.image} alt={preparationVisual.imageAlt} video={preparationVisual.video} onProgress={syncPreparationToVideo} /><p className="product-media-caption" aria-live="polite">{preparationOptions[activePreparation].caption}</p></div>
            </div>
            <div className={styles.learningBridge}><span>단어장 준비 완료</span><strong><CopyLines lines={["이제 나에게 맞는", "학습 방식을 골라보세요."]} /></strong></div>
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
                {studyModes.map((mode, index) => <div id={`mode-panel-${index}`} key={mode.title} role="tabpanel" aria-labelledby={`mode-tabs-tab-${index}`} className={styles.modePanel} hidden={activeMode !== index}><div role="group" aria-label={`${index + 1}/${studyModes.length}`}><MotionFrame poster={mode.image} alt={mode.imageAlt} video={mode.video} active={activeMode === index} /></div></div>)}
                <div className={styles.carouselControls}><button type="button" onClick={() => selectMode(activeMode - 1)} aria-label="이전 학습 방식">←</button><div>{studyModes.map((mode, index) => <button key={mode.title} type="button" aria-label={`${mode.title} 보기`} aria-current={activeMode === index ? "true" : undefined} onClick={() => selectMode(index)}><span /></button>)}</div><button type="button" onClick={() => selectMode(activeMode + 1)} aria-label="다음 학습 방식">→</button></div>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.aiSection} id="ai" aria-labelledby="ai-title">
          <div className={styles.sectionInner}>
            <div className={styles.aiHeading}>
              <p className={styles.kicker}>선택 기능 · AI 학습</p>
              <h2 id="ai-title"><CopyLines lines={["필요할 때만,", "내 API로 학습을 넓히세요."]} /></h2>
              <p><CopyLines lines={["내 단어장의 뜻과 예문을 보강하고,", "공부 중인 어휘로 단어·문법·독해 문제를 만드세요.", "암기를 넘어 떠올리고 적용하는 학습을 돕습니다."]} /></p>
            </div>
            <div className={styles.aiLayout}>
              <div className={styles.aiCopy}>
                <div className={styles.aiFeatureHeading} aria-live="polite">
                  <AiFeatureIcon feature={selectedAiFeature} />
                  <div><h3>{selectedAiFeature.title}</h3><p>{selectedAiFeature.subtitle}</p></div>
                </div>
                <div ref={aiTabsRef} id="ai-feature-tabs" className={styles.aiFeatureTabs} role="tablist" aria-label="AI 학습 기능 선택" onKeyDown={(event) => tabKeyHandler(event, activeAiFeature, aiFeatures.length, selectAiFeature)}>
                  {aiFeatures.map((feature, index) => (
                    <button
                      id={`ai-feature-tabs-tab-${index}`}
                      key={feature.title}
                      type="button"
                      role="tab"
                      aria-selected={activeAiFeature === index}
                      aria-controls="ai-feature-panel"
                      tabIndex={activeAiFeature === index ? 0 : -1}
                      style={{ "--ai-accent": feature.accent, "--ai-soft-accent": feature.softAccent } as CSSProperties}
                      onClick={() => selectAiFeature(index)}
                    >
                      <AiFeatureIcon feature={feature} />
                      <span className={styles.aiFeatureText}><strong>{feature.title}</strong></span>
                    </button>
                  ))}
                </div>
              </div>
              <div
                id="ai-feature-panel"
                className={styles.aiVisual}
                role="tabpanel"
                aria-labelledby={`ai-feature-tabs-tab-${activeAiFeature}`}
                onTouchStart={(event) => {
                  aiTouchStart.current = null;
                  if ((event.target as HTMLElement).closest("input, button, a")) return;
                  const touch = event.changedTouches[0];
                  if (touch) aiTouchStart.current = { x: touch.clientX, y: touch.clientY };
                }}
                onTouchEnd={(event) => {
                  const start = aiTouchStart.current;
                  const touch = event.changedTouches[0];
                  aiTouchStart.current = null;
                  if (!start || !touch) return;
                  const dx = touch.clientX - start.x;
                  const dy = touch.clientY - start.y;
                  if (Math.abs(dx) >= 48 && Math.abs(dx) > Math.abs(dy) * 1.25) {
                    selectAiFeature(activeAiFeature + (dx < 0 ? 1 : -1));
                  }
                }}
                onTouchCancel={() => { aiTouchStart.current = null; }}
              >
                {activeAiFeature === 0 ? (
                  <BeforeAfterSlider
                    beforeSrc="/media/ai/flashcard-before-example.jpg"
                    afterSrc="/media/ai/flashcard-after-example.jpg"
                    beforeAlt="예문이 아직 보강되지 않은 플래시카드 학습 화면"
                    afterAlt="AI가 예문을 보강한 플래시카드 학습 화면"
                  />
                ) : null}
                {aiFeatures.map((feature, index) => "video" in feature ? (
                  <div key={feature.title} className={styles.aiMediaPanel} hidden={activeAiFeature !== index}>
                    <MotionFrame poster={feature.image} alt={feature.imageAlt} video={feature.video} active={activeAiFeature === index} />
                  </div>
                ) : null)}
                <p className="product-media-caption" aria-live="polite">{selectedAiFeature.caption}</p>
                <div className={styles.carouselControls} aria-label="AI 학습 화면 전환">
                  <button type="button" onClick={() => selectAiFeature(activeAiFeature - 1)} aria-label="이전 AI 학습 기능">←</button>
                  <div>{aiFeatures.map((feature, index) => <button key={feature.title} type="button" aria-label={`${feature.title} 보기`} aria-current={activeAiFeature === index ? "true" : undefined} onClick={() => selectAiFeature(index)}><span /></button>)}</div>
                  <button type="button" onClick={() => selectAiFeature(activeAiFeature + 1)} aria-label="다음 AI 학습 기능">→</button>
                </div>
              </div>
            </div>
          </div>
        </section>


        <section className={styles.faqSection} id="faq" aria-labelledby="faq-title">
          <div className={styles.sectionInner}>
            <div className={styles.faqLayout}><div className={styles.helpPanel}><p className={styles.kicker}>도움말</p><h2><CopyLines lines={["필요한 안내를", "바로 찾아보세요."]} /></h2><p><CopyLines lines={["AI 연결 방법은 전용 가이드에서 확인하고,", "발견한 내용은 의견 게시판에 남겨주세요."]} /></p><a href="/ai-api">AI API 연결 가이드</a><a href="/feedback">의견 게시판</a>{supportEmail ? <a className={styles.emailLink} href={`mailto:${supportEmail}`} aria-label={`이메일 문의: ${supportEmail}`}><MailIcon /><span>{supportEmail}</span></a> : null}</div><div className={styles.faq}><p className={styles.kicker}>자주 묻는 질문</p><h2 id="faq-title">시작 전에 확인하세요.</h2>{productFaqItems.map((item, index) => <details key={item.question} open={index === 0}><summary>{item.question}<b aria-hidden="true" /></summary><p>{item.answerLines ? <CopyLines lines={item.answerLines} /> : item.answer}</p></details>)}</div></div>
          </div>
        </section>

        <section className={styles.finalCta} aria-labelledby="final-title"><div><p className={styles.kicker}>내 단어장으로 시작하기</p><h2 id="final-title"><CopyLines lines={["이미 정리한 단어장으로,", "오늘의 학습을 준비하세요."]} /></h2><p>{liveRelease.releaseStatus === "released" ? "Google Play에서 앱을 설치하고 학습을 시작하세요." : "정식 출시 전에 먼저 경험하거나, 출시 알림을 받아보세요."}</p><div className={styles.finalActions}><ReleaseAction config={liveRelease} onOpen={openEnrollment} />{liveRelease.acceptingTesters ? <ReleaseAction config={liveRelease} onOpen={openEnrollment} secondary /> : null}</div></div></section>
      </div>

      <footer className={styles.footer}><div className={styles.footerInner}><div className={styles.footerBrand}><a className={styles.brand} href="#top"><img src="/app-icon-192.png" width="42" height="42" alt="" /><span>Memorize Me</span></a><p>내 단어장으로 시작하는 학습</p></div><nav aria-label="서비스"><strong>서비스</strong><a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><Link href="/testing">테스트 안내</Link><a href="#faq">FAQ</a></nav><nav aria-label="지원"><strong>지원</strong><a href="/ai-api">AI API 연결 가이드</a><a href="/feedback">의견 게시판</a>{supportEmail ? <a className={styles.emailLink} href={`mailto:${supportEmail}`} aria-label={`이메일 문의: ${supportEmail}`}><MailIcon /><span>{supportEmail}</span></a> : null}</nav><nav aria-label="정책"><strong>정책</strong><a href="/privacy">개인정보 처리방침</a><a href="/account-deletion">계정 삭제 안내</a></nav><div><strong>앱</strong><p>{release.label}</p></div></div><div className={styles.footerBottom}>© 2026 Memorize Me</div></footer>

      {enrollmentMode ? <EnrollmentModal mode={enrollmentMode} config={liveRelease} onClose={() => setEnrollmentMode(null)} /> : null}
    </main>
  );
}
