#!/usr/bin/env bash
# Packages dist/BANAL.app into a compressed disk image (dist/BANAL-<version>.dmg).
#
# Creates:
#   - dist/BANAL-<version>.dmg
#   - dist/BANAL.dmg (symlink to versioned DMG)
#
# Signs the disk image with SIGN_IDENTITY (Developer ID or ad-hoc).

set -euo pipefail

APP="${1:-dist/BANAL.app}"
VERSION="${2:-0.1.0}"
DIST="${3:-dist}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

log()  { printf 'DMG  %s\n' "$*"; }
fail() { printf 'DMG FAIL  %s\n' "$*" >&2; exit 1; }

[[ -d "$APP" ]] || fail "missing $APP — run 'make app' first"

mkdir -p "$DIST"
DMG_NAME="BANAL-${VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"
LATEST_DMG="$DIST/BANAL.dmg"

RAW_DMG="$DIST/raw-BANAL-${VERSION}.dmg"
STAGING="$DIST/dmg-staging"

cleanup() {
  rm -rf "$STAGING" "$RAW_DMG"
}
trap cleanup EXIT

log "staging $APP and Applications shortcut..."
rm -rf "$STAGING" "$RAW_DMG" "$DMG_PATH" "$LATEST_DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

log "creating disk image $DMG_PATH..."
hdiutil makehybrid -hfs -hfs-volume-name "BANAL" -o "$RAW_DMG" "$STAGING" >/dev/null
hdiutil convert -format UDZO -o "$DMG_PATH" "$RAW_DMG" >/dev/null
rm -rf "$STAGING" "$RAW_DMG"

# Sign the DMG
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  log "signing $DMG_PATH with ad-hoc signature..."
  codesign --force --sign - "$DMG_PATH"
else
  log "signing $DMG_PATH with identity '$SIGN_IDENTITY'..."
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

# Create convenience alias/symlink
ln -sf "$DMG_NAME" "$LATEST_DMG"

log "created and signed $DMG_PATH (and $LATEST_DMG)"
