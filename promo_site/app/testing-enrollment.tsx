"use client";

import { useEffect, useRef, useState } from "react";
import type { FormEvent, ReactNode } from "react";
import { privacyNotice, releasePresentation, type ReleaseConfig } from "../lib/site-release";
import styles from "./home-v2.module.css";
import testing from "./testing.module.css";

export type EnrollmentMode = "tester" | "notification";

export function ReleaseAction({ config, onOpen, secondary = false }: { config: ReleaseConfig; onOpen: (mode: EnrollmentMode) => void; secondary?: boolean }) {
  const presentation = releasePresentation(config);
  if (config.releaseStatus === "released" && config.playStoreUrl && !secondary) {
    return <a className={styles.primaryCta} href={config.playStoreUrl} target="_blank" rel="noreferrer">{presentation.primary}</a>;
  }
  const mode = secondary || !config.acceptingTesters ? "notification" : "tester";
  return <button type="button" className={secondary ? testing.secondaryButton : mode === "tester" ? testing.testerCta : styles.primaryCta} onClick={() => onOpen(mode)}>{secondary ? "출시 알림 받기" : presentation.primary}</button>;
}

export function TestingSection({ config, onOpen }: { config: ReleaseConfig; onOpen: (mode: EnrollmentMode) => void }) {
  const presentation = releasePresentation(config);
  const steps = [
    ["테스터 모집", "Google Play에서 사용하는 Google 계정으로 신청해 주세요."],
    ["비공개 테스트", `안내받은 링크에서 참여에 동의하고 앱을 설치해 최소 ${config.minimumParticipationDays}일 동안 참여 상태를 유지합니다.`],
    ["개선 및 심사", "여러분의 의견을 반영하고 Google Play 승인·심사 절차를 진행합니다."],
    ["정식 출시", "승인과 출시 심사가 완료되면 Google Play에서 정식 버전을 공개합니다."],
  ];
  return <section id="closed-testing" className={testing.section} aria-labelledby="testing-title">
    <div className={styles.sectionInner}>
      <div className={styles.sectionHeading}>
        <p className={styles.kicker}>{config.releaseStatus === "released" ? "Google Play 정식 출시" : "출시 전 사전 체험"}</p>
        <h1 id="testing-title">{config.releaseStatus === "released" ? <>이제 Google Play에서<br />Memorize Me를 만나보세요.</> : <>정식 출시 전,<br />Memorize Me를 만나보세요.</>}</h1>
        <p className={testing.intro}>{config.releaseStatus === "released" ? "테스트에 함께해 주셔서 감사합니다. 나만의 단어장으로 학습과 복습을 시작하세요." : config.acceptingTesters ? "더 나은 단어 학습 경험을 만들기 위해 비공개 테스터를 모집합니다. 나만의 단어장으로 먼저 학습하고, 느낀 점과 개선 의견을 들려주세요." : "현재 테스터 모집은 종료되었습니다. 테스트와 개선을 진행하고 있으며, 출시 소식을 받아보실 수 있습니다."}</p>
      </div>
      <div className={testing.actions}><ReleaseAction config={config} onOpen={onOpen} /><a className={testing.inlineLink} href="#testing-faq">테스트 FAQ</a></div>
      {config.releaseStatus !== "released" ? <>
        <dl className={testing.requirements}>
          <div><dt>참여 대상</dt><dd>Android 기기와 Google 계정을 보유한 사용자</dd></div>
          <div><dt>참여 기간</dt><dd>Google Play 참여 동의 후 최소 {config.minimumParticipationDays}일</dd></div>
          <div><dt>체험 기능</dt><dd>단어장 가져오기·플래시카드·퀴즈·복습</dd></div>
          <div><dt>함께 할 일</dt><dd>실제 학습에 활용하고 <a href={config.feedbackUrl}>오류·개선 의견 남기기</a></dd></div>
        </dl>
        <p className={testing.note}>어린이는 Family Link 등 계정 설정에 따라 보호자 동의가 필요할 수 있습니다.</p>
        <div className={testing.benefits}><strong>{config.testerBenefitConfirmed ? "테스터 혜택은 평생 이어집니다." : "먼저 경험하고, 함께 개선해요."}</strong><p>내 단어장으로 앱을 체험하고, 여러분의 의견을 제품 개선에 더할 수 있습니다.</p>{config.testerBenefitConfirmed && config.testerBenefitText ? <p>{config.testerBenefitText}</p> : null}</div>
      </> : null}
      <ol className={testing.roadmap} aria-label="테스트 및 정식 출시 로드맵">
        {steps.map(([title, body], index) => <li key={title} aria-current={presentation.stage === index ? "step" : undefined}><span className={testing.stepNumber}>{String(index + 1).padStart(2, "0")}</span><h3>{title}</h3>{presentation.stage === index ? <span className={testing.currentStep}>현재 단계</span> : null}<p>{body}</p></li>)}
      </ol>
      <p className={testing.note}>정식 출시 일정은 테스트 진행 상황과 Google Play 심사 결과에 따라 달라질 수 있습니다.</p>
    </div>
  </section>;
}

export function TestingFaq({ config }: { config: ReleaseConfig }) {
  const questions: [string, ReactNode][] = [
    ["비공개 테스트란 무엇인가요?", "정식 출시 전에 앱을 직접 사용하고 오류와 개선 의견을 전달하는 프로그램입니다."],
    ["누구나 참여할 수 있나요?", "Android 기기와 Google 계정이 있으면 누구나 테스트를 신청할 수 있습니다. 어린이는 Family Link 등 계정 설정에 따라 보호자 동의가 필요할 수 있습니다."],
    ["신청하면 바로 설치할 수 있나요?", <>신청 계정을 테스터 목록에 등록한 뒤 이메일로 참여 링크를 안내합니다. 그 링크에서 Google Play 테스트 참여에 동의한 후 설치할 수 있습니다.<br />신청 접수만으로 참여 기간이 시작되지는 않습니다.</>],
    ["테스트 기간은 얼마나 되나요?", `Google Play에서 참여에 동의한 후 최소 ${config.minimumParticipationDays}일 동안 참여 상태를 유지해 주세요. 테스트 상황에 따라 연장될 수 있습니다.`],
    ["매일 앱을 사용해야 하나요?", "매일 앱을 사용하는 것이 필수는 아닙니다. 다만 꾸준히 학습에 활용하고 사용 의견을 들려주시면 앱을 개선하는 데 큰 도움이 됩니다."],
    ["오류나 개선 의견은 어디에 전달하나요?", "의견 게시판 또는 문의 이메일로 전달해 주세요. 기기·앱 버전·재현 절차를 적되 API 키나 비밀번호는 적지 마세요."],
    ["정식 출시는 언제인가요?", config.releaseStatus === "released" ? "Google Play에서 정식 버전을 다운로드할 수 있습니다." : "비공개 테스트, 앱 개선과 Google Play 승인·심사 이후 출시 일정을 안내합니다."],
    ["iPhone에서도 참여할 수 있나요?", "현재 테스트는 Android 기기를 대상으로 합니다. iOS 지원은 추후 검토할 예정입니다."],
    ["테스터에게 어떤 혜택이 있나요?", config.testerBenefitConfirmed && config.testerBenefitText ? config.testerBenefitText : "정식 출시 전에 앱을 체험하고 개선 과정에 참여할 수 있습니다. 추가 혜택은 확정 후 안내합니다."],
  ];
  return <div id="testing-faq" className={testing.faqGroup}><h2 id="testing-faq-title">테스트 참여 FAQ</h2>{questions.map(([question, answer]) => <details key={question}><summary>{question}<b aria-hidden="true" /></summary><p>{answer}</p></details>)}</div>;
}

export function EnrollmentModal({ mode, config, onClose }: { mode: EnrollmentMode; config: ReleaseConfig; onClose: () => void }) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const emailRef = useRef<HTMLInputElement>(null);
  const [email, setEmail] = useState("");
  const [purpose, setPurpose] = useState("");
  const [notification, setNotification] = useState(false);
  const [participation, setParticipation] = useState(false);
  const [privacy, setPrivacy] = useState(false);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState("");
  const websiteRef = useRef<HTMLInputElement>(null);
  const isTester = mode === "tester";
  const notice = privacyNotice(config, mode);
  const accepting = !isTester || config.acceptingTesters;

  useEffect(() => {
    const previousFocus = document.activeElement as HTMLElement | null;
    const previousOverflow = document.body.style.overflow;
    const dialog = dialogRef.current;
    dialog?.showModal();
    document.body.style.overflow = "hidden";
    emailRef.current?.focus();
    return () => {
      dialog?.close();
      document.body.style.overflow = previousOverflow;
      previousFocus?.focus({ preventScroll: true });
    };
  }, []);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy || !accepting || !config.privacyConfirmed) return;
    const next: Record<string,string> = {};
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim()) || email.trim().length > 254) next.email = "올바른 이메일 주소를 입력해 주세요.";
    if (isTester && !participation) next.participation = "테스트 참여 조건을 확인해 주세요.";
    if (!privacy) next.privacy = "개인정보 수집·이용 안내를 확인해 주세요.";
    setErrors(next);
    if (Object.keys(next).length) { document.getElementById(`enroll-${Object.keys(next)[0]}`)?.focus(); return; }
    setBusy(true);
    setFormError("");
    try {
      const response = await fetch("/api/tester-applications", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email, usePurpose: isTester ? purpose : "", participationConfirmed: participation, privacyConsent: privacy, releaseNotificationConsent: !isTester || notification, privacyNoticeVersion: config.privacyNoticeVersion, mode, website: websiteRef.current?.value || "" }) });
      const result = await response.json().catch(() => null);
      if (!response.ok || !result?.ok) throw new Error(typeof result?.error === "string" ? result.error : "신청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.");
      setDone(true);
    } catch (error) { setFormError(error instanceof TypeError ? "신청을 완료하지 못했습니다. 네트워크 연결을 확인한 뒤 다시 시도해 주세요." : error instanceof Error ? error.message : "신청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요."); }
    finally { setBusy(false); }
  }

  return <dialog ref={dialogRef} className={testing.modal} aria-labelledby="enrollment-title" aria-describedby="enrollment-description" onCancel={(event) => { event.preventDefault(); onClose(); }}>
    <header className={testing.modalHeader}>
      <div><p className={testing.modalKicker}>Memorize Me · {isTester ? "출시 전 사전 체험" : "새로운 소식"}</p><h2 id="enrollment-title">{done ? "신청이 접수되었습니다" : isTester ? "비공개 테스터 신청" : "정식 출시 알림 신청"}</h2></div>
      <button type="button" className={testing.closeButton} onClick={onClose} aria-label="신청 창 닫기"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg></button>
      <p id="enrollment-description" aria-live="polite">{done ? isTester ? "테스터 등록 후 이메일로 참여 방법을 안내합니다. Google Play 참여 링크에서 동의한 뒤 테스트 기간이 시작됩니다." : "입력하신 이메일로 정식 출시 소식을 안내해 드립니다." : isTester ? "먼저 써 보고, 더 나은 학습 경험을 함께 만들어요." : "정식 출시 소식을 이메일로 받아보세요."}</p>
    </header>
    {done ? <div className={testing.successActions}><button className={testing.submitButton} type="button" onClick={onClose}>확인</button></div> : <form noValidate onSubmit={submit} aria-busy={busy}>
      {!accepting ? <div role="status" className={testing.statusNotice}><span className={testing.infoIcon} aria-hidden="true">i</span><p><strong>현재 테스터 모집이 종료되었어요.</strong><span>출시 알림으로 다음 소식을 받아보세요.</span></p></div> : null}
      {!config.privacyConfirmed ? <div role="status" className={testing.statusNotice}><span className={testing.infoIcon} aria-hidden="true">i</span><p><strong>신청 접수를 준비하고 있어요.</strong><span>개인정보 수집·보관 안내가 확정되면 신청할 수 있어요.</span></p></div> : null}
      <label className={testing.field} htmlFor="enroll-email"><span className={testing.fieldLabel}>{isTester ? "Google 계정 이메일" : "이메일"}<span className={testing.requiredLabel}>필수</span></span><input ref={emailRef} id="enroll-email" aria-required="true" type="email" autoComplete="email" inputMode="email" placeholder="이메일 주소를 입력해 주세요" maxLength={254} value={email} onChange={(event) => setEmail(event.target.value)} aria-invalid={Boolean(errors.email)} aria-describedby="email-help email-error" /><small id="email-help">{isTester ? "Google Play에서 쓰는 계정 · Gmail 이외 주소도 가능해요." : "출시 소식을 받을 이메일을 입력해 주세요."}</small><small id="email-error" className={testing.fieldError}>{errors.email}</small></label>
      <div className={testing.honeypot} aria-hidden="true"><label>Website<input ref={websiteRef} name="website" tabIndex={-1} autoComplete="off" /></label></div>
      {isTester ? <label className={testing.field}><span className={testing.fieldLabel}>주요 사용 목적<span className={testing.optionalLabel}>선택</span></span><select value={purpose} onChange={(event) => setPurpose(event.target.value)}><option value="">선택하지 않음</option><option value="student">학생 학습</option><option value="child">자녀 학습</option><option value="teaching">교육 및 강의</option><option value="self">개인 어학 공부</option><option value="other">기타</option></select><small>선택하지 않아도 신청할 수 있어요. 선택한 항목은 학습 수요 파악에 사용합니다.</small></label> : null}
      {isTester ? <div className={testing.participationSection}><label className={testing.check}><input id="enroll-participation" aria-required="true" type="checkbox" checked={participation} onChange={(event) => setParticipation(event.target.checked)} aria-invalid={Boolean(errors.participation)} aria-describedby="participation-error" /><span><span className={testing.checkTitle}>최소 {config.minimumParticipationDays}일 동안 참여할 수 있어요.<span className={testing.requiredLabel}>필수</span></span><small>Android 기기에서 테스트 참여 상태를 유지하고 앱을 사용합니다.</small></span></label><small id="participation-error" className={testing.fieldError}>{errors.participation}</small><p className={testing.note}>어린이는 Family Link 등 계정 설정에 따라 보호자 동의가 필요할 수 있습니다.</p></div> : null}
      <details className={testing.privacyNotice}><summary><span>개인정보 수집·이용 안내</span><span className={testing.detailsHint}>자세히 보기<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true"><path d="m6 9 6 6 6-6" /></svg></span></summary><dl><dt>수집 목적</dt><dd>{notice.purpose}</dd><dt>수집 항목</dt><dd>{notice.items}</dd><dt>보관 기간</dt><dd>{notice.retention}</dd><dt>동의 거부·문의</dt><dd>동의를 거부할 수 있으나 신청 접수가 제한됩니다. 삭제·철회는 {config.supportEmail ? <a href={`mailto:${config.supportEmail}`}>{config.supportEmail}</a> : "문의 채널이 확정된 후"} 요청할 수 있습니다.</dd></dl><a href="/privacy#tester-data" target="_blank" rel="noreferrer">개인정보 처리방침 확인 (새 창)</a></details>
      <div className={testing.consentSection}>
        <label className={testing.check}><input id="enroll-privacy" aria-required="true" type="checkbox" checked={privacy} onChange={(event) => setPrivacy(event.target.checked)} aria-invalid={Boolean(errors.privacy)} aria-describedby="privacy-error" /><span className={testing.checkTitle}>개인정보 수집·이용에 동의합니다.<span className={testing.requiredLabel}>필수</span></span></label><small id="privacy-error" className={testing.fieldError}>{errors.privacy}</small>
        {isTester ? <label className={testing.check}><input type="checkbox" checked={notification} onChange={(event) => setNotification(event.target.checked)} /><span><span className={testing.checkTitle}>정식 출시 소식도 받아볼게요.<span className={testing.optionalLabel}>선택</span></span><small>동의하지 않아도 테스트를 신청할 수 있어요.</small></span></label> : <p className={testing.note}>신청 버튼을 누르면 정식 출시 안내 이메일 수신을 신청합니다.</p>}
      </div>
      {formError ? <p role="alert" className={testing.formError}>{formError}</p> : null}
      <footer className={testing.modalFooter}><button className={testing.submitButton} type="submit" disabled={busy || !accepting || !config.privacyConfirmed}>{busy ? "신청을 접수하고 있습니다…" : isTester ? "테스터 신청하기" : "출시 알림 신청하기"}</button><p className={testing.note}>{isTester ? "테스터 등록과 참여 링크 안내는 운영자가 순서대로 진행합니다." : "출시 소식은 동의한 이메일로 안내합니다."}</p></footer>
    </form>}
  </dialog>;
}
