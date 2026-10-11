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

final result: blocked
