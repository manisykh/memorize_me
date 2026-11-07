import { rename } from "node:fs/promises";
import { spawn } from "node:child_process";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cloudflareRoute = path.join(root, "app", "api", "feedback", "route.ts");
const parkedRoute = `${cloudflareRoute}.cloudflare-only`;

function run(script, args = []) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [script, ...args], {
      cwd: root,
      env: process.env,
      stdio: "inherit",
    });
    child.on("error", reject);
    child.on("exit", (code) => code === 0 ? resolve() : reject(new Error(`${path.basename(script)} exited with code ${code}`)));
  });
}

await run(path.join(root, "scripts", "validate-netlify-env.mjs"));

await rename(cloudflareRoute, parkedRoute);
try {
  await run(path.join(root, "node_modules", "next", "dist", "bin", "next"), ["build", "--webpack"]);
} finally {
  await rename(parkedRoute, cloudflareRoute);
}
