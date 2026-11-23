import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, extname, join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const origin = process.env.STANDALONE_SOURCE_URL?.trim() || "http://localhost:3030";
const outputPaths = [
  join(root, "public", "downloads", "memorize-me-homepage-current.html"),
  join(root, "..", "deliverables", "memorize-me-homepage-current.html"),
  join(root, "..", "deliverables", "memorize-me-homepage-latest.html"),
];

const cssPaths = [
  "/app/globals.css",
  "/app/manual.css",
  "/app/feedback.css",
  "/app/home-v2.module.css",
];

const assetPaths = [
  "/app-icon-192.png",
  "/media/hero/wordbook-hero-bg-v1.png",
  "/media/hero/wordbook-hero-bg-mobile-v1.png",
  "/media/feature/sheet-selection-current.svg",
  "/media/latest/learning-current.png",
  "/media/showcase/review-today.jpg",
  "/media/showcase/flashcard-action.jpg",
  "/media/showcase/quiz-choice.jpg",
  "/media/showcase/quiz-spelling.jpg",
  "/media/current-20261107/learning-overview.jpg",
  "/media/showcase/stats-memory.jpg",
  "/media/showcase/stats-schedule.jpg",
  "/media/showcase/ai-menu.jpg",
  "/media/manual/pdf-options.jpg",
  "/media/video/wordbook-import.mp4",
  "/media/video/flashcard.mp4",
  "/media/video/quiz-choice.mp4",
  "/media/video/quiz-spelling.mp4",
  "/media/video/mistakes.mp4",
  "/media/video/review.mp4",
  "/media/video/test-sheet.mp4",
  "/media/video/posters/wordbook-import.jpg",
  "/media/video/posters/flashcard.jpg",
  "/media/video/posters/quiz-choice.jpg",
  "/media/video/posters/quiz-spelling.jpg",
  "/media/video/posters/mistakes.jpg",
  "/media/video/posters/review.jpg",
  "/media/video/posters/test-sheet.jpg",
];

const mimeByExtension = {
  ".css": "text/css",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".mp4": "video/mp4",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

async function fetchText(path) {
  const response = await fetch(`${origin}${path}`);
  if (!response.ok) throw new Error(`Failed to fetch ${path}: ${response.status}`);
  return response.text();
}

function extractViteCss(moduleSource, path) {
  const match = moduleSource.match(
    /const __vite__css = ("(?:\\.|[^"\\])*")\s*\n__vite__updateStyle/,
  );
  if (!match) throw new Error(`Could not extract CSS from ${path}`);
  return JSON.parse(match[1]);
}

function dataUri(path) {
  const extension = extname(path).toLowerCase();
  const mime = mimeByExtension[extension];
  if (!mime) throw new Error(`Unsupported asset type: ${path}`);
  const bytes = readFileSync(join(root, "public", path.slice(1)));
  return `data:${mime};base64,${bytes.toString("base64")}`;
}

const standaloneCss = `
.standalone-mobile-menu{display:none;padding:12px 20px 20px;background:#fff;border-top:1px solid #dce5f0}
.standalone-mobile-menu[data-open="true"]{display:grid;gap:4px}
.standalone-mobile-menu a{padding:13px 8px;font-weight:800;color:#102b54;text-decoration:none}
.standalone-lightbox{position:fixed;inset:0;z-index:9999;display:grid;place-items:center;padding:24px;background:rgba(2,18,48,.78)}
.standalone-lightbox[hidden]{display:none}
.standalone-lightbox button{position:absolute;top:20px;right:20px;padding:11px 16px;color:#fff;background:#0b5fd8;border:0;border-radius:999px;font-weight:800;cursor:pointer}
.standalone-lightbox figure{max-width:min(92vw,760px);max-height:88vh;margin:0;display:grid;justify-items:center;gap:10px}
.standalone-lightbox img{max-width:100%;max-height:80vh;border-radius:24px;box-shadow:0 24px 70px rgba(0,0,0,.35)}
.standalone-lightbox figcaption{color:#fff;font-weight:800}
@media(min-width:901px){.standalone-mobile-menu{display:none!important}}
`;

const standaloneScript = String.raw`
(() => {
  const byClass = (name, root = document) => root.querySelector('[class*="_' + name + '_"]');
  const allByClass = (name, root = document) => [...root.querySelectorAll('[class*="_' + name + '_"]')];
  const pageUrl = 'https://memorizeme-app.netlify.app';

  const setupVideo = (video) => {
    if (!video || video.dataset.standaloneReady) return;
    video.dataset.standaloneReady = 'true';
    video.muted = true;
    video.playsInline = true;
    const label = video.getAttribute('aria-label') || '';
    const start = Number(video.dataset.start || 0.2);
    const end = Number(video.dataset.end || (label.includes('가져올 시트') ? 13.25 : label.includes('플래시카드') ? 6.85 : 0));
    const play = () => video.play().catch(() => undefined);
    const reset = () => { if (Math.abs(video.currentTime - start) > .2) video.currentTime = start; };
    video.addEventListener('loadedmetadata', () => { reset(); play(); });
    video.addEventListener('timeupdate', () => { if (end > 0 && video.currentTime >= end) { video.currentTime = start; play(); } });
    const observer = new IntersectionObserver(([entry]) => entry.isIntersecting ? play() : video.pause(), { threshold: .18 });
    observer.observe(video);
    if (video.readyState >= 1) { reset(); play(); }
  };
  document.querySelectorAll('video').forEach(setupVideo);

  const menuButton = byClass('menuButton');
  const header = byClass('header');
  if (menuButton && header) {
    const menu = document.createElement('nav');
    menu.className = 'standalone-mobile-menu';
    menu.id = 'standalone-mobile-menu';
    menu.setAttribute('aria-label', '모바일 메뉴');
    menu.dataset.open = 'false';
    menu.innerHTML = '<a href="#journey">시작하기</a><a href="#learning">학습 방식</a><a href="#ai">AI 학습</a><a href="#faq">FAQ</a><a href="' + pageUrl + '/ai-api">AI API 연결 가이드</a><a href="' + pageUrl + '/feedback">의견 게시판</a>';
    header.append(menu);
    menuButton.setAttribute('aria-controls', menu.id);
    menuButton.addEventListener('click', () => {
      const open = menu.dataset.open !== 'true';
      menu.dataset.open = String(open);
      menuButton.setAttribute('aria-expanded', String(open));
      const glyph = menuButton.querySelector('[aria-hidden="true"]');
      if (glyph) glyph.textContent = open ? '×' : '☰';
    });
    menu.addEventListener('click', () => { menu.dataset.open = 'false'; menuButton.setAttribute('aria-expanded', 'false'); });
  }

  const journeyArticles = [...document.querySelectorAll('[data-step]')];
  const journeySticky = byClass('journeySticky');
  const activeJourneyClass = journeyArticles.find((article) => article.className)?.className || '';
  const journeyLabels = { import: '단어장 준비', learn: '첫 학습', review: '오늘 복습' };
  let activeJourney = '';
  const showJourney = (key) => {
    if (!journeySticky || activeJourney === key) return;
    const article = journeyArticles.find((item) => item.dataset.step === key);
    const mobile = article && byClass('mobileJourneyImage', article);
    const frame = mobile && byClass('motionFrame', mobile);
    if (!article || !frame) return;
    activeJourney = key;
    journeyArticles.forEach((item) => item.className = item.dataset.step === key ? activeJourneyClass : '');
    const clone = frame.cloneNode(true);
    const label = document.createElement('p');
    label.textContent = journeyLabels[key] || '';
    journeySticky.replaceChildren(clone, label);
    clone.querySelectorAll('video').forEach(setupVideo);
  };
  const updateJourney = () => {
    const line = window.innerHeight * .52;
    let next = journeyArticles[0]?.dataset.step || 'import';
    journeyArticles.forEach((article) => {
      const rect = article.getBoundingClientRect();
      if (rect.top + Math.min(rect.height * .38, 240) <= line) next = article.dataset.step || next;
    });
    showJourney(next);
  };
  if (journeyArticles.length && journeySticky) {
    updateJourney();
    let journeyFrame = 0;
    const scheduleJourney = () => { if (!journeyFrame) journeyFrame = requestAnimationFrame(() => { journeyFrame = 0; updateJourney(); }); };
    addEventListener('scroll', scheduleJourney, { passive: true });
    addEventListener('resize', scheduleJourney);
  }

  const modes = [
    { title: '플래시카드', body: ['뜻과 예문을 확인하고', '알아요·몰라요로 기억을 쌓습니다.'], poster: '/media/video/posters/flashcard.jpg', video: '/media/video/flashcard.mp4', alt: '단어와 응답 버튼이 보이는 플래시카드 학습 화면', start: .1, end: 13.94 },
    { title: '객관식 퀴즈', body: ['여러 보기에서 정확한 뜻을 고르며', '기억을 확인합니다.'], poster: '/media/video/posters/quiz-choice.jpg', video: '/media/video/quiz-choice.mp4', alt: '단어의 뜻을 보기에서 고르는 객관식 퀴즈 화면', start: .1, end: 19.17 },
    { title: '스펠링 퀴즈', body: ['뜻을 보고 철자를 직접 입력해', '기억을 더 단단하게 만듭니다.'], poster: '/media/video/posters/quiz-spelling.jpg', video: '/media/video/quiz-spelling.mp4', alt: '뜻을 보고 영단어 철자를 입력하는 스펠링 퀴즈 화면', start: .1, end: 19.09 },
    { title: '오답노트', body: ['틀린 단어와 다시 확인할 기록을 모아', '취약한 부분을 반복합니다.'], poster: '/media/video/posters/mistakes.jpg', video: '/media/video/mistakes.mp4', alt: '누적 오답과 다시 확인할 학습 기록을 보여주는 화면', start: .1, end: 10.55 },
    { title: '복습하기', body: ['오늘 필요한 단어를 모아 복습하고', '다음 복습 일정까지 확인합니다.'], poster: '/media/video/posters/review.jpg', video: '/media/video/review.mp4', alt: '오늘 복습할 단어 수와 복습 시작 버튼을 보여주는 화면', start: .1, end: 11.7 },
    { title: '시험지 만들기', body: ['학습할 단어를 골라 시험지로 만들고', 'PDF·Excel·HTML로 공유합니다.'], poster: '/media/video/posters/test-sheet.jpg', video: '/media/video/test-sheet.mp4', alt: '시험지 파일 형식과 출력 구성을 선택하는 화면', start: .1, end: 14.9 },
  ];
  const tabs = byClass('modeTabs');
  const modeCopy = byClass('modeCopy');
  const panel = byClass('modePanel');
  const controls = byClass('carouselControls');
  const expand = byClass('expandButton');
  const initialFrame = panel && byClass('motionFrame', panel)?.cloneNode(true);
  let activeMode = 0;
  const showMode = (requested) => {
    if (!tabs || !modeCopy || !panel) return;
    activeMode = (requested + modes.length) % modes.length;
    const mode = modes[activeMode];
    const buttons = [...tabs.querySelectorAll('button')];
    buttons.forEach((button, index) => { button.setAttribute('aria-selected', String(index === activeMode)); button.tabIndex = index === activeMode ? 0 : -1; });
    const selectedButton = buttons[activeMode];
    if (selectedButton && tabs.scrollWidth > tabs.clientWidth) {
      tabs.scrollTo({ left: selectedButton.offsetLeft - tabs.offsetLeft - (tabs.clientWidth - selectedButton.offsetWidth) / 2, behavior: 'smooth' });
    }
    const title = modeCopy.querySelector('h3');
    const body = modeCopy.querySelector(':scope > p');
    const titleIcon = byClass('studyModeIcon', modeCopy);
    const buttonIcon = buttons[activeMode] && byClass('studyModeIcon', buttons[activeMode]);
    if (title) title.textContent = mode.title;
    if (body) body.innerHTML = '<span class="copy-lines">' + mode.body.map((line) => '<span class="copy-line">' + line + '</span>').join('') + '</span>';
    if (titleIcon && buttonIcon) { titleIcon.className = buttonIcon.className; titleIcon.innerHTML = buttonIcon.innerHTML; }
    const frame = byClass('motionFrame', panel);
    if (frame && initialFrame) {
      const clone = initialFrame.cloneNode(true);
      const video = clone.querySelector('video');
      const source = clone.querySelector('source');
      if (mode.video && video && source) {
        video.poster = mode.poster;
        video.setAttribute('aria-label', mode.alt);
        video.dataset.start = String(mode.start ?? .1);
        video.dataset.end = String(mode.end);
        video.removeAttribute('data-standalone-ready');
        source.src = mode.video;
        video.load();
      } else {
        const image = document.createElement('img');
        image.src = mode.poster;
        image.alt = mode.alt;
        image.loading = 'lazy';
        clone.replaceChildren(image);
      }
      frame.replaceWith(clone);
      clone.querySelectorAll('video').forEach(setupVideo);
    }
    if (controls) {
      const dots = [...controls.querySelectorAll('div button')];
      dots.forEach((dot, index) => index === activeMode ? dot.setAttribute('aria-current', 'true') : dot.removeAttribute('aria-current'));
    }
  };
  if (tabs) {
    [...tabs.querySelectorAll('button')].forEach((button, index) => button.addEventListener('click', () => showMode(index)));
    tabs.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowRight' || event.key === 'ArrowDown') { event.preventDefault(); showMode(activeMode + 1); }
      if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') { event.preventDefault(); showMode(activeMode - 1); }
    });
  }
  if (controls) {
    const direct = [...controls.querySelectorAll(':scope > button')];
    if (direct[0]) direct[0].addEventListener('click', () => showMode(activeMode - 1));
    if (direct[1]) direct[1].addEventListener('click', () => showMode(activeMode + 1));
    [...controls.querySelectorAll('div button')].forEach((button, index) => button.addEventListener('click', () => showMode(index)));
  }
  const carousel = byClass('modeCarousel');
  if (carousel) {
    let startX = 0;
    carousel.addEventListener('touchstart', (event) => { startX = event.changedTouches[0]?.clientX || 0; }, { passive: true });
    carousel.addEventListener('touchend', (event) => {
      const distance = (event.changedTouches[0]?.clientX || startX) - startX;
      if (Math.abs(distance) >= 48) showMode(activeMode + (distance < 0 ? 1 : -1));
    }, { passive: true });
  }

  const lightbox = document.createElement('div');
  lightbox.className = 'standalone-lightbox';
  lightbox.hidden = true;
  lightbox.innerHTML = '<button type="button" aria-label="확대 화면 닫기">닫기 ×</button><figure><img alt=""><figcaption></figcaption></figure>';
  document.body.append(lightbox);
  const closeLightbox = () => { lightbox.hidden = true; document.body.style.overflow = ''; };
  lightbox.querySelector('button').addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', (event) => { if (event.target === lightbox) closeLightbox(); });
  addEventListener('keydown', (event) => { if (event.key === 'Escape') closeLightbox(); });
  if (expand) expand.addEventListener('click', () => {
    const mode = modes[activeMode];
    lightbox.querySelector('img').src = mode.poster;
    lightbox.querySelector('img').alt = mode.alt;
    lightbox.querySelector('figcaption').textContent = mode.title;
    lightbox.hidden = false;
    document.body.style.overflow = 'hidden';
  });
})();
`;

let html = await fetchText("/");
const css = (
  await Promise.all(
    cssPaths.map(async (path) => extractViteCss(await fetchText(path), path)),
  )
).join("\n");

html = html
  .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "")
  .replace(/<link\b[^>]+href=["']\/app\/(?:globals|manual|feedback|home-v2\.module)\.css["'][^>]*>/gi, "")
  .replace(/<link\b[^>]+href=["']\/@id\/[^"']+["'][^>]*>/gi, "")
  .replace(/href=["']\/(manual|feedback|ai-api|privacy|account-deletion)([^"']*)["']/g, (_match, route, rest) => `href="https://memorizeme-app.netlify.app/${route}${rest}"`)
  .replace("</head>", `<style>${css}\n${standaloneCss}</style></head>`)
  .replace("</body>", `<script>${standaloneScript}</script></body>`);

for (const path of assetPaths) {
  html = html.split(path).join(dataUri(path));
}

html = html
  .replaceAll(`${origin}/`, "")
  .replaceAll("http://localhost:3030", "");

if (/\/(?:media|app-icon-192\.png)/.test(html)) {
  throw new Error("Standalone HTML still contains unresolved local assets");
}
if (!html.includes("data:video/mp4;base64,")) {
  throw new Error("Standalone HTML does not contain embedded videos");
}

for (const outputPath of outputPaths) {
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, html, "utf8");
  console.log(outputPath);
}
