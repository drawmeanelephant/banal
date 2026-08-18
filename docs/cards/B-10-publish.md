# Card B-10 — Publish is Export

**Milestone:** M6 · **Lane:** publisher · **Depends:** B-5 · **Status:** ready

## Owns

- `BANALPublisher`, staging of `.md` / `.textile` / `.cook`
- File → Publish Site…
- Optional live `wrangler pages deploy` using Keychain token
- Status copy

## Do not touch

- Graph inspector
- Cloudflare Worker host
- Making publish required to “finish” a note

## Why

The thrill is: three essays and a sauce become a site, once, and
then it is boring forever. Boris owns the site graph. BANAL
stages files and shows a folder (and maybe a URL). If this feels
like onboarding a SaaS, tear it out.

## Do

1. Only `published: true` (or Cooklang/Boris equivalent you map
   honestly) leaves the vault.
2. Map BANAL local keys → Boris closed grammar. Do not send
   `created` / `published: bool` into Boris.
3. Prefer `boris` when present; builtin HTML+RSS remains the
   fallback for Markdown. Textile/Cooklang without Boris: skip
   or say so in one sentence — do not invent a second SSG.
4. Artifact in `.publish/`. Reveal in Finder.
5. Deploy: only if token + project exist. Failure is one
   sentence + a log the user can copy. Success does not open a
   confetti sheet.
6. Graph, search indexes, RAG: not our UI. If Boris emits them,
   they live in the artifact.

## Do not

- Auto-publish on save.
- A publish dashboard with charts.
- Standard.site / Nostr / AT Proto from this card.

## Gate

Mark two Markdown notes and one `.cook` published. ⇧⌘P produces
HTML for all three when Boris is present. Disk notes untouched.
Deploy still optional. No new chrome in the three columns.
