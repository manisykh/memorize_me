import { existsSync, mkdirSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import sharp from "sharp";

const root = resolve(import.meta.dirname, "..");
const outputDir = join(root, "public", "downloads");
const baseUrl = process.argv[2] || "http://localhost:3011";
const edgeCandidates = [
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
];
const edgePath = edgeCandidates.find(existsSync);

if (!edgePath) {
  throw new Error("Microsoft Edge executable was not found.");
}

const exports = [
  ["/app-infographic", "memorize-me-app-guide"],
  ["/learning-infographic", "memorize-me-learning-guide"],
  ["/infographic", "memorize-me-ai-api-guide"],
];

mkdirSync(outputDir, { recursive: true });

for (const [pathname, basename] of exports) {
  const pngPath = join(outputDir, `${basename}.render.png`);
  const jpgPath = join(outputDir, `${basename}.jpg`);
  const profilePath = join(tmpdir(), "memorize-me-edge-export", basename);
  const result = spawnSync(
    edgePath,
    [
      "--headless=new",
      "--disable-gpu",
      "--hide-scrollbars",
      "--run-all-compositor-stages-before-draw",
      "--virtual-time-budget=6000",
      "--force-device-scale-factor=1",
      "--window-size=1080,1920",
      `--user-data-dir=${profilePath}`,
      `--screenshot=${pngPath}`,
      `${baseUrl}${pathname}`,
    ],
    { encoding: "utf8" },
  );

  if (result.status !== 0 || !existsSync(pngPath)) {
    throw new Error(
      `Failed to render ${pathname}: ${result.stderr || result.stdout || `exit ${result.status}`}`,
    );
  }

  await sharp(pngPath)
    .flatten({ background: "#f5f8fc" })
    .jpeg({ quality: 92, chromaSubsampling: "4:4:4" })
    .toFile(jpgPath);
  rmSync(pngPath, { force: true });
  console.log(jpgPath);
}
