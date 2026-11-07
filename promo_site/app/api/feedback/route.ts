import { and, desc, eq, sql } from "drizzle-orm";
import { NextResponse } from "next/server";
import { getDb } from "@/db";
import {
  feedbackPosts,
  feedbackRateLimits,
  feedbackReactions,
  feedbackReplies,
} from "@/db/schema";
import {
  clearAdminCookie,
  createAdminCookie,
  hashPostPassword,
  isAdminRequest,
  isSameOrigin,
  requestFingerprint,
  sha256,
  verifyAdminPassword,
  verifyPostPassword,
} from "@/lib/feedback-security";

export const dynamic = "force-dynamic";

const categories = new Set(["praise", "bug", "request", "idea", "other"]);
const statuses = new Set(["new", "reviewing", "planned", "done"]);

function json(data: unknown, status = 200, headers?: HeadersInit) {
  return NextResponse.json(data, {
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

async function checkWriteRate(
  request: Request,
  scope = "post",
  limit = 5,
  windowMs = 10 * 60 * 1000,
) {
  const db = getDb();
  const now = Date.now();
  const fingerprint = await sha256(`${scope}|${requestFingerprint(request)}`);
  const [existing] = await db
    .select()
    .from(feedbackRateLimits)
    .where(eq(feedbackRateLimits.fingerprint, fingerprint))
    .limit(1);

  if (!existing || now - existing.windowStart > windowMs) {
    await db
      .insert(feedbackRateLimits)
      .values({ fingerprint, windowStart: now, count: 1 })
      .onConflictDoUpdate({
        target: feedbackRateLimits.fingerprint,
        set: { windowStart: now, count: 1 },
      });
    return true;
  }

  if (existing.count >= limit) return false;
  await db
    .update(feedbackRateLimits)
    .set({ count: existing.count + 1 })
    .where(eq(feedbackRateLimits.fingerprint, fingerprint));
  return true;
}

export async function GET(request: Request) {
  const db = getDb();
  const url = new URL(request.url);
  const category = text(url.searchParams.get("category"), 20);
  const filter = categories.has(category) ? eq(feedbackPosts.category, category) : undefined;
  const posts = await db
    .select({
      id: feedbackPosts.id,
      nickname: feedbackPosts.nickname,
      category: feedbackPosts.category,
      title: feedbackPosts.title,
      body: feedbackPosts.body,
      status: feedbackPosts.status,
      likes: feedbackPosts.likes,
      createdAt: feedbackPosts.createdAt,
      updatedAt: feedbackPosts.updatedAt,
    })
    .from(feedbackPosts)
    .where(filter)
    .orderBy(desc(feedbackPosts.createdAt))
    .limit(150);

  const replies = await db
    .select({
      id: feedbackReplies.id,
      postId: feedbackReplies.postId,
      author: feedbackReplies.author,
      body: feedbackReplies.body,
      createdAt: feedbackReplies.createdAt,
    })
    .from(feedbackReplies)
    .orderBy(feedbackReplies.createdAt);

  const repliesByPost = new Map<string, typeof replies>();
  for (const reply of replies) {
    const current = repliesByPost.get(reply.postId) ?? [];
    current.push(reply);
    repliesByPost.set(reply.postId, current);
  }

  return json({
    posts: posts.map((post) => ({ ...post, replies: repliesByPost.get(post.id) ?? [] })),
    isAdmin: await isAdminRequest(request),
  });
}

export async function POST(request: Request) {
  if (!isSameOrigin(request)) return json({ error: "허용되지 않은 요청입니다." }, 403);
  const input = await bodyOf(request);
  const action = text(input.action, 30) || "create";

  if (action === "admin-login") {
    if (!(await checkWriteRate(request, "admin-login", 8, 15 * 60 * 1000))) {
      return json({ error: "로그인 시도가 너무 많습니다. 잠시 후 다시 시도해 주세요." }, 429);
    }
    const password = text(input.password, 128);
    if (!(await verifyAdminPassword(password))) {
      return json({ error: "관리자 비밀번호가 올바르지 않습니다." }, 401);
    }
    return json({ ok: true }, 200, { "Set-Cookie": await createAdminCookie(request) });
  }

  if (action === "admin-logout") {
    return json({ ok: true }, 200, { "Set-Cookie": clearAdminCookie() });
  }

  const db = getDb();

  if (action === "react") {
    const postId = text(input.postId, 80);
    const clientToken = text(input.clientToken, 160);
    if (!postId || clientToken.length < 16) return json({ error: "반응 정보를 확인할 수 없습니다." }, 400);
    const voterHash = await sha256(`reaction|${clientToken}|${requestFingerprint(request)}`);
    try {
      await db.insert(feedbackReactions).values({
        id: crypto.randomUUID(),
        postId,
        voterHash,
        createdAt: Date.now(),
      });
      await db
        .update(feedbackPosts)
        .set({ likes: sql`${feedbackPosts.likes} + 1` })
        .where(eq(feedbackPosts.id, postId));
      return json({ ok: true });
    } catch {
      return json({ error: "이미 공감한 의견입니다." }, 409);
    }
  }

  if (action.startsWith("admin-")) {
    if (!(await isAdminRequest(request))) return json({ error: "관리자 로그인이 필요합니다." }, 401);
    const postId = text(input.postId, 80);
    if (!postId) return json({ error: "게시물을 찾을 수 없습니다." }, 400);

    if (action === "admin-reply") {
      const replyBody = text(input.body, 1000);
      if (replyBody.length < 2) return json({ error: "답글을 두 글자 이상 입력해 주세요." }, 400);
      await db.insert(feedbackReplies).values({
        id: crypto.randomUUID(),
        postId,
        author: "Memorize Me 운영자",
        body: replyBody,
        createdAt: Date.now(),
      });
      return json({ ok: true });
    }

    if (action === "admin-status") {
      const status = text(input.status, 20);
      if (!statuses.has(status)) return json({ error: "상태값이 올바르지 않습니다." }, 400);
      await db
        .update(feedbackPosts)
        .set({ status, updatedAt: Date.now() })
        .where(eq(feedbackPosts.id, postId));
      return json({ ok: true });
    }

    if (action === "admin-delete") {
      await db.delete(feedbackPosts).where(eq(feedbackPosts.id, postId));
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
  await db.insert(feedbackPosts).values({
    id: crypto.randomUUID(),
    nickname,
    passwordSalt: passwordData.salt,
    passwordHash: passwordData.hash,
    category,
    title,
    body: postBody,
    status: "new",
    likes: 0,
    createdAt: now,
    updatedAt: now,
  });
  return json({ ok: true }, 201);
}

export async function PATCH(request: Request) {
  if (!isSameOrigin(request)) return json({ error: "허용되지 않은 요청입니다." }, 403);
  const input = await bodyOf(request);
  const id = text(input.id, 80);
  const db = getDb();
  const [post] = await db.select().from(feedbackPosts).where(eq(feedbackPosts.id, id)).limit(1);
  if (!post) return json({ error: "게시물을 찾을 수 없습니다." }, 404);

  const admin = await isAdminRequest(request);
  if (!admin && !(await verifyPostPassword(text(input.password, 64), post.passwordSalt, post.passwordHash))) {
    return json({ error: "글 비밀번호가 올바르지 않습니다." }, 401);
  }

  const nickname = text(input.nickname, 20);
  const category = text(input.category, 20);
  const title = text(input.title, 80);
  const postBody = text(input.body, 2000);
  if (nickname.length < 2 || !categories.has(category) || title.length < 2 || postBody.length < 5) {
    return json({ error: "입력 내용을 다시 확인해 주세요." }, 400);
  }

  await db
    .update(feedbackPosts)
    .set({ nickname, category, title, body: postBody, updatedAt: Date.now() })
    .where(eq(feedbackPosts.id, id));
  return json({ ok: true });
}

export async function DELETE(request: Request) {
  if (!isSameOrigin(request)) return json({ error: "허용되지 않은 요청입니다." }, 403);
  const input = await bodyOf(request);
  const id = text(input.id, 80);
  const db = getDb();
  const [post] = await db.select().from(feedbackPosts).where(eq(feedbackPosts.id, id)).limit(1);
  if (!post) return json({ error: "게시물을 찾을 수 없습니다." }, 404);

  const admin = await isAdminRequest(request);
  if (!admin && !(await verifyPostPassword(text(input.password, 64), post.passwordSalt, post.passwordHash))) {
    return json({ error: "글 비밀번호가 올바르지 않습니다." }, 401);
  }
  await db.delete(feedbackPosts).where(and(eq(feedbackPosts.id, id)));
  return json({ ok: true });
}
