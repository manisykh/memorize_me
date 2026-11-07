# Memorize Me homepage design QA

## Reference and implementation evidence

- Selected visual direction: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-80e9dd8d-86c4-46ab-8b9f-212a3e159b19.png`
- Desktop implementation capture: `audit/home-responsive-implementation-2026-11-04/desktop.png`
- Mobile implementation capture: `audit/home-responsive-implementation-2026-11-04/mobile.png`
- Side-by-side comparison: `audit/home-responsive-implementation-2026-11-04/comparison.png`
- Preview URL used for QA: `http://localhost:3030/`

## Viewports and states

- Mobile: 390 × 844 CSS pixels, full-page capture.
- Desktop: 1440 × 1024 CSS pixels, full-page capture.
- Journey states checked: import, learn, review.
- Disclosure states checked: AI details and FAQ.
- Overlay state checked: app-screen lightbox opened and closed.
- Navigation states checked: mobile menu and desktop navigation.
- Mobile sticky action bar checked at 390 px and verified hidden at 1440 px.

## Findings and corrections

1. Removed the root legacy `index.html` that intercepted the new RSC homepage. The preserved standalone copies remain under `standalone/` and `public/downloads/`.
2. Kept the selected desktop message, “이미 만든 단어장, 그대로 외우세요.”, as the primary value proposition.
3. Applied the selected mobile structure: vertical hero, fixed bottom action bar, and tabbed import → learn → review journey.
4. Reused current application screenshots only; no unapproved replacement imagery was introduced.
5. Added responsive desktop composition, accessible tab semantics, keyboard-dismissable lightbox, reduced-motion handling, and FAQ structured data.
6. Verified that the latest app screen remains legible rather than being cropped to an uninformative fragment.

## Verification

- Modern Node build (`v24.22.1`): passed.
- Targeted ESLint for the new homepage files: passed with only the existing `img` optimization advisory warnings.
- Browser console errors during interaction QA: none.
- Repository-wide lint still reports pre-existing errors in unrelated legal, feedback, manual, and generated environment files.
- The existing rendered-HTML test harness cannot load the Cloudflare virtual module under plain Node (`cloudflare:` URL scheme); this is an environment limitation rather than a homepage compile failure.

## Final result

final result: passed

---

## Support navigation and learning carousel refresh — 2026-11-04

### Evidence

- Current desktop homepage: `audit/support-learning-refresh-2026-11-04/home-desktop-current.png`
- Current mobile homepage: `audit/support-learning-refresh-2026-11-04/home-mobile-current.png`
- Current desktop guide: `audit/support-learning-refresh-2026-11-04/manual-desktop-current.png`
- Current mobile guide: `audit/support-learning-refresh-2026-11-04/manual-mobile-current.png`
- Reference comparison: `audit/support-learning-refresh-2026-11-04/comparison-current.png`
- QA preview: `http://localhost:3031/`

### Checks and corrections

1. Removed the legacy root `manual.html` that intercepted `/manual` and exposed the old navigation and onboarding UI.
2. The homepage now presents User Guide and Tester Board as separate, equal support entry cards; the guide header is reduced to brand and Home.
3. The learning-method selector and phone carousel are synchronized in both directions. Selecting “객관식 퀴즈” moved the carousel by one viewport (`scrollLeft 295.2 / clientWidth 298`) and updated `aria-selected=true`.
4. Flashcard, multiple-choice, spelling, and review screens use current application captures only.
5. Phone frames use a 9:20 container with `object-fit: contain`. Source captures were verified at 0.45–0.48 width/height ratios, so no image is stretched or cropped.
6. Mobile (390 × 844) and desktop (1440 × 1024) layouts were visually inspected. The mobile guide keeps a visible “홈으로 돌아가기” action.
7. Targeted ESLint and the production Vinext build both pass; browser interaction QA produced no console errors.

### Final result

final result: passed
