"use client";

import Link from "next/link";
import { useEffect } from "react";
import "../legal.css";

export function LegacyAdminRedirect() {
  useEffect(() => {
    window.location.replace("/admin");
  }, []);

  return <main className="legal-page"><article className="legal-content">
    <h1>관리자 페이지로 이동합니다.</h1>
    <p>자동으로 이동하지 않으면 <Link href="/admin">관리자 페이지 열기</Link>를 눌러 주세요.</p>
  </article></main>;
}
