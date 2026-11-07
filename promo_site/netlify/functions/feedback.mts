import { getStore } from "@netlify/blobs";

type Reply = {
  id: string;
  postId: string;
  author: string;
  body: string;
  createdAt: number;
};

type StoredPost = {
  id: string;
  nickname: string;
  passwordSalt: string;
  passwordHash: string;
  category: string;
  title: string;
  body: string;
  status: string;
  likes: number;
  reactions: string[];
  replies: Reply[];
  createdAt: number;
  updatedAt: number;
};

type RateLimit = { windowStart: number; count: number };

const encoder = new TextEncoder();
const categories = new Set(["praise", "bug", "request", "idea", "other"]);
const statuses = new Set(["new", "reviewing", "planned", "done"]);
const ADMIN_COOKIE = "memorize_feedback_admin";
const SESSION_SECONDS = 60 * 60 * 8;
const store = () => getStore("memorize-feedback");

function json(data: unknown, status = 200, headers?: HeadersInit) {
  return Response.json(data, {
    status,
    headers: { "Cache-Control": "no-store", ...headers },
  });
}

function text(value: unknown, max: number) {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

async function bodyOf(request: Request) {
  try {
    return (await request.json()) as Record<string, unknown>;
  } catch {
    return {};
  }
}

function toBase64Url(bytes: Uint8Array) {
  return Buffer.from(bytes).toString("base64url");
}

function fromBase64Url(value: string) {
  return new Uint8Array(Buffer.from(value, "base64url"));
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return toBase64Url(new Uint8Array(digest));
}

async function safeEqual(leftValue: string, rightValue: string) {
  const left = encoder.encode(leftValue);
  const right = encoder.encode(rightValue);
  if (left.length !== right.length) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
}

async function hashPostPassword(password: string, salt?: Uint8Array) {
  const actualSalt = salt ?? crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", encoder.encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: actualSalt, iterations: 120_000 },
    key,
    256,
  );
  return { salt: toBase64Url(actualSalt), hash: toBase64Url(new Uint8Array(bits)) };
}

async function verifyPostPassword(password: string, salt: string, expected: string) {
  try {
    const actual = await hashPostPassword(password, fromBase64Url(salt));
    return safeEqual(actual.hash, expected);
  } catch {
    return false;
  }
}

async function hmac(value: string) {
  const secret = process.env.FEEDBACK_SESSION_SECRET?.trim() || "";
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

async function verifyAdminPassword(password: string) {
  const expected = process.env.FEEDBACK_ADMIN_PASSWORD?.trim() || "";
  return Boolean(expected) && safeEqual(await sha256(password), await sha256(expected));
}

async function createAdminCookie(request: Request) {
  const expires = Math.floor(Date.now() / 1000) + SESSION_SECONDS;
  const payload = String(expires);
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return `${ADMIN_COOKIE}=${payload}.${await hmac(payload)}; Max-Age=${SESSION_SECONDS}; Path=/; HttpOnly${secure}; SameSite=Lax`;
}

function clearAdminCookie() {
  return `${ADMIN_COOKIE}=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Lax`;
}

async function isAdminRequest(request: Request) {
  const cookie = request.headers.get("cookie") || "";
  const match = cookie.match(new RegExp(`(?:^|;\\s*)${ADMIN_COOKIE}=([^;]+)`));
  if (!match) return false;
  const [expiresText, signature] = match[1].split(".");
  const expires = Number(expiresText);
  if (!expires || expires < Math.floor(Date.now() / 1000) || !signature) return false;
  return safeEqual(signature, await hmac(expiresText));
}

function requestFingerprint(request: Request) {
  const ip = request.headers.get("x-nf-client-connection-ip") || request.headers.get("x-forwarded-for") || "unknown";
  const agent = request.headers.get("user-agent") || "unknown";
  return `${ip.split(",")[0].trim()}|${agent.slice(0, 180)}`;
}

function isSameOrigin(request: Request) {
  const origin = request.headers.get("origin");
  if (!origin) return true;
  return origin === new URL(request.url).origin;
}

async function checkWriteRate(request: Request, scope = "post", limit = 5, windowMs = 10 * 60 * 1000) {
  const fingerprint = await sha256(`${scope}|${requestFingerprint(request)}`);
  const key = `rate/${fingerprint}`;
  const now = Date.now();
  const current = await store().get(key, { type: "json", consistency: "strong" }) as RateLimit | null;
  if (!current || now - current.windowStart > windowMs) {
    await store().setJSON(key, { windowStart: now, count: 1 });
    return true;
  }
  if (current.count >= limit) return false;
  await store().setJSON(key, { ...current, count: current.count + 1 });
  return true;
}

async function getPost(id: string) {
  return await store().get(`post/${id}`, { type: "json", consistency: "strong" }) as StoredPost | null;
}

async function savePost(post: StoredPost, onlyIfNew = false) {
  return store().setJSON(`post/${post.id}`, post, onlyIfNew ? { onlyIfNew: true } : undefined);
}

async function listPosts(category: string) {
  const listing = await store().list({ prefix: "post/" });
  const records = await Promise.all(
    listing.blobs.slice(0, 300).map(({ key }) => store().get(key, { type: "json", consistency: "strong" }) as Promise<StoredPost | null>),
  );
  return records
    .filter((post): post is StoredPost => Boolean(post))
    .filter((post) => !categories.has(category) || post.category === category)
    .sort((left, right) => right.createdAt - left.createdAt)
    .slice(0, 150);
}

async function handleGet(request: Request) {
  const category = text(new URL(request.url).searchParams.get("category"), 20);
  const posts = await listPosts(category);
  return json({
    posts: posts.map(({ passwordHash: _hash, passwordSalt: _salt, reactions: _reactions, ...post }) => post),
    isAdmin: await isAdminRequest(request),
  });
}

async function handlePost(request: Request) {
  if (!isSameOrigin(request)) return json({ error: "허용되지 않은 요청입니다." }, 403);
  const input = await bodyOf(request);
  const action = text(input.action, 30) || "create";

  if (action === "admin-login") {
    if (!(await checkWriteRate(request, "admin-login", 8, 15 * 60 * 1000))) {
      return json({ error: "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요." }, 429);
    }
    if (!(await verifyAdminPassword(text(input.password, 128)))) {
      return json({ error: "관리자 비밀번호가 올바르지 않습니다." }, 401);
    }
    return json({ ok: true }, 200, { "Set-Cookie": await createAdminCookie(request) });
  }

  if (action === "admin-logout") {
    return json({ ok: true }, 200, { "Set-Cookie": clearAdminCookie() });
  }

  if (action === "react") {
    const postId = text(input.postId, 80);
    const clientToken = text(input.clientToken, 160);
    const post = await getPost(postId);
    if (!post || clientToken.length < 16) return json({ error: "반응 정보를 확인할 수 없습니다." }, 400);
    const voterHash = await sha256(`reaction|${clientToken}|${requestFingerprint(request)}`);
    if (post.reactions.includes(voterHash)) return json({ error: "이미 공감한 의견입니다." }, 409);
    post.reactions.push(voterHash);
    post.likes = post.reactions.length;
    post.updatedAt = Date.now();
    await savePost(post);
    return json({ ok: true });
  }

  if (action.startsWith("admin-")) {
    if (!(await isAdminRequest(request))) return json({ error: "관리자 로그인이 필요합니다." }, 401);
    const postId = text(input.postId, 80);
    const post = await getPost(postId);
    if (!post) return json({ error: "게시물을 찾을 수 없습니다." }, 404);

    if (action === "admin-reply") {
      const replyBody = text(input.body, 1000);
      if (replyBody.length < 2) return json({ error: "답글을 두 글자 이상 입력해 주세요." }, 400);
      post.replies.push({ id: crypto.randomUUID(), postId, author: "Memorize Me 운영자", body: replyBody, createdAt: Date.now() });
      post.updatedAt = Date.now();
      await savePost(post);
      return json({ ok: true });
    }

    if (action === "admin-status") {
      const status = text(input.status, 20);
      if (!statuses.has(status)) return json({ error: "상태값이 올바르지 않습니다." }, 400);
      post.status = status;
      post.updatedAt = Date.now();
      await savePost(post);
      return json({ ok: true });
    }

    if (action === "admin-delete") {
      await store().delete(`post/${postId}`);
      return json({ ok: true });
    }
  }

  if (!(await checkWriteRate(request))) {
    return json({ error: "짧은 시간에 너무 많은 글이 등록되었습니다. 잠시 후 다시 시도해 주세요." }, 429);
  }

  const nickname = text(input.nickname, 20);
  const password = text(input.password, 64);
  const category = text(input.category, 20);
  const title = text(input.title, 80);
  const postBody = text(input.body, 2000);
  if (nickname.length < 2) return json({ error: "닉네임은 두 글자 이상 입력해 주세요." }, 400);
  if (password.length < 4) return json({ error: "글 비밀번호는 네 글자 이상 입력해 주세요." }, 400);
  if (!categories.has(category)) return json({ error: "분류를 선택해 주세요." }, 400);
  if (title.length < 2) return json({ error: "제목은 두 글자 이상 입력해 주세요." }, 400);
  if (postBody.length < 5) return json({ error: "의견을 다섯 글자 이상 입력해 주세요." }, 400);

  const passwordData = await hashPostPassword(password);
  const now = Date.now();
  const post: StoredPost = {
    id: crypto.randomUUID(), nickname, passwordSalt: passwordData.salt, passwordHash: passwordData.hash,
    category, title, body: postBody, status: "new", likes: 0, reactions: [], replies: [], createdAt: now, updatedAt: now,
  };
  await savePost(post, true);
  return json({ ok: true }, 201);
}

async function handlePatch(request: Request) {
  if (!isSameOrigin(request)) return json({ error: "허용되지 않은 요청입니다." }, 403);
  const input = await bodyOf(request);
  const id = text(input.id, 80);
  const post = await getPost(id);
  if (!post) return json({ error: "게시물을 찾을 수 없습니다." }, 404);
  if (!(await isAdminRequest(request)) && !(await verifyPostPassword(text(input.password, 64), post.passwordSalt, post.passwordHash))) {
    return json({ error: "글 비밀번호가 올바르지 않습니다." }, 401);
  }
  const nickname = text(input.nickname, 20);
  const category = text(input.category, 20);
  const title = text(input.title, 80);
  const postBody = text(input.body, 2000);
  if (nickname.length < 2 || !categories.has(category) || title.length < 2 || postBody.length < 5) {
    return json({ error: "입력 내용을 다시 확인해 주세요." }, 400);
  }
  Object.assign(post, { nickname, category, title, body: postBody, updatedAt: Date.now() });
  await savePost(post);
  return json({ ok: true });
}

async function handleDelete(request: Request) {
  if (!isSameOrigin(request)) return json({ error: "허용되지 않은 요청입니다." }, 403);
  const input = await bodyOf(request);
  const id = text(input.id, 80);
  const post = await getPost(id);
  if (!post) return json({ error: "게시물을 찾을 수 없습니다." }, 404);
  if (!(await isAdminRequest(request)) && !(await verifyPostPassword(text(input.password, 64), post.passwordSalt, post.passwordHash))) {
    return json({ error: "글 비밀번호가 올바르지 않습니다." }, 401);
  }
  await store().delete(`post/${id}`);
  return json({ ok: true });
}

export default async function handler(request: Request) {
  try {
    if (request.method === "GET") return handleGet(request);
    if (request.method === "POST") return handlePost(request);
    if (request.method === "PATCH") return handlePatch(request);
    if (request.method === "DELETE") return handleDelete(request);
    return json({ error: "지원하지 않는 요청입니다." }, 405, { Allow: "GET, POST, PATCH, DELETE" });
  } catch (error) {
    console.error("[feedback]", error);
    return json({ error: "게시판 서버에서 요청을 처리하지 못했습니다." }, 500);
  }
}

export const config = { path: "/api/feedback" };
