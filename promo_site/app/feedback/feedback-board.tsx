"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

type Reply = { id: string; postId: string; author: string; body: string; createdAt: number; isAdmin?: boolean };
type Post = {
  id: string;
  nickname: string;
  category: string;
  title: string;
  body: string;
  status: string;
  likes: number;
  createdAt: number;
  updatedAt: number;
  replies: Reply[];
};

const categories = [
  ["all", "전체"],
  ["praise", "칭찬하기"],
  ["bug", "오류 제보"],
  ["request", "개선 요청"],
  ["idea", "아이디어"],
  ["other", "기타"],
];
const statusLabels: Record<string, string> = {
  new: "접수됨",
  reviewing: "확인 중",
  planned: "반영 예정",
  done: "반영 완료",
};
const categoryLabels = Object.fromEntries(categories);
const emptyForm = { nickname: "", password: "", category: "request", title: "", body: "" };
const emptyComment = { nickname: "", password: "", body: "" };

function formatDate(timestamp: number) {
  return new Intl.DateTimeFormat("ko-KR", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" }).format(timestamp);
}

async function api(method: string, body?: Record<string, unknown>, query = "") {
  const response = await fetch(`/api/feedback${query}`, {
    method,
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
    cache: "no-store",
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || "요청을 처리하지 못했습니다.");
  return data;
}

export function FeedbackBoard() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [isAdmin, setIsAdmin] = useState(false);
  const [filter, setFilter] = useState("all");
  const [expanded, setExpanded] = useState<string | null>(null);
  const [showWrite, setShowWrite] = useState(false);
  const [showAdmin, setShowAdmin] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [adminPassword, setAdminPassword] = useState("");
  const [replyText, setReplyText] = useState<Record<string, string>>({});
  const [commentDrafts, setCommentDrafts] = useState<Record<string, typeof emptyComment>>({});
  const [editId, setEditId] = useState<string | null>(null);
  const [editForm, setEditForm] = useState({ ...emptyForm });
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await api("GET", undefined, filter === "all" ? "" : `?category=${filter}`);
      setPosts(data.posts || []);
      setIsAdmin(Boolean(data.isAdmin));
      setMessage("");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "게시물을 불러오지 못했습니다.");
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => { void load(); }, [load]);

  const counts = useMemo(() => ({
    total: posts.length,
    answered: posts.filter((post) => post.replies.some((reply) => reply.isAdmin)).length,
    done: posts.filter((post) => post.status === "done").length,
  }), [posts]);

  async function submitPost(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    try {
      await api("POST", { action: "create", ...form });
      setForm(emptyForm);
      setShowWrite(false);
      await load();
      setMessage("의견이 등록되었습니다. 확인 후 답변드릴게요.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "등록하지 못했습니다.");
    } finally { setBusy(false); }
  }

  async function loginAdmin(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    try {
      await api("POST", { action: "admin-login", password: adminPassword });
      setAdminPassword("");
      setShowAdmin(false);
      await load();
    } catch (error) { setMessage(error instanceof Error ? error.message : "로그인하지 못했습니다."); }
    finally { setBusy(false); }
  }

  async function logoutAdmin() {
    await api("POST", { action: "admin-logout" });
    await load();
  }

  async function react(postId: string) {
    let token = localStorage.getItem("memorize-feedback-voter");
    if (!token) {
      token = `${crypto.randomUUID()}-${crypto.randomUUID()}`;
      localStorage.setItem("memorize-feedback-voter", token);
    }
    try {
      await api("POST", { action: "react", postId, clientToken: token });
      await load();
    } catch (error) { setMessage(error instanceof Error ? error.message : "공감하지 못했습니다."); }
  }

  function beginEdit(post: Post) {
    setExpanded(post.id);
    setEditId(post.id);
    setEditForm({ nickname: post.nickname, password: "", category: post.category, title: post.title, body: post.body });
  }

  async function saveEdit(event: FormEvent) {
    event.preventDefault();
    if (!editId) return;
    setBusy(true);
    try {
      await api("PATCH", { id: editId, ...editForm });
      setEditId(null);
      await load();
    } catch (error) { setMessage(error instanceof Error ? error.message : "수정하지 못했습니다."); }
    finally { setBusy(false); }
  }

  async function removePost(post: Post) {
    const password = isAdmin ? "" : window.prompt("글을 삭제하려면 작성할 때 정한 비밀번호를 입력하세요.");
    if (!isAdmin && password === null) return;
    if (!window.confirm("이 의견을 삭제할까요? 삭제 후에는 복구할 수 없습니다.")) return;
    try {
      if (isAdmin) await api("POST", { action: "admin-delete", postId: post.id });
      else await api("DELETE", { id: post.id, password });
      setExpanded(null);
      await load();
    } catch (error) { setMessage(error instanceof Error ? error.message : "삭제하지 못했습니다."); }
  }

  async function setStatus(postId: string, status: string) {
    await api("POST", { action: "admin-status", postId, status });
    await load();
  }

  async function reply(postId: string) {
    const body = replyText[postId]?.trim() || "";
    try {
      await api("POST", { action: "admin-reply", postId, body });
      setReplyText((current) => ({ ...current, [postId]: "" }));
      await load();
    } catch (error) { setMessage(error instanceof Error ? error.message : "답글을 등록하지 못했습니다."); }
  }

  async function submitComment(event: FormEvent, postId: string) {
    event.preventDefault();
    const draft = commentDrafts[postId] || emptyComment;
    setBusy(true);
    try {
      await api("POST", { action: "reply", postId, ...draft });
      setCommentDrafts((current) => ({ ...current, [postId]: { ...emptyComment } }));
      await load();
      setExpanded(postId);
      setMessage("댓글이 등록되었습니다.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "댓글을 등록하지 못했습니다.");
    } finally { setBusy(false); }
  }

  async function removeReply(postId: string, replyId: string) {
    const password = isAdmin ? "" : window.prompt("댓글을 삭제하려면 작성할 때 정한 비밀번호를 입력하세요.");
    if (!isAdmin && password === null) return;
    if (!window.confirm("이 댓글을 삭제할까요?")) return;
    try {
      await api("POST", { action: "reply-delete", postId, replyId, password });
      await load();
      setExpanded(postId);
      setMessage("댓글이 삭제되었습니다.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "댓글을 삭제하지 못했습니다.");
    }
  }

  return (
    <section className="feedback-board" aria-label="테스터 의견 게시판">
      <div className="feedback-summary">
        <div><strong>{counts.total}</strong><span>등록된 의견</span></div>
        <div><strong>{counts.answered}</strong><span>운영자 답변</span></div>
        <div><strong>{counts.done}</strong><span>반영 완료</span></div>
      </div>

      <div className="feedback-toolbar">
        <div className="feedback-filters" role="tablist" aria-label="의견 분류">
          {categories.map(([value, label]) => (
            <button key={value} type="button" className={filter === value ? "active" : ""} onClick={() => setFilter(value)}>{label}</button>
          ))}
        </div>
        <div className="feedback-toolbar-actions">
          {isAdmin ? <button className="feedback-admin-on" type="button" onClick={logoutAdmin}>관리자 로그아웃</button> : <button type="button" onClick={() => setShowAdmin((value) => !value)}>관리자 로그인</button>}
          <button className="feedback-write-button" type="button" onClick={() => setShowWrite((value) => !value)}>+ 의견 남기기</button>
        </div>
      </div>

      {message && <p className="feedback-message" role="status">{message}</p>}

      {showAdmin && !isAdmin && (
        <form className="feedback-admin-form" onSubmit={loginAdmin}>
          <label><span>관리자 비밀번호</span><input type="password" value={adminPassword} onChange={(event) => setAdminPassword(event.target.value)} required autoComplete="current-password" /></label>
          <button type="submit" disabled={busy}>관리자로 로그인</button>
        </form>
      )}

      {showWrite && (
        <form className="feedback-write-form" onSubmit={submitPost}>
          <div className="feedback-form-heading"><div><span>NEW FEEDBACK</span><h2>테스트 의견 남기기</h2></div><button type="button" onClick={() => setShowWrite(false)} aria-label="작성 폼 닫기">×</button></div>
          <div className="feedback-form-grid">
            <label><span>닉네임</span><input value={form.nickname} maxLength={20} onChange={(event) => setForm({ ...form, nickname: event.target.value })} placeholder="2~20자" required /></label>
            <label><span>글 비밀번호</span><input type="password" value={form.password} maxLength={64} onChange={(event) => setForm({ ...form, password: event.target.value })} placeholder="수정·삭제용 4자 이상" required /></label>
            <label className="full"><span>분류</span><select value={form.category} onChange={(event) => setForm({ ...form, category: event.target.value })}>{categories.slice(1).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
            <label className="full"><span>제목</span><input value={form.title} maxLength={80} onChange={(event) => setForm({ ...form, title: event.target.value })} placeholder="무엇을 개선하면 좋을까요?" required /></label>
            <label className="full"><span>내용</span><textarea value={form.body} maxLength={2000} onChange={(event) => setForm({ ...form, body: event.target.value })} placeholder="사용한 기기, 발생한 화면과 기대한 동작을 함께 알려 주세요." required /></label>
          </div>
          <div className="feedback-form-footer"><small>비밀번호는 암호화해 저장하며 운영자도 확인할 수 없습니다.</small><button type="submit" disabled={busy}>{busy ? "등록 중…" : "의견 등록"}</button></div>
        </form>
      )}

      <div className="feedback-list">
        {loading ? <div className="feedback-empty">의견을 불러오는 중입니다…</div> : posts.length === 0 ? <div className="feedback-empty"><strong>아직 등록된 의견이 없습니다.</strong><span>첫 번째 의견을 남겨 주세요.</span></div> : posts.map((post) => {
          const open = expanded === post.id;
          return (
            <article className={`feedback-post ${open ? "open" : ""}`} key={post.id}>
              <button className="feedback-post-summary" type="button" onClick={() => setExpanded(open ? null : post.id)} aria-expanded={open}>
                <span className={`feedback-category category-${post.category}`}>{categoryLabels[post.category]}</span>
                <span className="feedback-post-title"><strong>{post.title}</strong><small>{post.nickname} · {formatDate(post.createdAt)}</small></span>
                <span className={`feedback-status status-${post.status}`}>{statusLabels[post.status]}</span>
                <span className="feedback-counts">♡ {post.likes}<b>{post.replies.length ? `댓글 ${post.replies.length}` : ""}</b></span>
                <span className="feedback-chevron" aria-hidden="true">⌄</span>
              </button>
              {open && (
                <div className="feedback-post-detail">
                  {editId === post.id ? (
                    <form className="feedback-edit-form" onSubmit={saveEdit}>
                      <div className="feedback-form-grid">
                        <label><span>닉네임</span><input value={editForm.nickname} onChange={(event) => setEditForm({ ...editForm, nickname: event.target.value })} /></label>
                        {!isAdmin && <label><span>글 비밀번호</span><input type="password" value={editForm.password} onChange={(event) => setEditForm({ ...editForm, password: event.target.value })} required /></label>}
                        <label className="full"><span>분류</span><select value={editForm.category} onChange={(event) => setEditForm({ ...editForm, category: event.target.value })}>{categories.slice(1).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
                        <label className="full"><span>제목</span><input value={editForm.title} onChange={(event) => setEditForm({ ...editForm, title: event.target.value })} /></label>
                        <label className="full"><span>내용</span><textarea value={editForm.body} onChange={(event) => setEditForm({ ...editForm, body: event.target.value })} /></label>
                      </div>
                      <div className="feedback-inline-actions"><button type="button" onClick={() => setEditId(null)}>취소</button><button className="primary" type="submit" disabled={busy}>수정 저장</button></div>
                    </form>
                  ) : <p className="feedback-body">{post.body}</p>}

                  {post.replies.map((reply) => <div className={`feedback-reply ${reply.isAdmin ? "admin" : ""}`} key={reply.id}>
                    <div className="feedback-reply-head"><span><strong>{reply.author}</strong>{reply.isAdmin && <b>운영자</b>}<time>{formatDate(reply.createdAt)}</time></span><button type="button" onClick={() => void removeReply(post.id, reply.id)}>삭제</button></div>
                    <p>{reply.body}</p>
                  </div>)}

                  {!isAdmin && (() => {
                    const draft = commentDrafts[post.id] || emptyComment;
                    return <form className="feedback-comment-form" onSubmit={(event) => void submitComment(event, post.id)}>
                      <div className="feedback-comment-heading"><strong>댓글 남기기</strong><span>비밀번호는 댓글 삭제에 사용합니다.</span></div>
                      <div className="feedback-comment-fields">
                        <label><span>닉네임</span><input value={draft.nickname} maxLength={20} placeholder="2~20자" onChange={(event) => setCommentDrafts((current) => ({ ...current, [post.id]: { ...draft, nickname: event.target.value } }))} required /></label>
                        <label><span>비밀번호</span><input type="password" value={draft.password} maxLength={64} placeholder="4자 이상" onChange={(event) => setCommentDrafts((current) => ({ ...current, [post.id]: { ...draft, password: event.target.value } }))} required /></label>
                        <label className="comment-body"><span>댓글</span><textarea value={draft.body} maxLength={1000} placeholder="의견에 대한 생각이나 사용 경험을 남겨 주세요." onChange={(event) => setCommentDrafts((current) => ({ ...current, [post.id]: { ...draft, body: event.target.value } }))} required /></label>
                        <button type="submit" disabled={busy}>{busy ? "등록 중…" : "댓글 등록"}</button>
                      </div>
                    </form>;
                  })()}

                  {isAdmin && (
                    <div className="feedback-admin-tools">
                      <label><span>처리 상태</span><select value={post.status} onChange={(event) => void setStatus(post.id, event.target.value)}>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label>
                      <label className="admin-reply"><span>운영자 답글</span><textarea value={replyText[post.id] || ""} onChange={(event) => setReplyText({ ...replyText, [post.id]: event.target.value })} placeholder="확인 내용이나 반영 계획을 알려 주세요." /></label>
                      <button className="feedback-reply-button" type="button" onClick={() => void reply(post.id)}>답글 등록</button>
                    </div>
                  )}

                  <div className="feedback-post-actions">
                    <button type="button" onClick={() => void react(post.id)}>♡ 공감 {post.likes}</button>
                    <span />
                    <button type="button" onClick={() => beginEdit(post)}>수정</button>
                    <button className="danger" type="button" onClick={() => void removePost(post)}>삭제</button>
                  </div>
                </div>
              )}
            </article>
          );
        })}
      </div>
    </section>
  );
}
