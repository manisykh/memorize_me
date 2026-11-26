export const releaseStatuses = ["recruiting", "testing", "reviewing", "released"] as const;
export type ReleaseStatus = typeof releaseStatuses[number];
export type ReleaseConfig = {
  releaseStatus: ReleaseStatus;
  acceptingTesters: boolean;
  minimumParticipationDays: number;
  testerBenefitConfirmed: boolean;
  testerBenefitText: string | null;
  playStoreUrl: string | null;
  feedbackUrl: string;
  supportEmail: string | null;
  privacyConfirmed: boolean;
  retentionDays: number | null;
  privacyNoticeVersion: string;
};

type Environment = Record<string, string | undefined>;

// Tester benefits were explicitly confirmed by the operator on 2026-11-26.
export const confirmedTesterBenefitText = "비공개 테스터에게는 주요 학습 기능의 무료 이용을 포함한 초기 사용자 혜택을 모두 제공하며, 해당 혜택은 평생 유지됩니다. 추후 광고가 도입되어도 광고 없이 이용할 수 있습니다. 다만 향후 Memorize Me가 자체 API로 제공하는 AI 기능은 이 혜택에 포함되지 않습니다. 직접 연결하는 AI API의 비용과 한도는 제공업체 정책을 따릅니다.";

// Central release defaults. Custom benefit copy and privacy terms still need
// explicit operator confirmation rather than becoming approved on deployment.
export function getReleaseConfig(env: Environment = process.env): ReleaseConfig {
  const candidate = env.RELEASE_STATUS;
  let releaseStatus: ReleaseStatus = releaseStatuses.includes(candidate as ReleaseStatus) ? candidate as ReleaseStatus : "recruiting";
  const rawPlayUrl = env.NEXT_PUBLIC_GOOGLE_PLAY_URL?.trim() || "";
  let playStoreUrl: string | null = null;
  try {
    const url = new URL(rawPlayUrl);
    if (url.protocol === "https:" && url.hostname === "play.google.com" && url.pathname === "/store/apps/details" && url.searchParams.get("id")) playStoreUrl = url.href;
  } catch { /* A download button needs a real Play Store URL. */ }
  if (releaseStatus === "released" && !playStoreUrl) releaseStatus = "reviewing";
  const email = env.NEXT_PUBLIC_SUPPORT_EMAIL?.trim() || "";
  const supportEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && !/@example\.(com|org|net)$/i.test(email) ? email : null;
  const days = Number(env.TESTER_RETENTION_DAYS);
  const retentionDays = Number.isInteger(days) && days >= 1 && days <= 730 ? days : null;
  const minimum = Number(env.TESTER_MINIMUM_PARTICIPATION_DAYS || 14);
  const testerBenefitText = env.TESTER_BENEFIT_TEXT?.trim() || confirmedTesterBenefitText;
  const testerBenefitConfirmed = env.TESTER_BENEFIT_CONFIRMED === "true" || (env.TESTER_BENEFIT_CONFIRMED === undefined && testerBenefitText === confirmedTesterBenefitText);
  return {
    releaseStatus,
    acceptingTesters: releaseStatus !== "released" && (env.ACCEPTING_TESTERS === "true" || (env.ACCEPTING_TESTERS === undefined && releaseStatus === "recruiting")),
    minimumParticipationDays: Number.isInteger(minimum) && minimum > 0 ? minimum : 14,
    testerBenefitConfirmed,
    testerBenefitText,
    playStoreUrl,
    feedbackUrl: "/feedback",
    supportEmail,
    privacyConfirmed: env.TESTER_PRIVACY_CONFIRMED === "true" && Boolean(retentionDays && supportEmail),
    retentionDays,
    // Keep the actual retention/participation terms traceable in each consent.
    privacyNoticeVersion: `${env.TESTER_PRIVACY_NOTICE_VERSION?.trim() || "2026-11-26.v1"};retention=${retentionDays ?? "pending"};participation=${Number.isInteger(minimum) && minimum > 0 ? minimum : 14}`,
  };
}

export function releasePresentation(config: ReleaseConfig) {
  const labels: Record<ReleaseStatus, string> = {
    recruiting: "Android · 비공개 테스터 모집 중",
    testing: "Android · 비공개 테스트 진행 중",
    reviewing: "Google Play 출시 승인 및 심사 진행 중",
    released: "Google Play 정식 출시",
  };
  return {
    label: config.releaseStatus === "recruiting" && !config.acceptingTesters ? "Android · 비공개 테스터 모집 마감" : config.acceptingTesters && config.releaseStatus !== "recruiting" ? `${labels[config.releaseStatus]} · 테스터 추가 모집` : labels[config.releaseStatus],
    primary: config.releaseStatus === "released" ? "Google Play에서 다운로드" : config.acceptingTesters ? "테스터 신청하기" : "출시 알림 받기",
    stage: releaseStatuses.indexOf(config.releaseStatus),
  };
}

export function privacyNotice(config: ReleaseConfig, mode: "tester" | "notification") {
  return {
    purpose: mode === "tester" ? "비공개 테스트 신청 접수, 테스터 등록 및 참여 방법 안내" : "정식 출시 알림 발송",
    items: mode === "tester" ? "Google 계정 이메일, 참여 확인·필수 동의 기록, 선택한 사용 목적 및 출시 알림 동의" : "이메일 및 출시 알림·개인정보 동의 기록",
    retention: config.retentionDays ? `신청일로부터 ${config.retentionDays}일 보관하며, 기한 도래 후 1시간 이내 자동 삭제합니다. 출시 알림 동의 정보에도 같은 기한을 적용합니다. 삭제·동의 철회 요청 시에는 확인 후 삭제합니다.` : "개인정보 보관 기준을 확인한 후 신청 접수를 시작합니다.",
  };
}
