# Card I-3 — 1.0 copy pass

**Milestone:** M20 · **Lane:** copy · **Depends:** I-2 sit · **Status:** board — Help, About, empty states, release notes

## Handoff

- **Not started.** Copy exists (Help Book, About, empty states) but has not been read aloud as a set against the 1.0 window.
- **Not this card:** localization, a marketing site, an onboarding tour.

## Owns

- `Resources/BANAL.help/` (the one landing page)
- About / empty-state strings in `Sources/BANALApp/`
- `CHANGELOG.md` release notes for 1.0

## Do not touch

- The voice rules in [`../HORIZON.md`](../HORIZON.md) (short, warm, gone). Read them before rewriting.

## Why

California is “boring on purpose.” The sentences should sound like a person who works here and is not trying to impress you.

## Do

1. Read every empty state, menu title, and Settings label out loud. One sentence, lowercase energy, no exclamation marks.
2. Confirm Help is still one page and the anchors match the window.
3. Write the 1.0 release notes in `CHANGELOG.md` — what a friend needs to know, not a changelog dump.
4. Bump the version to 1.0.

## Do not

- Add a tour, a tips panel, or a fourth Settings pane.

## Gate

A skeptical friend reads the empty states and the Help page and never asks “where’s the rest?”
