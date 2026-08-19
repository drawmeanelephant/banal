# Card F-1 — Notarized release pipeline

**Milestone:** M10 · **Lane:** app · **Depends:** M7 C-3 landed · **Status:** ready — Gatekeeper happy

## Handoff

- **Not started.** `make app` creates an ad-hoc signed, sandboxed `.app` bundle in `dist/BANAL.app`. Release distribution requires Developer ID signing, hardening, and notarization.
- **Not this card:** In-app updater (Sparkle is a future menu item only if needed), web download portals.

## Owns

- `Makefile` (targets: `make sign-developer-id`, `make notarize`, `make release-dmg`)
- `scripts/notarize.sh` (or xcrun notarytool wrapper)
- App entitlements and sandbox validation under Gatekeeper

## Do not touch

- App sandbox entitlements (must retain standard sandbox with security-scoped bookmark read/write)
- Account creation or registration requirements

## Why

A friend or colleague should be able to download `BANAL.dmg` or `BANAL.app`, double-click, drag to Applications, and launch without right-click workarounds or Gatekeeper security warnings.

## Do

1. Add Developer ID Application signing and hardened runtime (`--options runtime`) to the build script when signing identities are present in Keychain / environment.
2. Add `notarytool` submission and stapling (`xcrun stapler staple dist/BANAL.app`).
3. Add DMG packaging target (`make release-dmg`) that packages the stapled app.
4. Verify first-run sandbox file permissions and security-scoped bookmark flow on a fresh system account without cached DerivedData.

## Do not

- Require an online account or telemetry to run the app.
- Break local ad-hoc developer builds when Developer ID certificate is absent.

## Gate

`spctl --assess --type execute --verbose dist/BANAL.app` reports `accepted` source=Notarized Developer ID. First launch opens the folder picker cleanly.
