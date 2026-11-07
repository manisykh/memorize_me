import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const templatePath = join(root, "standalone", "homepage.template.html");
const outputPaths = [
  join(root, "public", "downloads", "memorize-me-homepage.html"),
  join(root, "..", "deliverables", "memorize-me-homepage-latest.html"),
];

const assets = {
  APP_ICON: "public/app-icon.png",
  HOME_SCREEN: "public/media/current-20261107/home-progress.jpg",
  AI_SCREEN: "public/media/latest/ai-learning.png",
  ONBOARDING_ONE: "public/media/latest/onboarding-01.png",
  ONBOARDING_TWO: "public/media/feature/learning-modes.png",
  ONBOARDING_THREE: "public/media/latest/onboarding-03.png",
  AI_SETTINGS: "public/media/latest/ai-settings.png",
  GOOGLE_PICKER: "public/media/feature/google-picker.jpg",
  SHEET_SELECTION: "public/media/feature/sheet-selection-current.svg",
  FLASHCARD_SCREEN: "public/media/current-20261107/flashcard-learning.jpg",
  QUIZ_MULTIPLE: "public/media/feature/quiz-multiple-choice-current.jpg",
  QUIZ_SPELLING: "public/media/feature/quiz-spelling-current.jpg",
  HOME_TODAY: "public/media/feature/home-today.png",
  REVIEW_TAB: "public/media/current-20261107/learning-overview.jpg",
  WORDBOOK_ADD: "public/media/feature/wordbook-add.png",
  LEARNING_MODES: "public/media/latest/flashcard-current.png",
  REVIEW_TODAY: "public/media/latest/learning-current.png",
  LEARNING_OVERVIEW: "public/media/current-20261107/learning-overview.jpg",
  STATS_REVIEW: "public/media/current-20261107/stats-word2.jpg",
  FLASHCARD_REVIEW: "public/media/current-20261107/flashcard-review.jpg",
};

const mimeByExt = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".svg": "image/svg+xml",
};
let html = readFileSync(templatePath, "utf8");

for (const [token, relativePath] of Object.entries(assets)) {
  const absolutePath = join(root, relativePath);
  const mime = mimeByExt[extname(absolutePath).toLowerCase()];
  if (!mime) throw new Error(`Unsupported image type: ${relativePath}`);
  const dataUri = `data:${mime};base64,${readFileSync(absolutePath).toString("base64")}`;
  html = html.replaceAll(`{{${token}}}`, dataUri);
}

for (const outputPath of outputPaths) {
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, html, "utf8");
  console.log(outputPath);
}
