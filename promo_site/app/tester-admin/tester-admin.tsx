"use client";
import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import type { TesterRecord } from "../../lib/tester-service";
import { PolicyHeader } from "../policy-header";
import "../legal.css";
import styles from "./tester-admin.module.css";

async function readRecords(signal?: AbortSignal) {
  const response = await fetch("/api/tester-applications", { cache: "no-store", signal });
  if (response.status === 401) return { authenticated: false, records: [] as TesterRecord[] };
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "신청 목록을 불러오지 못했습니다.");
  return { authenticated: true, records: data.records as TesterRecord[] };
}

export function TesterAdmin() {
  const [records, setRecords] = useState<TesterRecord[]>([]);
  const [authenticated, setAuthenticated] = useState(false);
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function load() {
    const data = await readRecords();
    setAuthenticated(data.authenticated); setRecords(data.records);
  }
  useEffect(() => {
    const abort = new AbortController();
    readRecords(abort.signal).then((data) => { setAuthenticated(data.authenticated); setRecords(data.records); }).catch((error) => { if (!abort.signal.aborted) setError(error.message); });
    return () => abort.abort();
  }, []);
  async function login(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError("");
    try {
      const response = await fetch("/api/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "admin-login", password }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "로그인하지 못했습니다.");
      setPassword(""); await load();
    } catch (error) { setError(error instanceof Error ? error.message : "로그인하지 못했습니다."); }
    finally { setBusy(false); }
  }
  async function update(record: TesterRecord, status?: TesterRecord["status"]) {
    if (!status && !window.confirm("신청 정보와 동의 기록을 삭제할까요? 이 작업은 되돌릴 수 없습니다.")) return;
    setBusy(true); setError("");
    try {
      const response = await fetch("/api/tester-applications", { method: status ? "PATCH" : "DELETE", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: record.id, status }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "처리하지 못했습니다.");
      await load();
    } catch (error) { setError(error instanceof Error ? error.message : "처리하지 못했습니다."); }
    finally { setBusy(false); }
  }
  async function logout() {
    setBusy(true);
    try {
      const response = await fetch("/api/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "admin-logout" }) });
      if (!response.ok) throw new Error("로그아웃하지 못했습니다.");
      setRecords([]); setAuthenticated(false);
    } catch (error) { setError(error instanceof Error ? error.message : "연결을 확인해 주세요."); }
    finally { setBusy(false); }
  }
  return <main className="legal-page"><PolicyHeader /><article className={`legal-content ${styles.content}`}><p className="legal-kicker">TESTER ADMIN</p><h1>테스트 신청 관리</h1><p>접수 확인 → Play Console 계정 등록 → 참여 링크 수동 발송 순서로 진행합니다. 실제 참여 여부·기간은 Play Console에서 확인하세요.</p>{error ? <p role="alert" className={styles.error}>{error}</p> : null}
    {!authenticated ? <form onSubmit={login} className={styles.login}><label>관리자 비밀번호<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label><button disabled={busy}>관리자 로그인</button></form> : <><div className={styles.toolbar}><strong>접수 {records.length}건</strong><button disabled={busy} onClick={() => { setError(""); load().catch((error) => setError(error.message)); }}>새로고침</button><button disabled={busy} onClick={logout}>로그아웃</button></div><p>‘등록 완료’와 ‘안내 발송’은 운영자가 직접 수행한 뒤 변경합니다. 출시 알림은 동의한 신청에만 보내고, 목적이 끝난 정보는 삭제하세요.</p><div className={styles.records}>{records.map((record) => <article key={record.id}><h2>{record.email}</h2><p>{record.mode === "tester" ? "테스트 신청" : "출시 알림"} · {new Date(record.submittedAt).toLocaleString("ko-KR")}</p><p>사용 목적: {record.usePurpose || "미선택"} · 참여 확인: {record.participationConfirmed ? "동의" : "해당 없음"}</p><p>출시 알림: {record.releaseNotificationConsent ? "동의" : "미동의"} · 개인정보 동의: {record.privacyNoticeVersion}</p><p>자동 삭제 기준: {new Date(record.expiresAt).toLocaleString("ko-KR")}</p><div className={styles.toolbar}><label>운영 상태 <select disabled={busy} value={record.status} onChange={(event) => update(record, event.target.value as TesterRecord["status"])}><option value="received">접수</option><option value="registered">등록 완료</option><option value="invited">안내 발송</option></select></label><button disabled={busy} onClick={() => update(record)}>신청 정보 삭제</button></div></article>)}</div></>}
  </article></main>;
}
