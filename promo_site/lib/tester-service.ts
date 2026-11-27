import { getReleaseConfig } from "./site-release";

export type TesterRecord = {
  id: string;
  email: string;
  mode: "tester" | "notification";
  usePurpose?: string;
  releaseNotificationConsent?: boolean;
  participationConfirmed: boolean;
  privacyConsent: true;
  privacyNoticeVersion: string;
  submittedAt: number;
  expiresAt: number;
  status: "received" | "registered" | "invited";
};
export type PrivateStore = {
  read: (key: string) => Promise<{ data: unknown; etag: string } | null>;
  write: (key: string, data: unknown, condition: { onlyIfNew: true } | { onlyIfMatch: string }) => Promise<boolean>;
  keys: (prefix: string) => Promise<string[]>;
  remove: (key: string) => Promise<void>;
};
type Dependencies = {
  env: Record<string, string | undefined>;
  store: () => PrivateStore;
  isAdmin: (request: Request) => Promise<boolean>;
  now?: () => number;
};
const encoder = new TextEncoder();
const purposes = new Set(["", "student", "child", "teaching", "self", "other"]);

export async function privateDigest(value: string, secret: string) {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return Array.from(new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(value))), (byte) => byte.toString(16).padStart(2, "0")).join("");
}
export function result(data: unknown, status = 200, headers?: HeadersInit) {
  return Response.json(data, { status, headers: { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff", ...headers } });
}

export async function purgeExpiredTesterData(store: PrivateStore, now = Date.now()) {
  for (const prefix of ["application/", "rate/"]) {
    for (const key of await store.keys(prefix)) {
      const entry = await store.read(key);
      const data = entry?.data as { expiresAt?: number; start?: number } | undefined;
      if (data && (prefix === "application/" ? Number(data.expiresAt) <= now : Number(data.start) + 600_000 <= now)) await store.remove(key);
    }
  }
}

export function createTesterHandler(dependencies: Dependencies) {
  return async function handle(request: Request): Promise<Response> {
    const { env } = dependencies;
    const config = getReleaseConfig(env);
    const now = dependencies.now?.() ?? Date.now();
    const url = new URL(request.url);
    if (request.method === "GET" && url.searchParams.get("view") === "config") return result({ config });
    try {
      if (request.method === "GET" && url.searchParams.get("view") === "session") return result({ authenticated: await dependencies.isAdmin(request) });
      if (request.method === "GET") {
        if (!(await dependencies.isAdmin(request))) return result({ error: "관리자 로그인이 필요합니다." }, 401);
        const store = dependencies.store();
        const records: TesterRecord[] = [];
        for (const key of await store.keys("application/")) {
          const entry = await store.read(key);
          if (!entry) continue;
          const record = entry.data as TesterRecord;
          if (record.expiresAt <= now) { await store.remove(key); continue; }
          records.push(record);
        }
        return result({ records: records.sort((a, b) => b.submittedAt - a.submittedAt) });
      }
      const origin = request.headers.get("origin");
      if (!origin || origin !== url.origin) return result({ error: "허용되지 않은 요청입니다." }, 403);
      if (!request.headers.get("content-type")?.startsWith("application/json")) return result({ error: "JSON 형식이 필요합니다." }, 415);
      const raw = await request.text();
      if (raw.length > 4096) return result({ error: "요청이 너무 큽니다." }, 413);
      let body: Record<string, unknown>;
      try { body = JSON.parse(raw); if (!body || typeof body !== "object" || Array.isArray(body)) throw new Error(); }
      catch { return result({ error: "입력 형식을 확인해 주세요." }, 400); }

      if (request.method === "PATCH" || request.method === "DELETE") {
        if (!(await dependencies.isAdmin(request))) return result({ error: "관리자 로그인이 필요합니다." }, 401);
        const id = typeof body.id === "string" ? body.id : "";
        if (!/^(tester|notification)-[a-f0-9]{64}$/.test(id)) return result({ error: "신청 정보를 확인해 주세요." }, 400);
        const store = dependencies.store();
        const key = `application/${id}`;
        const existing = await store.read(key);
        if (!existing) return result({ error: "신청 정보를 찾을 수 없습니다." }, 404);
        if (request.method === "DELETE") { await store.remove(key); return result({ ok: true }); }
        if (!["received", "registered", "invited"].includes(String(body.status))) return result({ error: "상태를 확인해 주세요." }, 400);
        const modified = await store.write(key, { ...(existing.data as TesterRecord), status: body.status }, { onlyIfMatch: existing.etag });
        return modified ? result({ ok: true }) : result({ error: "다른 변경이 있습니다. 새로고침해 주세요." }, 409);
      }
      if (request.method !== "POST") return result({ error: "지원하지 않는 요청입니다." }, 405, { Allow: "GET, POST, PATCH, DELETE" });
      if (!config.privacyConfirmed) return result({ error: "개인정보 수집 안내가 확정된 후 신청 접수를 시작합니다." }, 503);
      if (body.mode !== "tester" && body.mode !== "notification") return result({ error: "신청 유형을 확인해 주세요." }, 400);
      if (body.mode === "tester" && !config.acceptingTesters) return result({ error: "현재 테스터 모집이 종료되었습니다. 출시 알림을 신청해 주세요." }, 409);
      if (config.releaseStatus === "released" && body.mode === "notification") return result({ error: "이미 정식 출시되었습니다. Google Play에서 확인해 주세요." }, 409);
      const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
      if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return result({ error: "올바른 이메일 주소를 입력해 주세요." }, 400);
      if (body.privacyConsent !== true || (body.mode === "tester" && body.participationConfirmed !== true)) return result({ error: "테스트 참여 조건과 개인정보 수집 안내를 확인해 주세요." }, 400);
      if (body.privacyNoticeVersion !== config.privacyNoticeVersion) return result({ error: "안내가 변경되었습니다. 페이지를 새로고침한 뒤 다시 신청해 주세요." }, 409);
      if (body.website || (body.mode === "notification" && body.releaseNotificationConsent !== true)) return result({ error: "입력 내용을 확인해 주세요." }, 400);
      if ((body.usePurpose !== undefined && (typeof body.usePurpose !== "string" || !purposes.has(body.usePurpose))) || (body.releaseNotificationConsent !== undefined && typeof body.releaseNotificationConsent !== "boolean")) return result({ error: "선택 항목을 확인해 주세요." }, 400);
      const secret = env.FEEDBACK_SESSION_SECRET?.trim() || "";
      if (secret.length < 32) return result({ error: "신청 서버를 준비 중입니다. 잠시 후 다시 시도해 주세요." }, 503);
      const store = dependencies.store();
      const ip = request.headers.get("x-nf-client-connection-ip") || request.headers.get("cf-connecting-ip") || "local";
      const rateKey = `rate/${await privateDigest(`rate|${ip}|${request.headers.get("user-agent")?.slice(0,120) || ""}`, secret)}`;
      let allowed = false;
      for (let retry = 0; retry < 4; retry++) {
        const current = await store.read(rateKey);
        const previous = current?.data as { start: number; count: number } | undefined;
        const fresh = !previous || now - previous.start >= 600_000;
        if (!fresh && previous.count >= 10) return result({ error: "신청 시도가 많습니다. 잠시 후 다시 시도해 주세요." }, 429, { "Retry-After": "600" });
        if (await store.write(rateKey, { start: fresh ? now : previous.start, count: fresh ? 1 : previous.count + 1 }, current ? { onlyIfMatch: current.etag } : { onlyIfNew: true })) { allowed = true; break; }
      }
      if (!allowed) return result({ error: "요청이 몰리고 있습니다. 잠시 후 다시 시도해 주세요." }, 429);
      const id = `${body.mode}-${await privateDigest(`email|${email}`, secret)}`;
      const record: TesterRecord = {
        id, email, mode: body.mode,
        usePurpose: body.mode === "tester" ? String(body.usePurpose ?? "") : "",
        releaseNotificationConsent: body.releaseNotificationConsent === true,
        participationConfirmed: body.mode === "tester", privacyConsent: true, privacyNoticeVersion: config.privacyNoticeVersion,
        submittedAt: now,
        expiresAt: now + config.retentionDays! * 86_400_000, status: "received",
      };
      // Atomic create prevents duplicates even if two requests race. Identical
      // responses keep an applicant's existence private. No email is sent here.
      const key = `application/${id}`;
      const modified = await store.write(key, record, { onlyIfNew: true });
      if (!modified) {
        const existing = await store.read(key);
        if (!existing) throw new Error("Unconfirmed storage write");
        // Never overwrite consent on a duplicate request.
      }
      return result({ ok: true }, 200);
    } catch {
      // Do not log email addresses, raw payloads, or storage errors containing data.
      return result({ error: "신청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요." }, 503);
    }
  };
}
