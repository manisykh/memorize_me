import assert from "node:assert/strict";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

async function renderHtml(pathname) {
  const response = await render(pathname);
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  return response.text();
}

test("server-renders the production landing page and legal links", async () => {
  const html = await renderHtml("/");

  assert.match(html, /<title>Memorize Me \| 시트에서 시작하는 단어 학습<\/title>/i);
  assert.match(html, /href="\/privacy"[^>]*>개인정보 처리방침<\/a>/);
  assert.match(html, /href="\/account-deletion"[^>]*>계정 삭제<\/a>/);
  assert.match(html, /href="\/manual"[^>]*>사용 가이드<\/a>/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/i);
});

test("server-renders the privacy policy", async () => {
  const html = await renderHtml("/privacy");

  assert.match(html, /개인정보 처리방침/);
  assert.match(html, /AI API 키/);
  assert.match(html, /보관과 삭제/);
  assert.match(html, /href="\/account-deletion"/);
});

test("server-renders the external account deletion path", async () => {
  const html = await renderHtml("/account-deletion");

  assert.match(html, /계정 삭제 요청/);
  assert.match(html, /앱 없이 삭제 요청/);
  assert.match(html, /mailto:release-check@example\.com/);
  assert.doesNotMatch(html, /공개 지원 이메일이 아직 설정되지 않았습니다/);
});
