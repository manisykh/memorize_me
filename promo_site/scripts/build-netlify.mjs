import { rename } from "node:fs/promises";
import { spawn } from "node:child_process";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
// Production endpoints are Netlify Functions, not static export routes.
const routes = ["feedback", "tester-applications"].map((name) => path.join(root, "app", "api", name, "route.ts"));
const parked = [];

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

try {
  for (const route of routes) {
    await rename(route, `${route}.netlify-only`);
    parked.push(route);
  }
  await run(path.join(root, "node_modules", "next", "dist", "bin", "next"), ["build", "--webpack"]);
} finally {
  for (const route of parked.reverse()) await rename(`${route}.netlify-only`, route);
}
