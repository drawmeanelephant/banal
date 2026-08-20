# Card I-1 — Notarized + stapled 1.0 release

**Milestone:** M20 · **Lane:** app · **Depends:** F-1 pipeline, C-3 app · **Status:** board — the first `.app` a stranger can keep

## Handoff

- **Not started.** F-1 built the notarize pipeline (`Scripts/notarize.sh`, `make release`) and C-3 ships an ad-hoc signed `.app`, but no Developer ID / notarized / stapled build has been produced on this machine.
- **Not this card:** App Store submission, Sparkle auto-update, an update Settings pane.

## Owns

- `Makefile`, `Scripts/notarize.sh`, `Scripts/` (release path)
- The release checklist — one page in `docs/`, not a wiki

## Do not touch

- The three-column window. This is packaging, not chrome.
- The local ad-hoc build (`make app`) — a developer without a cert still opens their own notes.

## Why

California (M20) is the first honest “a stranger double-clicks and it works” day. The pipeline exists; a real Developer ID certificate must turn it into an actual stapled release.

## Do

1. Sign with a real Developer ID Application certificate (hardened runtime, timestamp).
2. Notarize and staple both the `.app` and the DMG.
3. Build `make release` end to end; keep the ad-hoc fallback for local builds.
4. Verify on a clean Mac (or a clean user account): double-click opens, Gatekeeper shows no warning, the notes-folder picker works, a new note is written.

## Do not

- Ship an unsigned or ad-hoc build as “1.0”.
- Add an update feed or an account.

## Gate

A clean machine double-clicks the DMG, drags BANAL to Applications, opens it, writes a note, and closes. No terminal, no warning, no token.
