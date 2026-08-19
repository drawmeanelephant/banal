# Card B-3 — Empty states that do not insult anyone

**Milestone:** M3 · **Lane:** chrome · **Status:** landed — one-sentence empties, missing-folder picker

## Handoff

- **Landed:** First run “Choose a notes folder.” Missing folder “This notes folder is missing.” plus the path — folder is not silently recreated. Empty search / folder / selection / published are one sentence. Publish-with-none is “Nothing published.” `NotesFolderAccess` + tests.
- **Sit (this session):** Empty nested folder is “No notes in this folder.” Nonsense search is “No notes match.” with the query kept. Missing folder: launch on a vanished path, or delete the notes folder while open, shows “This notes folder is missing.” plus the path and Choose… — the folder is not recreated. Full tester script: [`../TESTING-NOTES-FOLDER.md`](../TESTING-NOTES-FOLDER.md). `BANAL_VAULT` points at a folder without touching the saved bookmark.

## Owns

- Empty list / empty folder / no selection / first-run picker
- Transient status strip
- Missing vault / revoked bookmark copy

## Do not touch

- Onboarding carousels
- Sample-content marketing pages
- Tooltips that explain the concept of a folder

## Why

Empty is most of a new vault. If empty looks like a SaaS landing
page, the app has already lost. If empty looks like a crash, same.
Apple Notes says almost nothing. We say one sentence and leave a
keyboard path.

## Do

1. First run: “Choose a notes folder.” Two buttons. No hero video.
2. Empty folder: “No notes in this folder.” ⌘N still creates *here*.
3. Empty search: “No notes match.” Query stays.
4. No selection: “Create a note with ⌘N.”
5. Nothing published: “Nothing published.” Not a lecture on Boris.
6. Missing folder / stale bookmark: Settings / choose folder. No
   stack of sheets.
7. Publish with zero published notes: one sentence in the status
   strip. Already exists — keep it that quiet.

## Do not

- Illustrations of elephants.
- “Tips for your first week.”
- Confetti.

## Gate

A brand-new vault, an empty nested folder, and a nonsense search
each look like the same product — calm, short, keyboard-complete.
