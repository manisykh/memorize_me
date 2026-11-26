"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { ReleaseConfig } from "../../lib/site-release";
import { releasePresentation } from "../../lib/site-release";
import { EnrollmentModal, ReleaseAction, TestingFaq, TestingSection, type EnrollmentMode } from "../testing-enrollment";
import styles from "../home-v2.module.css";
import testing from "../testing.module.css";

export function TestingGuide({ releaseConfig }: { releaseConfig: ReleaseConfig }) {
  const [config, setConfig] = useState(releaseConfig);
  const [menuOpen, setMenuOpen] = useState(false);
  const [enrollmentMode, setEnrollmentMode] = useState<EnrollmentMode | null>(null);
  const release = releasePresentation(config);

  useEffect(() => {
    const abort = new AbortController();
    void fetch("/api/tester-applications?view=config", { cache: "no-store", signal: abort.signal }).then((response) => response.ok ? response.json() : null).then((data) => { if (data?.config) setConfig(data.config); }).catch(() => undefined);
    return () => abort.abort();
  }, []);

  useEffect(() => {
    const close = (event: KeyboardEvent) => { if (event.key === "Escape") setMenuOpen(false); };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, []);

  useEffect(() => {
    if (!menuOpen) return;
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = overflow; };
  }, [menuOpen]);

  const links = <>
    <a href="#closed-testing" onClick={() => setMenuOpen(false)}>참여 안내</a>
    <a href="#testing-faq" onClick={() => setMenuOpen(false)}>테스트 FAQ</a>
    <Link className={styles.headerPageButton} href="/">홈으로 돌아가기</Link>
    <Link className={`${styles.headerPageButton} ${styles.headerPageButtonPrimary}`} href={config.feedbackUrl}>의견 게시판</Link>
  </>;

  return <main className={`${styles.page} ${testing.guidePage}`} id="testing-top">
    <a className={styles.skipLink} href="#closed-testing">본문으로 건너뛰기</a>
    <header className={styles.header}>
      <div className={styles.headerInner}>
        <Link className={styles.brand} href="/" aria-label="Memorize Me 홈으로 이동"><img src="/app-icon-192.png" width="42" height="42" alt="" /><span>Memorize Me</span></Link>
        <nav className={styles.desktopNav} aria-label="테스트 안내 메뉴">{links}</nav>
        <button className={styles.menuButton} type="button" aria-expanded={menuOpen} aria-controls="testing-mobile-menu" onClick={() => setMenuOpen((value) => !value)}><span aria-hidden="true">{menuOpen ? "×" : "☰"}</span><span className={styles.srOnly}>{menuOpen ? "메뉴 닫기" : "메뉴 열기"}</span></button>
      </div>
      {menuOpen ? <nav id="testing-mobile-menu" className={styles.mobileMenu} aria-label="테스트 안내 모바일 메뉴">{links}</nav> : null}
    </header>

    <TestingSection config={config} onOpen={setEnrollmentMode} />
    <section className={testing.guideFaq} aria-labelledby="testing-faq-title">
      <div className={styles.sectionInner}><div className={styles.faq}><TestingFaq config={config} /></div>
        <div className={testing.actions}><ReleaseAction config={config} onOpen={setEnrollmentMode} />{config.releaseStatus !== "released" && config.acceptingTesters ? <ReleaseAction config={config} onOpen={setEnrollmentMode} secondary /> : null}</div>
      </div>
    </section>
    <footer className={testing.guideFooter}><div className={testing.guideFooterInner}><span>{release.label}</span><nav aria-label="테스트 안내 하단 메뉴"><Link href="/">홈으로 돌아가기</Link><Link href="/privacy">개인정보 처리방침</Link><Link href={config.feedbackUrl}>의견 게시판</Link></nav></div></footer>
    {enrollmentMode ? <EnrollmentModal mode={enrollmentMode} config={config} onClose={() => setEnrollmentMode(null)} /> : null}
  </main>;
}
