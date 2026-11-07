"use client";

import { useEffect, useRef, useState } from "react";
import { faqItems, journeySteps, studyModes, type JourneyKey } from "./home-content";
import styles from "./home-v2.module.css";

type HomeLandingProps = {
  googlePlayUrl?: string;
  supportEmail?: string;
};

function PrimaryCta({ googlePlayUrl, compact = false }: { googlePlayUrl?: string; compact?: boolean }) {
  const label = googlePlayUrl ? "Google Play에서 받기" : "사용자 가이드 보기";
  return (
    <a
      className={`${styles.primaryCta} ${compact ? styles.compactCta : ""}`}
      href={googlePlayUrl || "/manual"}
      target={googlePlayUrl ? "_blank" : undefined}
      rel={googlePlayUrl ? "noreferrer" : undefined}
      aria-label={label}
    >
      {label}
    </a>
  );
}

export function HomeLanding({ googlePlayUrl, supportEmail }: HomeLandingProps) {
  const [menuOpen, setMenuOpen] = useState(false);
  const [activeJourney, setActiveJourney] = useState<JourneyKey>("learn");
  const [activeMode, setActiveMode] = useState(0);
  const [lightboxImage, setLightboxImage] = useState<{ src: string; alt: string; label: string } | null>(null);
  const journeyCarouselRef = useRef<HTMLDivElement>(null);
  const modeCarouselRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      setMenuOpen(false);
      setLightboxImage(null);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  useEffect(() => {
    if (!lightboxImage) return;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [lightboxImage]);

  const closeMenu = () => setMenuOpen(false);
  const selectJourney = (key: JourneyKey) => {
    const index = journeySteps.findIndex((step) => step.key === key);
    setActiveJourney(key);
    const carousel = journeyCarouselRef.current;
    if (!carousel || index < 0) return;
    carousel.scrollTo({ left: carousel.clientWidth * index, behavior: "smooth" });
  };

  const syncJourneyFromScroll = () => {
    const carousel = journeyCarouselRef.current;
    if (!carousel || carousel.clientWidth === 0) return;
    const index = Math.max(0, Math.min(journeySteps.length - 1, Math.round(carousel.scrollLeft / carousel.clientWidth)));
    setActiveJourney(journeySteps[index].key);
  };

  const selectMode = (index: number) => {
    setActiveMode(index);
    const carousel = modeCarouselRef.current;
    if (!carousel) return;
    carousel.scrollTo({ left: carousel.clientWidth * index, behavior: "smooth" });
  };

  const syncModeFromScroll = () => {
    const carousel = modeCarouselRef.current;
    if (!carousel || carousel.clientWidth === 0) return;
    const nextIndex = Math.max(0, Math.min(studyModes.length - 1, Math.round(carousel.scrollLeft / carousel.clientWidth)));
    setActiveMode(nextIndex);
  };

  return (
    <main className={styles.page} id="top">
      <header className={styles.header}>
        <a className={styles.brand} href="#top" aria-label="Memorize Me 처음으로">
          <img src="/app-icon.png" alt="" aria-hidden="true" />
          <span>Memorize Me</span>
        </a>

        <nav className={styles.desktopNav} aria-label="주요 메뉴">
          <a href="#difference">핵심 장점</a>
          <a href="#learning">학습 방식</a>
          <a href="#journey">시작 안내</a>
          <a href="#ai">AI 학습</a>
          <a href="#faq">FAQ</a>
          <a className={styles.navCta} href="/manual">사용자 가이드</a>
        </nav>

        <button
          type="button"
          className={styles.menuButton}
          aria-expanded={menuOpen}
          aria-controls="mobile-menu"
          onClick={() => setMenuOpen((value) => !value)}
        >
          {menuOpen ? "닫기" : "메뉴"}
        </button>

        {menuOpen ? (
          <nav id="mobile-menu" className={styles.mobileMenu} aria-label="모바일 메뉴">
            <a href="#difference" onClick={closeMenu}>핵심 장점</a>
            <a href="#learning" onClick={closeMenu}>학습 방식</a>
            <a href="#journey" onClick={closeMenu}>시작 안내</a>
            <a href="#ai" onClick={closeMenu}>AI 학습</a>
            <a href="#faq" onClick={closeMenu}>FAQ·도움</a>
          </nav>
        ) : null}
      </header>

      <section className={styles.hero} aria-labelledby="hero-title">
        <div className={styles.heroCopy}>
          <p className={styles.eyebrow}>YOUR WORDS. ONE LEARNING FLOW.</p>
          <h1 id="hero-title">
            이미 만든 단어장,
            <strong>그대로 외우세요.</strong>
          </h1>
          <p className={styles.heroDescription}>
            구글 시트나 엑셀에 정리한 단어장을 그대로 가져오세요. 카드와 퀴즈로 공부하고,
            학습 결과에 맞춰 필요한 단어를 복습하세요.
          </p>
          <div className={styles.heroActions}>
            <PrimaryCta googlePlayUrl={googlePlayUrl} />
            <a className={styles.secondaryCta} href="/feedback">테스트 중이라면 의견 남기기 <span>→</span></a>
          </div>
          {!googlePlayUrl ? <p className={styles.releaseNote}><span />Android · Google Play 출시 준비 중</p> : null}
        </div>

        <button
          type="button"
          className={styles.heroScreen}
          onClick={() => setLightboxImage({
            src: "/media/current-20261107/home-progress.jpg",
            alt: "오늘 학습 수량과 진행 현황을 보여주는 최신 Memorize Me 홈 화면",
            label: "오늘 학습",
          })}
          aria-label="최신 Memorize Me 홈 화면 크게 보기"
        >
          <img
            src="/media/current-20261107/home-progress.jpg"
            alt="오늘 학습 수량과 진행 현황을 보여주는 최신 Memorize Me 홈 화면"
          />
          <span>눌러서 크게 보기</span>
        </button>
      </section>

      <section className={styles.benefits} id="difference" aria-label="Memorize Me 주요 장점">
        <article><span>01</span><div><strong>다시 입력하지 않고 가져오기</strong><p>이미 정리한 단어장을 학습에 바로 활용합니다.</p></div></article>
        <article><span>02</span><div><strong>카드와 퀴즈로 확인하기</strong><p>뜻을 알아보는 것에서 직접 답하는 것까지 이어집니다.</p></div></article>
        <article><span>03</span><div><strong>오늘 복습할 단어만 모아보기</strong><p>학습 결과에 맞춰 필요한 단어를 따로 보여줍니다.</p></div></article>
      </section>

      <section className={styles.journey} id="journey" aria-labelledby="journey-title">
        <div className={styles.sectionHeading}>
          <p className={styles.eyebrow}>GET STARTED</p>
          <h2 id="journey-title">처음 시작하는 3단계</h2>
          <p>무엇을 준비하고 어디를 눌러야 하는지, 실제 앱 화면과 함께 확인하세요.</p>
        </div>

        <div className={styles.tabList} role="tablist" aria-label="학습 여정 단계">
          {journeySteps.map((step, index) => (
            <button
              type="button"
              key={step.key}
              role="tab"
              id={`journey-tab-${step.key}`}
              aria-selected={activeJourney === step.key}
              aria-controls={`journey-panel-${step.key}`}
              className={activeJourney === step.key ? styles.activeTab : ""}
              onClick={() => selectJourney(step.key)}
            >
              <span>{index + 1}</span>{step.shortLabel}
            </button>
          ))}
        </div>

        <div
          className={styles.journeyCarousel}
          ref={journeyCarouselRef}
          onScroll={syncJourneyFromScroll}
          aria-label="처음 시작하는 3단계 실제 화면"
        >
          {journeySteps.map((step, index) => (
            <div
              className={styles.journeyPanel}
              role="tabpanel"
              key={step.key}
              id={`journey-panel-${step.key}`}
              aria-labelledby={`journey-tab-${step.key}`}
              aria-hidden={activeJourney !== step.key}
            >
              <div className={styles.journeyCopy}>
                <p className={styles.stepNumber}>{String(index + 1).padStart(2, "0")}</p>
                <h3>{step.title}</h3>
                <p>{step.description}</p>
                <ul>{step.points.map((point) => <li key={point}>{point}</li>)}</ul>
                <a className={styles.guideLink} href={step.guideHref}>이 단계 자세히 보기 <span>→</span></a>
              </div>
              <button
                type="button"
                className={styles.journeyScreen}
                onClick={() => setLightboxImage({ src: step.image, alt: step.imageAlt, label: step.imageLabel })}
                aria-label={`${step.imageLabel} 화면 크게 보기`}
              >
                <img className={step.image.endsWith(".svg") ? styles.containScreen : styles.croppedScreen} src={step.image} alt={step.imageAlt} />
                <span>{step.imageLabel} · 크게 보기</span>
              </button>
            </div>
          ))}
        </div>

        <div className={styles.tabDots} aria-hidden="true">
          {journeySteps.map((step) => <span key={step.key} className={activeJourney === step.key ? styles.activeDot : ""} />)}
        </div>
      </section>

      <section className={styles.learning} id="learning" aria-labelledby="learning-title">
        <div className={styles.sectionHeading}>
          <p className={styles.eyebrow}>LEARN YOUR WAY</p>
          <h2 id="learning-title">외우는 방식은 하나가 아니니까.</h2>
          <p>플래시카드로 익히고, 객관식과 스펠링 퀴즈로 외운 단어를 확인하세요.</p>
        </div>
        <div className={styles.learningValue}>
          <button
            type="button"
            onClick={() => setLightboxImage({ src: "/media/current-20261107/learning-overview.jpg", alt: "플래시카드와 셀프 테스트 및 오답 기록을 보여주는 최신 학습 화면", label: "학습 개요" })}
            aria-label="최신 학습 개요 화면 크게 보기"
          ><img src="/media/current-20261107/learning-overview.jpg" alt="플래시카드와 셀프 테스트 및 오답 기록을 보여주는 최신 학습 화면" /></button>
          <div><p className={styles.eyebrow}>LEARN · CHECK · REVIEW</p><h3>학습 기록이 다음 복습으로 이어집니다.</h3><p>플래시카드와 퀴즈 결과를 한곳에서 확인하고, 다시 볼 오답과 오늘의 복습으로 자연스럽게 이어갈 수 있습니다.</p></div>
        </div>
        <div className={styles.modeShowcase}>
          <div className={styles.modeList} role="tablist" aria-label="학습 방식 선택">
            {studyModes.map((mode, index) => (
              <button
                type="button"
                role="tab"
                aria-selected={activeMode === index}
                className={activeMode === index ? styles.activeMode : ""}
                key={mode.title}
                onClick={() => selectMode(index)}
              >
                <span>{String(index + 1).padStart(2, "0")}</span>
                <div><strong>{mode.title}</strong><p>{mode.body}</p></div>
              </button>
            ))}
          </div>
          <div className={styles.modePhone}>
            <div
              className={styles.modeCarousel}
              ref={modeCarouselRef}
              onScroll={syncModeFromScroll}
              aria-label="학습 방식 실제 화면"
            >
              {studyModes.map((mode) => (
                <button
                  type="button"
                  key={mode.title}
                  onClick={() => setLightboxImage({ src: mode.image, alt: mode.imageAlt, label: mode.title })}
                  aria-label={`${mode.title} 화면 크게 보기`}
                >
                  <img src={mode.image} alt={mode.imageAlt} />
                </button>
              ))}
            </div>
            <div className={styles.modePagination} aria-hidden="true">
              {studyModes.map((mode, index) => <span key={mode.title} className={activeMode === index ? styles.activeModeDot : ""} />)}
            </div>
            <p>화면을 좌우로 넘겨보세요</p>
          </div>
        </div>
        <div className={styles.reviewFeature}>
          <div className={styles.reviewCopy}>
            <p className={styles.eyebrow}>REVIEW, WHEN IT MATTERS</p>
            <h3>오늘 복습할 단어를<br />따로 고르지 않아도 됩니다.</h3>
            <p>학습 결과를 바탕으로 오늘과 앞으로의 복습 일정을 보여주고, 필요한 단어부터 다시 학습할 수 있게 도와줍니다.</p>
          </div>
          <button
            type="button"
            onClick={() => setLightboxImage({ src: "/media/current-20261107/stats-word2.jpg", alt: "기억 현황과 오늘 및 앞으로의 복습 일정을 보여주는 최신 통계 화면", label: "복습 일정" })}
            aria-label="최신 복습 일정 화면 크게 보기"
          ><img src="/media/current-20261107/stats-word2.jpg" alt="기억 현황과 오늘 및 앞으로의 복습 일정을 보여주는 최신 통계 화면" /></button>
        </div>
      </section>

      <section className={styles.aiSection} id="ai" aria-labelledby="ai-title">
        <div className={styles.aiCopy}>
          <p className={styles.eyebrow}>OPTIONAL · AI LEARNING</p>
          <h2 id="ai-title">필요할 때만,<br />AI로 학습을 확장하세요.</h2>
          <p>기본 학습은 AI 연결 없이 사용할 수 있습니다. 개인 API를 연결하면 내 단어장에 뜻과 예문을 보강하고 난이도별 단어·문법·독해 문제를 만들 수 있습니다.</p>
          <ul><li>뜻·예문 보강</li><li>난이도별 문제 생성</li><li>PDF·HTML 시험지 내보내기</li></ul>
          <div className={styles.aiActions}><a href="/ai-api">AI API 연결 가이드</a><a href="/manual#ai">AI 학습 기능 보기</a></div>
          <p className={styles.aiNotice}>AI 기능에는 직접 발급한 API 키가 필요합니다. 이용 요금은 연결한 서비스의 정책에 따르며, 무료 이용에는 사용량 제한이나 응답 지연이 있을 수 있습니다.</p>
        </div>
        <div className={styles.aiVisual}>
          <img src="/media/latest/ai-learning.png" alt="최신 Memorize Me AI 학습 화면" />
        </div>
      </section>

      <section className={styles.trustFaq} id="faq" aria-labelledby="faq-title">
        <aside className={styles.helpPanel} aria-label="도움말과 의견">
          <p className={styles.eyebrow}>NEED HELP?</p>
          <h2>더 자세한 사용법이 필요한가요?</h2>
          <p>구체적인 조작은 사용자 가이드에서 확인하고, 테스트 중 발견한 내용은 의견 게시판에 남겨주세요.</p>
          <div><a href="/manual">사용자 가이드 <span>→</span></a><a href="/feedback">테스터 의견 게시판 <span>→</span></a></div>
        </aside>
        <div className={styles.faq}>
          <p className={styles.eyebrow}>BEFORE YOU START</p>
          <h2 id="faq-title">자주 묻는 질문</h2>
          {faqItems.map((item, index) => (
            <details key={item.question} open={index === 0}>
              <summary>{item.question}<span aria-hidden="true">＋</span></summary>
              <p>{item.answer}</p>
            </details>
          ))}
        </div>
      </section>

      <section className={styles.finalCta} id="participate" aria-labelledby="participate-title">
        <p className={styles.eyebrow}>START WITH YOUR WORDS</p>
        <h2 id="participate-title">내 단어장으로 공부하는 방법을<br />미리 확인하세요.</h2>
        <p>{googlePlayUrl ? "Google Play에서 앱을 설치하고 내 단어장으로 학습을 시작하세요." : "Google Play 출시 전에는 최신 사용자 가이드로 가져오기·학습·복습 방법을 확인할 수 있습니다."}</p>
        <div className={styles.finalActions}>
          <PrimaryCta googlePlayUrl={googlePlayUrl} />
          <a className={styles.secondaryCta} href="/feedback">테스트 중이라면 의견 남기기 <span>→</span></a>
        </div>
        {supportEmail ? <a className={styles.supportEmail} href={`mailto:${supportEmail}`}>문의 {supportEmail}</a> : null}
      </section>

      <footer className={styles.footer}>
        <a className={styles.brand} href="#top"><img src="/app-icon.png" alt="" aria-hidden="true" /><span>Memorize Me</span></a>
        <nav aria-label="정책 및 지원"><a href="/privacy">개인정보 처리방침</a><a href="/account-deletion">계정 삭제</a><a href="/manual">사용 가이드</a><a href="/feedback">테스터 게시판</a></nav>
        <p>© 2026 Memorize Me</p>
      </footer>

      {lightboxImage ? (
        <div className={styles.lightbox} role="dialog" aria-modal="true" aria-label={`${lightboxImage.label} 화면 확대`} onMouseDown={(event) => { if (event.target === event.currentTarget) setLightboxImage(null); }}>
          <button type="button" onClick={() => setLightboxImage(null)} aria-label="확대 화면 닫기">닫기</button>
          <figure><img src={lightboxImage.src} alt={lightboxImage.alt} /><figcaption>{lightboxImage.label}</figcaption></figure>
        </div>
      ) : null}
    </main>
  );
}
