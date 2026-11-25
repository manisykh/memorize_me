"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import styles from "../home-v2.module.css";

export function ApiGuideHeader() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const close = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, [open]);

  const closeMenu = () => setOpen(false);

  return (
    <header className={styles.header}>
      <div className={styles.headerInner}>
        <Link className={styles.brand} href="/" aria-label="Memorize Me 홈으로 이동">
          <img src="/app-icon-192.png" width="42" height="42" alt="" aria-hidden="true" />
          <span>Memorize Me</span>
        </Link>
        <nav className={styles.desktopNav} aria-label="AI API 가이드 목차">
          <a href="#api-top">가이드 소개</a>
          <a href="#api-routes">시작 경로</a>
          <a href="#api-steps">앱 연결 순서</a>
          <a href="#api-errors">오류 해결</a>
          <Link className={styles.headerPageButton} href="/">홈으로 돌아가기</Link>
          <Link className={`${styles.headerPageButton} ${styles.headerPageButtonPrimary}`} href="/feedback">의견 게시판</Link>
        </nav>
        <button className={styles.menuButton} type="button" aria-expanded={open} aria-controls="api-guide-mobile-menu" onClick={() => setOpen((value) => !value)}>
          <span aria-hidden="true">{open ? "×" : "☰"}</span>
          <span className={styles.srOnly}>{open ? "메뉴 닫기" : "메뉴 열기"}</span>
        </button>
      </div>
      {open ? (
        <nav id="api-guide-mobile-menu" className={styles.mobileMenu} aria-label="AI API 가이드 모바일 목차">
          <a href="#api-top" onClick={closeMenu}>가이드 소개</a>
          <a href="#api-routes" onClick={closeMenu}>시작 경로</a>
          <a href="#api-steps" onClick={closeMenu}>앱 연결 순서</a>
          <a href="#api-errors" onClick={closeMenu}>오류 해결</a>
          <Link className={styles.headerPageButton} href="/" onClick={closeMenu}>홈으로 돌아가기</Link>
          <Link className={`${styles.headerPageButton} ${styles.headerPageButtonPrimary}`} href="/feedback" onClick={closeMenu}>의견 게시판</Link>
        </nav>
      ) : null}
    </header>
  );
}
