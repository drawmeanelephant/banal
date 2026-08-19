# Card C-2 — Honesty in Settings and menus

**Milestone:** M7 · **Lane:** settings · **Depends:** C-0 · **Status:** landed — Boris/Oliver paths, About, speakable copy

## Handoff

- **Landed:** Settings → Publish has Boris (optional) and Oliver
  (optional) with Choose… / Reveal / Clear. Paths persist in
  `.banal/config.json`. `AppModel.refreshOliver()` picks up a new
  Oliver path without relaunch. BANAL → About BANAL: name, 0.1.0,
  mission sentence. First-run already said “notes folder.” Publish
  and deploy status are spoken sentences.
- **Not this card:** the window sit (C-1), sandbox (C-3), a fourth pane.

## Owns

- `Sources/BANALApp/Views/SettingsRoot.swift` Publish pane
- Oliver and Boris path fields already named in
  [`../PREFERENCES.md`](../PREFERENCES.md)
- Tiny About
- First-run / missing-folder sentences if the sit shows they lie
- Status copy for missing Oliver, skipped recipes, deploy failure

## Do not touch

- A Languages pane
- OAuth, multi-account Cloudflare
- Preview, highlighting, scaled-recipe save

## Why

Prefs promised an Oliver path “later” and described Cloudflare as
aspirational after Deploy shipped. A finished Mac app does not
keep a basement of binaries the user cannot see. About and honest
empty copy are furniture, not features.

## Do

1. Publish pane: choose / reveal Boris binary and Oliver binary.
   Empty is fine. Missing binary stays silent for ordinary notes;
   publish and recipe Read already speak one sentence.
2. About: name, version, the one-line mission. No tour.
3. First-run: “Choose a notes folder.” and the Documents button
   use the same words as Settings. Do not silently create the
   default folder to dodge the picker.
4. Deploy / skip / failure copy is something you would say out
   loud. Success still does not open a sheet.
5. Update PREFERENCES in the same change if a control is added
   or renamed.

## Do not

- Show the API token after save.
- Put “BANALPublisher” or “entity id” in the UI.
- Add a Compiler tab. Paths live under Publish.

## Gate

Someone who never reads the README can find every feature in the
menu bar and Settings. Oliver’s path is visible. About exists.
`swift test` stays green.
