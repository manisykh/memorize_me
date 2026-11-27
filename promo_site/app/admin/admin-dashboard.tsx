"use client";
import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import type { TesterRecord } from "../../lib/tester-service";
import { FeedbackBoard } from "../feedback/feedback-board";
import { PolicyHeader } from "../policy-header";
import "../legal.css";
import styles from "./admin.module.css";

async function readSession(signal?: AbortSignal) {
  const response = await fetch("/api/tester-applications?view=session", { cache: "no-store", signal });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "관리자 세션을 확인하지 못했습니다.");
  return data.authenticated === true;
}

async function readRecords(signal?: AbortSignal) {
  const response = await fetch("/api/tester-applications", { cache: "no-store", signal });
  if (response.status === 401) return { authenticated: false, records: [] as TesterRecord[] };
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "신청 목록을 불러오지 못했습니다.");
  return { authenticated: true, records: data.records as TesterRecord[] };
}

export function AdminDashboard() {
  const [records, setRecords] = useState<TesterRecord[] | null>(null);
  const [authenticated, setAuthenticated] = useState(false);
  const [checking, setChecking] = useState(true);
  const [activePanel, setActivePanel] = useState<"testers" | "feedback">("testers");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const sessionExpired = useCallback(() => {
    setAuthenticated(false);
    setRecords(null);
    setError("관리자 세션이 종료되었습니다. 다시 로그인해 주세요.");
  }, []);

  useEffect(() => {
    const abort = new AbortController();
    readSession(abort.signal).then((value) => { if (!abort.signal.aborted) setAuthenticated(value); })
      .catch((error) => { if (!abort.signal.aborted) setError(error.message); })
      .finally(() => { if (!abort.signal.aborted) setChecking(false); });
    return () => abort.abort();
  }, []);

  useEffect(() => {
    if (!authenticated || activePanel !== "testers") return;
    const abort = new AbortController();
    readRecords(abort.signal).then((data) => {
      if (abort.signal.aborted) return;
      if (!data.authenticated) { sessionExpired(); return; }
      setRecords(data.records);
    }).catch((error) => { if (!abort.signal.aborted) setError(error.message); });
    return () => abort.abort();
  }, [authenticated, activePanel, sessionExpired]);

  async function load() {
    setBusy(true);
    setError("");
    try {
      const data = await readRecords();
      if (!data.authenticated) { sessionExpired(); return; }
      setRecords(data.records);
    } catch (error) { setError(error instanceof Error ? error.message : "목록을 불러오지 못했습니다."); }
    finally { setBusy(false); }
  }

  async function login(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError("");
    try {
      const response = await fetch("/api/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "admin-login", password }) });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || "로그인하지 못했습니다.");
      if (!(await readSession())) throw new Error("관리자 세션을 확인하지 못했습니다. 다시 로그인해 주세요.");
      setPassword(""); setRecords(null); setAuthenticated(true);
    } catch (error) { setError(error instanceof Error ? error.message : "로그인하지 못했습니다."); }
    finally { setBusy(false); }
  }

  async function update(record: TesterRecord, status?: TesterRecord["status"]) {
    if (!status && !window.confirm("신청 정보와 동의 기록을 삭제할까요? 이 작업은 되돌릴 수 없습니다.")) return;
    setBusy(true); setError("");
    try {
      const response = await fetch("/api/tester-applications", { method: status ? "PATCH" : "DELETE", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: record.id, status }) });
      const data = await response.json();
      if (response.status === 401) { sessionExpired(); return; }
      if (!response.ok) throw new Error(data.error || "처리하지 못했습니다.");
      await load();
    } catch (error) { setError(error instanceof Error ? error.message : "처리하지 못했습니다."); }
    finally { setBusy(false); }
  }

  async function logout() {
    setBusy(true); setError("");
    try {
      const response = await fetch("/api/feedback", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "admin-logout" }) });
      if (!response.ok) throw new Error("로그아웃하지 못했습니다.");
      setRecords(null); setAuthenticated(false);
    } catch (error) { setError(error instanceof Error ? error.message : "연결을 확인해 주세요."); }
    finally { setBusy(false); }
  }

  return <main className="legal-page"><PolicyHeader /><article className={`legal-content ${styles.content}`}>
    <p className="legal-kicker">ADMIN</p><h1>관리자 페이지</h1>
    <p>테스트 신청 계정과 의견 게시판을 한곳에서 관리하세요.</p>
    {error ? <p role="alert" className={styles.error}>{error}</p> : null}
    {checking ? <p role="status">관리자 세션을 확인하고 있습니다…</p> : !authenticated ?
      <form onSubmit={login} className={styles.login}><label>관리자 비밀번호<input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label><button disabled={busy}>관리자 로그인</button></form> :
      <>
        <div className={styles.toolbar}><nav className={styles.panelNav} aria-label="관리 항목"><button type="button" aria-pressed={activePanel === "testers"} onClick={() => { setError(""); setActivePanel("testers"); }}>테스트 계정 관리</button><button type="button" aria-pressed={activePanel === "feedback"} onClick={() => { setError(""); setActivePanel("feedback"); }}>의견 게시판 관리</button></nav><button type="button" disabled={busy} onClick={logout}>로그아웃</button></div>
        {activePanel === "feedback" ? <section aria-labelledby="admin-feedback-title"><h2 id="admin-feedback-title" className={styles.panelHeading}>의견 게시판 관리</h2><p>글을 열어 처리 상태를 바꾸거나 운영자 답변을 남길 수 있습니다.</p><div className={styles.managementBoard}><FeedbackBoard management onSessionExpired={sessionExpired} /></div></section> :
          <section aria-labelledby="admin-testers-title"><h2 id="admin-testers-title" className={styles.panelHeading}>테스트 계정 관리</h2>
            <p>홈페이지에 접수된 테스트 신청·출시 알림 계정을 관리합니다. 앱 회원 계정과 Google Play 테스터 목록을 자동으로 연동하지는 않습니다.</p>
            <p>접수 확인 → Play Console 계정 등록 → 참여 링크 수동 발송 순서로 진행합니다. 실제 참여 여부·기간은 Play Console에서 확인하세요.</p>
            <div className={styles.toolbar}><strong>접수 {records === null ? "—" : records.length}건</strong><button type="button" disabled={busy} onClick={() => void load()}>새로고침</button></div>
            <p>‘등록 완료’와 ‘안내 발송’은 직접 수행한 뒤 변경합니다. 정식 출시 알림은 수신에 동의한 계정에만 보내세요. 테스트 신청 자체는 출시 알림 동의가 아닙니다.</p>
            {records === null ? !error && <p role="status">신청 목록을 불러오고 있습니다…</p> : records.length === 0 ? <p>접수된 신청이 없습니다.</p> : <div className={styles.records}>{records.map((record) =>
              <article key={record.id}><h3>{record.email}</h3><p>{record.mode === "tester" ? "테스트 신청" : "출시 알림"} · {new Date(record.submittedAt).toLocaleString("ko-KR")}</p>
                <p>참여 확인: {record.participationConfirmed ? "동의" : "해당 없음"} · 개인정보 동의: {record.privacyNoticeVersion}</p>
                <p>사용 목적: {({ student: "학생 학습", child: "자녀 학습", teaching: "교육 및 강의", self: "개인 어학 공부", other: "기타" } as Record<string, string>)[record.usePurpose || ""] || "선택하지 않음"} · 출시 알림: {record.releaseNotificationConsent === true ? "수신 동의" : "동의 없음"}</p>
                <p>자동 삭제 기준: {new Date(record.expiresAt).toLocaleString("ko-KR")}</p>
                <div className={styles.toolbar}><label>운영 상태 <select disabled={busy} value={record.status} onChange={(event) => update(record, event.target.value as TesterRecord["status"])}><option value="received">접수</option><option value="registered">등록 완료</option><option value="invited">안내 발송</option></select></label><button type="button" disabled={busy} onClick={() => update(record)}>신청 정보 삭제</button></div>
              </article>)}</div>}
          </section>}
      </>}
  </article></main>;
}
