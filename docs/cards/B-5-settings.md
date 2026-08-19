# Card B-5 — Settings as furniture

**Milestone:** M2 · **Lane:** settings · **Status:** landed — copy + validation; Deploy enabled in B-10

## Handoff

- **Landed:** Three panes. General / Editor / Publish. Vault bookmark, sort, new-note location, type prefs, Keychain token, disabled Deploy + copyable wrangler.
- **This session:** UI copy from PREFERENCES (“Cloudflare Pages project”, “API token (Keychain)”). Inline base URL and project-name checks; account ID warns and does not block. Site + Cloudflare IDs persist in `.banal/config.json`; token never appears there.
- **Sit (this session):** Filled Publish in the GUI; quit; reopen showed Field Notes / URL / Ada / field-notes / account / domain. Deploy was clipped; window is now 640pt and Deploy is visible and disabled. Token never entered the vault. Passwords autofill can pop on the token field (system).

The three panes exist. This card is the copy, validation, and
“looks expensive” pass — so Cloudflare can arrive later without
redesigning anything.

## Owns

- `Sources/BANALApp/Views/SettingsRoot.swift`
- `AppPreferences`, `VaultConfiguration` persist
- `PublishKeychain`

## Do not touch

- Live `wrangler` deploy (B-10)
- Editor TextKit internals (B-1 / B-2)
- A fourth pane

## Why

Settings is where people decide we are serious. A Publish pane
that already has project, account, domain, and a Keychain token —
with Deploy sitting there disabled and honest — is hotter than a
wizard that appears the week we invent billing.

## Do

1. Keep exactly three tabs: General, Editor, Publish.
2. UI copy from [`../PREFERENCES.md`](../PREFERENCES.md): “notes
   folder,” not “vault.” “Cloudflare Pages project,” not “target.”
3. General: choose folder, reveal, sort, new-note location, watch
   external edits.
4. Editor: size, line height, measure, spelling, smart quotes. No serif.
   Changes apply to the open note immediately.
5. Publish: site title, base URL (validate http/s), author, project
   name, account ID, custom domain. Token: SecureField → Keychain.
   Never echo the token after save. “Not connected — publishing
   stays on this Mac.”
6. Deploy button visible and disabled, with a copyable wrangler
   command. Help string: local publish works today.
7. Vault-traveling fields in `.banal/config.json`. Token only in
   Keychain.

## Do not

- OAuth.
- Multi-account Cloudflare.
- Theme store.

## Gate

Fill every Publish field, quit, reopen: values persist. Token
survives quit and does not appear in the vault or in logs.
Someone who never opens Settings still has a good app.
