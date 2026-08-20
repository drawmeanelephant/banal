# Card I-2 — Whole-window release sit

**Milestone:** M20 · **Lane:** chrome · **Depends:** I-1 build · **Status:** board — the human pass that closes C-1, D-1/D-2, and F-8

## Handoff

- **Not started.** The code-backed sit is green, but the GUI passes are still open: C-1 (30s type / ⌘Z, light+dark 720/1100/1400, VoiceOver), D-1/D-2 visual gates (page, not browser), and F-8 GUI gate (Open With on a real machine).
- **Not this card:** new features. Anything this sit finds is the M13–M19 drive.

## Owns

- [`TESTING-WINDOW.md`](../TESTING-WINDOW.md), [`TESTING-SYSTEM.md`](../TESTING-SYSTEM.md) (the scripts)
- Sit notes land in `STATUS.md` and the C/D/F card Handoff blocks

## Do not touch

- Source-as-truth in the editor. If the sit hates the caret, fix the caret — do not swap in a preview.

## Why

Every board has deferred one human pass. Before 1.0, one person runs the whole window on the *signed* build and either says “Apple shipped it” or files bugs that outrank every remaining card.

## Do

1. Run the C-1 script against the signed `.app`: type 30s, ⌘Z, switch notes, light + dark at 720 / 1100 / 1400, VoiceOver.
2. Sit D-1/D-2: whisper is hints, not a theme; Read is a page, not a browser.
3. Sit F-8: Open With / double-click / Dock drag for `.md`, `.textile`, `.cook`.
4. Record every rough edge as a small sit bug. The drive (M13–M19) is those bugs, nothing else.

## Do not

- Book Japan. Do not add a surface because the sit felt thin.

## Gate

One human, one afternoon, the signed build. The window still looks like folders · list · page, and the bugs are written down.
