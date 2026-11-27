import assert from "node:assert/strict";
import test from "node:test";
import { confirmedTesterBenefitText, getReleaseConfig, privacyNotice, releasePresentation, testerPrivacyDefaults } from "../lib/site-release.ts";
import { createTesterHandler, purgeExpiredTesterData, type PrivateStore, type TesterRecord } from "../lib/tester-service.ts";
import { isTesterAdmin } from "../lib/tester-endpoint.ts";

const env = { RELEASE_STATUS: "recruiting", TESTER_PRIVACY_CONFIRMED: "true", TESTER_RETENTION_DAYS: "90", NEXT_PUBLIC_SUPPORT_EMAIL: "support@memorize.test", FEEDBACK_SESSION_SECRET: "fixture-secret-only-do-not-use-in-production" };
function fixture(overrides = {}) {
  const data = new Map<string,{data: unknown; etag: string}>();
  let version = 0;
  const store: PrivateStore = {
    async read(key) { return data.get(key) || null; },
    async write(key, value, condition) {
      const current = data.get(key);
      if ("onlyIfNew" in condition ? Boolean(current) : current?.etag !== condition.onlyIfMatch) return false;
      data.set(key, { data: structuredClone(value), etag: String(++version) }); return true;
    },
    async keys(prefix) { return [...data.keys()].filter((key) => key.startsWith(prefix)); },
    async remove(key) { data.delete(key); },
  };
  const handle = createTesterHandler({ env: { ...env, ...overrides }, store: () => store, isAdmin: async (request) => request.headers.get("authorization") === "fixture-admin", now: () => 1_800_000_000_000 });
  const body = { email: "person@custom.test", mode: "tester", participationConfirmed: true, privacyConsent: true, privacyNoticeVersion: getReleaseConfig({ ...env, ...overrides }).privacyNoticeVersion, website: "" };
  function request(payload: Record<string, unknown> = body, method = "POST", headers = {}) { return new Request("https://site.test/api/tester-applications", { method, headers: { origin: "https://site.test", "content-type": "application/json", ...headers }, body: JSON.stringify(payload) }); }
  return { handle, request, body, data, store };
}
test("release states, extra recruitment, confirmed perks and real download URL", () => {
  for (const [index, releaseStatus] of ["recruiting", "testing", "reviewing", "released"].entries()) {
    const config = getReleaseConfig({ RELEASE_STATUS: releaseStatus, NEXT_PUBLIC_GOOGLE_PLAY_URL: "https://play.google.com/store/apps/details?id=com.test.app" });
    assert.equal(releasePresentation(config).stage, index);
    assert.equal(config.acceptingTesters, releaseStatus === "recruiting");
  }
  assert.equal(getReleaseConfig({ RELEASE_STATUS: "released" }).releaseStatus, "reviewing");
  assert.equal(getReleaseConfig({ RELEASE_STATUS: "testing", ACCEPTING_TESTERS: "true" }).acceptingTesters, true);
  assert.equal(getReleaseConfig({ TESTER_BENEFIT_TEXT: "unconfirmed" }).testerBenefitConfirmed, false);
  assert.equal(getReleaseConfig({}).testerBenefitConfirmed, true);
  assert.equal(getReleaseConfig({}).testerBenefitText, confirmedTesterBenefitText);
  assert.match(confirmedTesterBenefitText, /평생 유지/);
  assert.match(confirmedTesterBenefitText, /광고 없이/);
  assert.match(confirmedTesterBenefitText, /자체 API로 제공하는 AI 기능은 이 혜택에 포함되지 않습니다/);
  assert.equal(getReleaseConfig({ TESTER_BENEFIT_CONFIRMED: "false" }).testerBenefitConfirmed, false);
  assert.equal(getReleaseConfig({}).privacyConfirmed, true);
  assert.match(releasePresentation(getReleaseConfig({ ACCEPTING_TESTERS: "false" })).label, /모집 마감/);
});
test("approved minimal policy defaults retain the existing contact, pause switch and invalid configuration guard", () => {
  const config = getReleaseConfig({});
  assert.equal(config.supportEmail, testerPrivacyDefaults.supportEmail);
  assert.equal(config.retentionDays, 90);
  assert.match(config.privacyNoticeVersion, /2026-11-28\.optional\.v2/);
  assert.equal(getReleaseConfig({ TESTER_PRIVACY_CONFIRMED: "false" }).privacyConfirmed, false);
  assert.equal(getReleaseConfig({ TESTER_PRIVACY_CONFIRMED: "invalid" }).privacyConfirmed, false);
  assert.equal(getReleaseConfig({ TESTER_RETENTION_DAYS: "0" }).privacyConfirmed, false);
  assert.equal(getReleaseConfig({ NEXT_PUBLIC_SUPPORT_EMAIL: "support@example.com" }).privacyConfirmed, false);
  assert.equal(getReleaseConfig({ NEXT_PUBLIC_SUPPORT_EMAIL: "" }).privacyConfirmed, false);
  assert.match(privacyNotice(config, "tester").items, /선택: 주요 사용 목적, 출시 알림/);
  assert.match(privacyNotice(config, "tester").retention, /신청일로부터 90일/);
});
test("Google account accepts custom email domains and optional fields default to unselected", async () => {
  const f = fixture(); assert.equal((await f.handle(f.request())).status, 200);
  const record = [...f.data.entries()].find(([key]) => key.startsWith("application/"))![1].data as TesterRecord;
  assert.equal(record.email, "person@custom.test");
  assert.deepEqual(Object.keys(record).sort(), ["id", "email", "mode", "usePurpose", "releaseNotificationConsent", "participationConfirmed", "privacyConsent", "privacyNoticeVersion", "submittedAt", "expiresAt", "status"].sort());
  assert.equal(record.usePurpose, ""); assert.equal(record.releaseNotificationConsent, false);
  assert.equal(record.submittedAt, 1_800_000_000_000); assert.equal(record.expiresAt - record.submittedAt, 90 * 86400000);
  assert.equal(record.status, "received");
});
test("duplicate concurrent requests have identical success and never overwrite consent", async () => {
  const f = fixture(); const responses = await Promise.all([f.handle(f.request()), f.handle(f.request({ ...f.body, email: " PERSON@custom.test ", releaseNotificationConsent: true }))]);
  assert.deepEqual(await responses[0].json(), { ok: true }); assert.deepEqual(await responses[1].json(), { ok: true });
  assert.equal([...f.data.keys()].filter((key) => key.startsWith("application/")).length, 1);
  const record = [...f.data.entries()].find(([key]) => key.startsWith("application/"))![1].data as TesterRecord;
  assert.equal(record.releaseNotificationConsent, false);
});
test("chosen optional purpose and notification consent are stored without unrelated client fields", async () => {
  const f = fixture();
  assert.equal((await f.handle(f.request({ ...f.body, usePurpose: "self", name: "unused", phone: "unused", releaseNotificationConsent: true }))).status, 200);
  const record = [...f.data.entries()].find(([key]) => key.startsWith("application/"))![1].data as TesterRecord;
  assert.equal(record.mode, "tester");
  assert.equal(record.usePurpose, "self"); assert.equal(record.releaseNotificationConsent, true);
  for (const key of ["name", "phone"]) assert.equal(Object.hasOwn(record, key), false);
});
test("standalone notification signup retains explicit consent and a separate purpose from tester applications", async () => {
  const f = fixture();
  const payload = { ...f.body, mode: "notification", participationConfirmed: false };
  assert.equal((await f.handle(f.request(payload))).status, 400);
  assert.equal(f.data.size, 0);
  assert.equal((await f.handle(f.request({ ...payload, releaseNotificationConsent: true }))).status, 200);
  assert.equal((await f.handle(f.request())).status, 200);
  const records = [...f.data.entries()].filter(([key]) => key.startsWith("application/")).map(([, entry]) => entry.data as TesterRecord);
  assert.equal(records.length, 2);
  assert.equal(records.find((record) => record.mode === "notification")!.participationConfirmed, false);
  assert.equal(records.find((record) => record.mode === "notification")!.releaseNotificationConsent, true);
  assert.ok(records.every((record) => record.privacyConsent && record.expiresAt - record.submittedAt === 90 * 86400000));
});
test("email, consent, current notice and honeypot are validated before storage", async () => {
  for (const change of [{ email: "broken" }, { privacyConsent: false }, { participationConfirmed: false }, { website: "spam" }, { mode: "unknown" }, { usePurpose: "unknown" }, { usePurpose: ["self"] }, { releaseNotificationConsent: "true" }, { mode: "notification", releaseNotificationConsent: false }]) {
    const f = fixture(); assert.equal((await f.handle(f.request({ ...f.body, ...change }))).status, 400); assert.equal(f.data.size, 0);
  }
  const f = fixture(); assert.equal((await f.handle(f.request({ ...f.body, privacyNoticeVersion: "old" }))).status, 409);
});
test("closed recruitment and unconfirmed privacy block collection on the server", async () => {
  const closed = fixture({ ACCEPTING_TESTERS: "false" }); assert.equal((await closed.handle(closed.request())).status, 409); assert.equal(closed.data.size, 0);
  const pending = fixture({ TESTER_PRIVACY_CONFIRMED: "false" }); assert.equal((await pending.handle(pending.request())).status, 503); assert.equal(pending.data.size, 0);
  assert.equal((await closed.handle(closed.request({ ...closed.body, mode: "notification", releaseNotificationConsent: true }))).status, 200);
});
test("public requests cannot read emails or change administrator state", async () => {
  const f = fixture(); await f.handle(f.request());
  assert.equal((await f.handle(new Request("https://site.test/api/tester-applications"))).status, 401);
  const config = await (await f.handle(new Request("https://site.test/api/tester-applications?view=config"))).text();
  assert.doesNotMatch(config, /person@|fixture-secret/);
  assert.equal((await f.handle(f.request({ id: "tester-" + "a".repeat(64), status: "invited" }, "PATCH"))).status, 401);
  assert.equal((await f.handle(f.request(f.body, "POST", { origin: "https://foreign.test" }))).status, 403);
});
test("shared admin session check never reads application storage or returns applicant data", async () => {
  const handle = createTesterHandler({ env, store: () => { throw new Error("Storage must not be accessed for a session check"); }, isAdmin: async (request) => request.headers.get("authorization") === "fixture-admin" });
  const publicResult = await handle(new Request("https://site.test/api/tester-applications?view=session"));
  assert.equal(publicResult.status, 200); assert.deepEqual(await publicResult.json(), { authenticated: false });
  const adminResult = await handle(new Request("https://site.test/api/tester-applications?view=session", { headers: { authorization: "fixture-admin" } }));
  assert.equal(adminResult.status, 200); assert.deepEqual(await adminResult.json(), { authenticated: true });
});
test("private operator list, status update, deletion and expiration", async () => {
  const f = fixture(); await f.handle(f.request());
  const list = await (await f.handle(new Request("https://site.test/api/tester-applications", { headers: { authorization: "fixture-admin" } }))).json();
  const id = list.records[0].id;
  assert.equal((await f.handle(f.request({ id, status: "invited" }, "PATCH", { authorization: "fixture-admin" }))).status, 200);
  assert.equal((f.data.get(`application/${id}`)!.data as TesterRecord).status, "invited");
  assert.equal((await f.handle(f.request({ id }, "DELETE", { authorization: "fixture-admin" }))).status, 200);
  assert.equal(f.data.has(`application/${id}`), false);
});
test("rate limit and storage errors cannot produce false success", async () => {
  const f = fixture(); for (let i = 0; i < 10; i++) assert.equal((await f.handle(f.request())).status, 200);
  assert.equal((await f.handle(f.request())).status, 429);
  const unavailable = createTesterHandler({ env, store: () => { throw new Error("private infrastructure failure"); }, isAdmin: async () => false });
  const response = await unavailable(f.request()); assert.equal(response.status, 503); assert.doesNotMatch(await response.text(), /infrastructure|person@/);
});
test("retention job removes expired applications and rate hashes, keeps active records", async () => {
  const f = fixture(); await f.handle(f.request());
  await f.store.write("application/expired", { expiresAt: 1 }, { onlyIfNew: true });
  await f.store.write("rate/expired", { start: 1 }, { onlyIfNew: true });
  await purgeExpiredTesterData(f.store, 1_800_000_000_001);
  assert.equal(f.data.has("application/expired"), false); assert.equal(f.data.has("rate/expired"), false);
  assert.equal([...f.data.keys()].filter((key) => key.startsWith("application/")).length, 1);
});
test("admin cookie verifies the shared signature and rejects tampering and expiration", async () => {
  const previous = process.env.FEEDBACK_SESSION_SECRET;
  process.env.FEEDBACK_SESSION_SECRET = env.FEEDBACK_SESSION_SECRET;
  try {
    const expiry = String(Math.floor(Date.now() / 1000) + 3600);
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(env.FEEDBACK_SESSION_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const signature = Buffer.from(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(expiry))).toString("base64url");
    const request = (cookie: string) => new Request("https://site.test", { headers: { cookie: `memorize_feedback_admin=${cookie}` } });
    assert.equal(await isTesterAdmin(request(`${expiry}.${signature}`)), true);
    assert.equal(await isTesterAdmin(request(`${expiry}.${signature.slice(0,-3)}bad`)), false);
    assert.equal(await isTesterAdmin(request(`1.${signature}`)), false);
  } finally { if (previous === undefined) delete process.env.FEEDBACK_SESSION_SECRET; else process.env.FEEDBACK_SESSION_SECRET = previous; }
});
