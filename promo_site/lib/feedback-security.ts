import { env } from "cloudflare:workers";

const encoder = new TextEncoder();
const ADMIN_COOKIE = "memorize_feedback_admin";
const SESSION_SECONDS = 60 * 60 * 8;

function runtimeValue(key: string) {
  return (env as unknown as Record<string, string | undefined>)[key]?.trim() || "";
}

function toBase64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function fromBase64Url(value: string) {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((value.length + 3) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function hmac(value: string) {
  const secret = runtimeValue("FEEDBACK_SESSION_SECRET");
  if (!secret) return "";
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return toBase64Url(new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(value))));
}

export async function hashPostPassword(password: string, salt?: Uint8Array) {
  const actualSalt = salt ?? crypto.getRandomValues(new Uint8Array(16));
  const pbkdfSalt = new Uint8Array(actualSalt);
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: pbkdfSalt, iterations: 120_000 },
    key,
    256,
  );
  return { salt: toBase64Url(actualSalt), hash: toBase64Url(new Uint8Array(bits)) };
}

export async function verifyPostPassword(password: string, salt: string, expected: string) {
  try {
    const actual = await hashPostPassword(password, fromBase64Url(salt));
    return await safeEqual(actual.hash, expected);
  } catch {
    return false;
  }
}

export async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return toBase64Url(new Uint8Array(digest));
}

export async function safeEqual(a: string, b: string) {
  const left = encoder.encode(a);
  const right = encoder.encode(b);
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
}

export async function verifyAdminPassword(password: string) {
  const expected = runtimeValue("FEEDBACK_ADMIN_PASSWORD");
  return Boolean(expected) && safeEqual(await sha256(password), await sha256(expected));
}

export async function createAdminCookie(request: Request) {
  const expires = Math.floor(Date.now() / 1000) + SESSION_SECONDS;
  const payload = String(expires);
  const signature = await hmac(payload);
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return `${ADMIN_COOKIE}=${payload}.${signature}; Max-Age=${SESSION_SECONDS}; Path=/; HttpOnly${secure}; SameSite=Lax`;
}

export function clearAdminCookie() {
  return `${ADMIN_COOKIE}=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Lax`;
}

export async function isAdminRequest(request: Request) {
  const cookie = request.headers.get("cookie") || "";
  const match = cookie.match(new RegExp(`(?:^|;\\s*)${ADMIN_COOKIE}=([^;]+)`));
  if (!match) return false;
  const [expiresText, signature] = match[1].split(".");
  const expires = Number(expiresText);
  if (!expires || expires < Math.floor(Date.now() / 1000) || !signature) return false;
  return safeEqual(signature, await hmac(expiresText));
}

export function requestFingerprint(request: Request) {
  const ip = request.headers.get("cf-connecting-ip") || request.headers.get("x-forwarded-for") || "unknown";
  const agent = request.headers.get("user-agent") || "unknown";
  return `${ip.split(",")[0].trim()}|${agent.slice(0, 180)}`;
}

export function isSameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) return true;
  return origin === new URL(request.url).origin;
}
