# Preferences

BANAL has few settings. They exist so the app stays out of the way, and so Cloudflare publishing can be switched on later without redesigning the product.

Schema changes land in this file in the same PR as code.

## Window

Standard macOS Settings (`⌘,`). Three panes, in this order:

1. **General** — vault and app behavior
2. **Editor** — type and editing
3. **Publish** — site identity + Cloudflare (deploy may be unimplemented; the fields are not)

No Accounts pane. No Themes store. No Plugins.

## General

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| Notes folder | security-scoped bookmark | unset → first-run picker; fallback `~/Documents/BANAL Notes` | Reveal in Finder. If the remembered path is gone, show “This notes folder is missing.” — do not recreate it. See [`TESTING-NOTES-FOLDER.md`](TESTING-NOTES-FOLDER.md). |
| Open most recent vault on launch | bool | true | |
| Sort notes | enum: `updated`, `created`, `title` | `updated` | |
| Default new-note location | enum: `selected_folder`, `vault_root`, `inbox` | `selected_folder` | If `inbox`, create `Inbox/` as needed |
| Move deleted notes to Trash | bool | true | Always filesystem Trash, never a BANAL limbo |
| Watch folder for external edits | bool | true | FSEvents + `NSFilePresenter` |

## Editor

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| Font | serif toggle + size 13–22 | system serif / New York 16 if available, else SF Pro 16 | No font picker; one pairing |
| Line height | enum: `tight`, `normal`, `loose` | `normal` | Maps to 1.35 / 1.5 / 1.7 |
| Limit line length | bool | true | Caps measure in the editor |
| Spell check | bool | system default | |
| Smart quotes | bool | true | |
| Typewriter scrolling | bool | false | Off by default; easy to add, easy to make tacky |

No theme marketplace. No Vim mode. No plugin font renderer.

## Publish

Local notes do not read these keys. They matter only when the user chooses File → Publish Site….

### Site

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| Site title | string | `Notes` | Home page + RSS title |
| Base URL | URL string | empty | e.g. `https://notes.example.com` — used in RSS and absolute links |
| Author | string | empty | Optional RSS / footer |
| Include drafts | bool | false | Must stay false unless the user is debugging. Published flag is the contract |
| Output folder | path relative to vault | `.publish/` | Artifact directory; gitignore-friendly |

### Compiler

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| Prefer Boris when available | bool | true | Else builtin HTML + RSS |
| Boris binary | optional path | `BANAL_BORIS_BIN`, then `PATH`, then sibling checkout | Reveal / choose file |
| Oliver binary | optional path | `BANAL_OLIVER_BIN`, then `PATH`, then sibling checkout | Locate only this card; Settings path later |

### Cloudflare (aspirational fields — store now, deploy later)

These controls should appear in Settings **now**, even if the action is “Save” plus a disabled Deploy button. The point is a finished pane, not a surprise form in a future release.

| Key | Type | Storage | Default | Notes |
| --- | --- | --- | --- | --- |
| Pages project name | string | vault `.banal/config.json` or app defaults | `banal-notes` | `wrangler pages deploy --project-name` |
| Account ID | string | same | empty | Not secret, but treat as private |
| Custom domain | string | same | empty | Documentation + future Pages project |
| Deploy command preview | computed | — | `npx wrangler pages deploy …` | Read-only, copyable |
| API token | secret | **Keychain** only | unset | Account.Cloudflare.BANAL. Never write to the vault, UserDefaults, or logs |
| Token present | derived bool | — | false | UI shows Connected / Not connected |

Out of scope for the pane (do not add):

- Multi-tenant Worker compile (`hosts/cloudflare-worker`)
- R2 object-browser
- Billing, plans, team invites
- OAuth dance beyond “paste a token”

### Behavior when deploy is not implemented

- **Save** writes the non-secret fields.
- **Publish Site…** still builds `.publish/` (Boris or builtin) and writes a dry-run `wrangler.toml`.
- **Deploy to Cloudflare** is visible and disabled, or enabled only as “copy command.” Implementing the live `wrangler` call is a later milestone, not a Settings redesign.

## Persistence rules

| Kind | Where |
| --- | --- |
| Vault bookmark, window frame, last selection | App UserDefaults |
| Site title, base URL, project name, account ID, Boris path | Vault `.banal/config.json` (travels with the folder) |
| API token | Keychain, service `dev.drawmeanelephant.banal`, account = vault identifier |
| Notes | `.md` files |

A cloned vault should carry site identity and not carry secrets.

## UI copy (use these strings)

- “Notes folder” not “vault” in the UI (docs may say vault).
- “Published notes” not “public graph.”
- “Cloudflare Pages project” not “target” or “edition.”
- “API token (Keychain)” not “password.”
- Empty token: “Not connected — publishing stays on this Mac.”
- Token set: “Token saved in Keychain.”

## Validation

- Base URL, if set, must parse as `http`/`https`.
- Project name: Cloudflare-safe (`[a-z0-9-]`), shown inline if invalid.
- Account ID: hex-looking, warn don’t block.
- Token: never displayed after save; only replace or delete.
