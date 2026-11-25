"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

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
    <header className="api-guide-header">
      <div className="api-guide-header-inner">
        <Link className="brand" href="/" aria-label="Memorize Me 홈으로 이동">
          <img className="brand-app-icon" src="/app-icon-192.png" alt="" aria-hidden="true" />
          <span>Memorize Me</span>
        </Link>
        <nav className="api-guide-desktop-nav" aria-label="주요 메뉴">
          <Link href="/#journey">시작하기</Link>
          <Link href="/#learning">학습 방식</Link>
          <Link href="/#ai">AI 학습</Link>
          <Link href="/#faq">FAQ</Link>
          <a className="api-guide-current-link" href="#api-top" aria-current="page">AI API 연결 가이드</a>
          <Link className="api-guide-feedback-link" href="/feedback">의견 게시판</Link>
        </nav>
        <button className="api-guide-menu-button" type="button" aria-expanded={open} aria-controls="api-guide-mobile-menu" onClick={() => setOpen((value) => !value)}>
          <span aria-hidden="true">{open ? "×" : "☰"}</span>
          <span className="api-guide-sr-only">{open ? "메뉴 닫기" : "메뉴 열기"}</span>
        </button>
      </div>
      {open ? (
        <nav id="api-guide-mobile-menu" className="api-guide-mobile-menu" aria-label="모바일 메뉴">
          <Link href="/" onClick={closeMenu}>홈으로 돌아가기</Link>
          <a href="#api-steps" onClick={closeMenu}>AI API 연결 순서</a>
          <a href="#api-errors" onClick={closeMenu}>오류 해결</a>
          <Link className="api-guide-feedback-link" href="/feedback" onClick={closeMenu}>의견 게시판</Link>
        </nav>
      ) : null}
    </header>
  );
}
