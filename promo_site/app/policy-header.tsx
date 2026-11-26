"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import styles from "./home-v2.module.css";

export function PolicyHeader({ current }: { current?: "privacy" | "account-deletion" }) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const close = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", close);
    return () => window.removeEventListener("keydown", close);
  }, [open]);

  const links = <>
    <Link href="/privacy" aria-current={current === "privacy" ? "page" : undefined} onClick={() => setOpen(false)}>개인정보 처리방침</Link>
    <Link href="/account-deletion" aria-current={current === "account-deletion" ? "page" : undefined} onClick={() => setOpen(false)}>계정 삭제 안내</Link>
    <Link className={styles.headerPageButton} href="/">홈으로 돌아가기</Link>
    <Link className={`${styles.headerPageButton} ${styles.headerPageButtonPrimary}`} href="/feedback">의견 게시판</Link>
  </>;

  return <header className={styles.header}>
    <div className={styles.headerInner}>
      <Link className={styles.brand} href="/" aria-label="Memorize Me 홈으로 이동">
        <img src="/app-icon-192.png" width="42" height="42" alt="" />
        <span>Memorize Me</span>
      </Link>
      <nav className={styles.desktopNav} aria-label="정책 페이지 메뉴">{links}</nav>
      <button className={styles.menuButton} type="button" aria-expanded={open} aria-controls="policy-mobile-menu" onClick={() => setOpen((value) => !value)}>
        <span aria-hidden="true">{open ? "×" : "☰"}</span>
        <span className={styles.srOnly}>{open ? "메뉴 닫기" : "메뉴 열기"}</span>
      </button>
    </div>
    {open ? <nav id="policy-mobile-menu" className={styles.mobileMenu} aria-label="정책 페이지 모바일 메뉴">{links}</nav> : null}
  </header>;
}
