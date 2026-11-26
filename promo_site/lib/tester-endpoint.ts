import { getStore } from "@netlify/blobs";
import { createTesterHandler, type PrivateStore } from "./tester-service";

export function createNetlifyTesterStore(): PrivateStore {
  const store = getStore("memorize-tester-applications", { consistency: "strong" });
  return {
    async read(key) {
      const entry = await store.getWithMetadata(key, { type: "json", consistency: "strong" });
      if (entry && !entry.etag) throw new Error("Missing storage version");
      return entry ? { data: entry.data, etag: entry.etag! } : null;
    },
    async write(key, data, condition) { return (await store.setJSON(key, data, condition)).modified; },
    async keys(prefix) {
      const keys: string[] = [];
      for await (const page of store.list({ prefix, paginate: true })) keys.push(...page.blobs.map((blob) => blob.key));
      return keys;
    },
    remove: (key) => store.delete(key),
  };
}

// Same signed, HttpOnly administrator cookie already used by the feedback board.
export async function isTesterAdmin(request: Request) {
  const secret = process.env.FEEDBACK_SESSION_SECRET?.trim();
  if (!secret || secret.length < 32) return false;
  const value = request.headers.get("cookie")?.match(/(?:^|;\s*)memorize_feedback_admin=([^;]+)/)?.[1];
  const [expiresText, signature] = value?.split(".") || [];
  const expires = Number(expiresText);
  if (!expires || expires < Date.now() / 1000 || !/^[\w-]+$/.test(signature || "")) return false;
  try {
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["verify"]);
    const binary = atob(signature.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - signature.length % 4) % 4));
    return await crypto.subtle.verify("HMAC", key, Uint8Array.from(binary, (character) => character.charCodeAt(0)), new TextEncoder().encode(expiresText));
  } catch { return false; }
}

export const testerEndpoint = createTesterHandler({ env: process.env, store: createNetlifyTesterStore, isAdmin: isTesterAdmin });
