# Design QA — wordbook management and import flow

- Date: 2026-09-26
- Target viewport: 390 × 844 logical pixels, light theme
- State: populated wordbook management, populated word list, add/edit form, merge selection, Google spreadsheet selection, sheet selection, import mapping dialog

## Source visual truth

All seven source mockups are 853 × 1844 pixels:

- Wordbook management: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-92606773-0fb0-4070-b999-ba6c78568d6e.png`
- Word list and management: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-3d026a98-45c8-4b55-b807-87cae2c9c89a.png`
- Add/edit word: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-0980a32b-0845-4de5-9294-55270d954764.png`
- Merge wordbooks: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-f50b92db-036c-4e2b-9edd-612c31674e0a.png`
- Google spreadsheet selection: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-56542211-a0d9-40b9-b26f-357f58d8b755.png`
- Google sheet selection: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-8bfb3d6f-f521-472e-824d-90368826b826.png`
- Import mapping: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-f88dcc70-3fb5-4f2f-983e-83fedafb024a.png`

## Implementation evidence

- Implementation screenshot path: unavailable
- Implementation pixel dimensions: unavailable
- CSS/logical viewport: target 390 × 844
- Density normalization: not performed because an implementation capture was unavailable
- Blocker: `adb devices -l` returned no connected Android device. The native Flutter routes could not be rendered in their required data and interaction states.

## Static verification

- `dart format` completed for all seven changed files.
- Targeted `dart analyze` completed successfully with no reported issues.
- `git diff --check` found no whitespace errors; only existing Git line-ending notices were emitted.
- Existing create, edit, delete, activate, plan, share, merge, Drive picker, recent spreadsheet, multi-sheet import, column mapping, header detection, additional-meaning selection, and post-import navigation behaviors remain connected.

## Fidelity surfaces

- Fonts and typography: app theme typography with deep-navy headings, stronger section hierarchy, muted supporting copy, truncation for long wordbook/sheet names; rendered comparison pending.
- Spacing and layout rhythm: 20 px page insets, 14 px grouped-card radius, 12–18 px internal spacing, grouped row dividers, and sticky primary actions; rendered comparison pending.
- Colors and tokens: `MemorizeIdentity` canvas, white surface, navy ink, iOS blue action, mint success, coral review, pale-blue context, and cool-gray border tokens applied; rendered comparison pending.
- Image quality and asset fidelity: the existing Google Sheets raster asset is retained; remaining symbols use consistent Cupertino icons rather than handcrafted substitutes; rendered comparison pending.
- Copy and content: mockup hierarchy is reflected while dynamic names, counts, source labels, plan state, validation, loading, empty, and error copy remain data-driven.
- Responsiveness and accessibility: layouts use `Expanded`, scroll views, truncation, safe areas, full-width bottom actions, and practical row tap targets; device-size and text-scale checks remain pending.

## Findings

- [P1] Rendered implementation cannot be compared with the seven source mockups.
  - Location: all seven target screens/dialogs.
  - Evidence: no Android device is listed by ADB, so no implementation screenshots exist.
  - Impact: exact text wrapping, safe-area behavior, keyboard interaction, modal height, scrolling, and pixel-level fidelity cannot be certified.
  - Fix: connect the target device, open each matching populated state, capture at native density, normalize to the source dimensions, and compare source plus implementation in a single comparison input.

## Full-view and focused-region comparison

- Full-view comparison evidence: blocked because implementation captures are unavailable.
- Focused-region comparison evidence: blocked for active/inactive wordbook rows, sticky actions, selection indicators, Google Sheets asset treatment, and import-mapping controls for the same reason.

## Comparison history

- Iteration 1: seven source mockups were opened, implementation was updated, and static analysis passed. The first rendered comparison was blocked because no ADB device was connected.

## Implementation checklist

- Connect the target Android device and confirm it appears in `adb devices -l`.
- Run the light-theme app and populate each route with the same state as its mockup.
- Capture all seven screens without rescaling or device-frame mismatch.
- Compare each source/capture pair together and resolve any P0/P1/P2 typography, spacing, color, icon, copy, overflow, or interaction differences.

## Follow-up polish

- Confirm the import-mapping dialog action row and keyboard inset on compact devices.
- Confirm long Korean and spreadsheet names wrap or truncate without shifting selection controls.
- Confirm dark and vision themes retain semantic contrast after light-theme fidelity is accepted.

## AI setup screens — 2026-10-12

### Source visual truth

- Example and meaning enrichment: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-2b662bf8-2585-424d-87c1-095c6bdc777f.png`
- AI quiz generation: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-b542dd15-29ef-476f-9cdc-9c7f1080b2a2.png`
- Grammar generation, final accordion direction: `C:\Users\manis\.codex\generated_images\01a07040-f246-72c1-8b26-4b764692d4f6\exec-a6c6f5f6-2f84-4718-9a26-eb3834ff162f.png`

### Implementation evidence

- Intended viewport: 390 × 844 logical pixels, mobile portrait
- Implementation screenshot path and pixel dimensions: unavailable
- Density normalization: unavailable
- State: initial AI setup, selected quiz scope, and expanded grammar-topic state

### Static verification

- Targeted Flutter analysis passed with no issues.
- Grammar curriculum, AI review, AI quiz validation, SRS, and quiz-review tests passed (33 tests).

### Findings

- [P1] The rendered AI setup screens cannot yet be compared with their three source mockups.
  - Evidence: no Android device or emulator is connected, so matching Flutter screenshots cannot be captured.
  - Impact: typography, vertical density, wrapping, bottom safe-area spacing, and accordion expansion remain visually unverified.
  - Fix: capture all three states on a 390 × 844-equivalent device and compare each source/capture pair together.

### Fidelity surfaces

- Fonts and typography: app theme weights and hierarchy are implemented; rendered comparison pending.
- Spacing and layout rhythm: grouped rows, 18 px page insets, 20–24 px radii, and safe-area bottom actions are implemented; rendered comparison pending.
- Colors and tokens: existing primary blue, mint connected state, coral errors, navy text, and pale blue surfaces are used; rendered comparison pending.
- Image quality and assets: no new raster assets are required; standard Cupertino icons are used.
- Copy and content: selected provider, wordbook, dynamic counts, scope, curriculum, topic, subtopic, and API disclosure are data-driven.

### Implementation checklist

- Capture 예문·뜻 보강 initial state.
- Capture AI 퀴즈 생성 with 오늘 학습 selected.
- Capture 문법 문제 생성 with 시제 expanded and two 세부 주제 selected.
- Compare source and implementation together and resolve any P0/P1/P2 differences.

final result: blocked

## Homepage learning-mode frame density — 2026-11-24

### Source visual truth

- Requested target: `C:\Users\manis\AppData\Local\Temp\codex-clipboard-fc39f7de-21f2-4e6d-bd45-c1ad59d61aee.png`
- Target state: desktop learning-mode carousel with a lower video stage, smaller previous/next controls, and a shorter outer navy frame.

### Implementation evidence

- Implementation screenshot path: unavailable
- Source pixel dimensions: 1030 × 770
- Intended viewport/state: desktop, 플래시카드 selected
- Static evidence: carousel height reduced from 680 px to 630 px, top stage spacing increased to 14 px, and arrow controls reduced from 44 px to 36 px.

### Fidelity surfaces

- Fonts and typography: unchanged.
- Spacing and layout rhythm: outer frame height is reduced by 50 px; the media stage begins 14 px lower; carousel control insets are tightened.
- Colors and visual tokens: unchanged.
- Image quality and asset fidelity: the existing flashcard video and frame treatment remain unchanged.
- Copy and content: unchanged.

### Findings

- [P1] Browser-rendered comparison remains unavailable because the Codex in-app browser cannot initialize its kernel assets.
  - Impact: exact visible balance between the left content, video stage, and bottom controls cannot be certified from a matching screenshot.
  - Fix: capture the local homepage at the reference width once the in-app browser is available and compare the learning section against the supplied source image.

### Comparison history

- Iteration 1: reduced the fixed carousel height, lowered the video stage, tightened control insets, and reduced arrow size. Production build and standalone export passed; rendered comparison remained blocked.

final result: blocked

## Homepage hero background coverage — 2026-11-24

### Source visual truth

- Requested target: `C:\Users\manis\AppData\Local\Temp\codex-clipboard-c32312d6-b29f-4191-8231-cc12bdbc0884.png`
- Target state: homepage hero at a roughly 1070 px desktop viewport, with the wordbook photograph continuing behind the Android · Google Play release-status row.

### Implementation evidence

- Implementation screenshot path: unavailable
- Viewport: intended desktop widths from 621 px through 1100 px, plus existing mobile and wide-desktop breakpoints
- Source pixel dimensions: 1070 × 560
- Implementation pixel dimensions and density normalization: unavailable
- Static evidence: the `max-width: 1100px` hero background override now uses `background-size: cover` and a centered crop instead of `100% auto`, so the pseudo-element covers the full hero height.

### Fidelity surfaces

- Fonts and typography: unchanged from the existing homepage.
- Spacing and layout rhythm: hero content and release-status spacing are unchanged.
- Colors and visual tokens: existing photograph, overlay, and background tokens are unchanged.
- Image quality and asset fidelity: the original hero image remains in use; only its responsive sizing and crop behavior changed.
- Copy and content: unchanged.

### Findings

- [P1] Browser-rendered comparison is unavailable.
  - Evidence: the Codex in-app browser failed to initialize because its kernel asset path could not be written.
  - Impact: the exact crop at representative desktop and mobile widths cannot be certified from rendered evidence.
  - Fix: reopen the local page when the in-app browser is available and compare the hero against the supplied screenshot at matching width.

### Full-view and focused-region comparison

- Full-view comparison: blocked because no browser screenshot could be captured.
- Focused-region comparison: blocked for the format icons and Android release-status row for the same reason.

### Comparison history

- Iteration 1: identified the `background-size: 100% auto` breakpoint as the reason the raster ended before the hero content; changed it to `cover`; production build and standalone export passed; rendered comparison remained blocked by the in-app browser initialization failure.

final result: blocked
