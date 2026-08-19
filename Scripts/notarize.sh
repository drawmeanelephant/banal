#!/usr/bin/env bash
# Notarizes and staples dist/BANAL.app or dist/BANAL-*.dmg using Apple's notarytool.
#
# Supports three credential discovery methods:
#   1. Keychain Profile (recommended):
#      NOTARY_PROFILE or KEYCHAIN_PROFILE
#      (e.g., created via `xcrun notarytool store-credentials <profile-name> ...`)
#   2. App Store Connect API Key:
#      APPLE_API_KEY_ID, APPLE_API_ISSUER_ID, APPLE_API_KEY_FILE (or APPLE_API_KEY_PATH / APPLE_API_KEY)
#   3. Apple ID + App-Specific Password + Team ID:
#      APPLE_ID, APPLE_PASSWORD (or APPLE_APP_SPECIFIC_PASSWORD), TEAM_ID (or APPLE_TEAM_ID)
#
# If no notarization credentials are present in the environment or Keychain,
# the script prints a diagnostic message and exits gracefully (code 0) so
# local ad-hoc developer builds do not break.

set -euo pipefail

TARGET="${1:-dist/BANAL.app}"

log()  { printf 'NOTARIZE  %s\n' "$*"; }
warn() { printf 'NOTARIZE WARNING  %s\n' "$*" >&2; }
fail() { printf 'NOTARIZE FAIL  %s\n' "$*" >&2; exit 1; }

if [[ ! -e "$TARGET" ]]; then
  fail "target '$TARGET' does not exist. Run 'make app' or 'make dmg' first."
fi

# Determine authentication arguments for xcrun notarytool
AUTH_ARGS=()

PROFILE="${NOTARY_PROFILE:-${KEYCHAIN_PROFILE:-}}"
API_KEY_ID="${APPLE_API_KEY_ID:-${AUTHKEY_KEY_ID:-${API_KEY_ID:-}}}"
API_ISSUER="${APPLE_API_ISSUER_ID:-${AUTHKEY_ISSUER_ID:-${ISSUER_ID:-}}}"
API_KEY_FILE="${APPLE_API_KEY_FILE:-${APPLE_API_KEY_PATH:-${APPLE_API_KEY:-}}}"
APPLE_ID="${APPLE_ID:-}"
APPLE_PASS="${APPLE_PASSWORD:-${APPLE_APP_SPECIFIC_PASSWORD:-}}"
TEAM_ID="${TEAM_ID:-${APPLE_TEAM_ID:-}}"

if [[ -n "$PROFILE" ]]; then
  log "using keychain profile '$PROFILE'"
  AUTH_ARGS=(--keychain-profile "$PROFILE")
elif [[ -n "$API_KEY_ID" && -n "$API_ISSUER" && -n "$API_KEY_FILE" ]]; then
  if [[ ! -f "$API_KEY_FILE" ]]; then
    fail "Apple API key file not found at '$API_KEY_FILE'"
  fi
  log "using App Store Connect API key ID '$API_KEY_ID'"
  AUTH_ARGS=(--key "$API_KEY_FILE" --key-id "$API_KEY_ID" --issuer "$API_ISSUER")
elif [[ -n "$APPLE_ID" && -n "$APPLE_PASS" && -n "$TEAM_ID" ]]; then
  log "using Apple ID '$APPLE_ID' and team ID '$TEAM_ID'"
  AUTH_ARGS=(--apple-id "$APPLE_ID" --password "$APPLE_PASS" --team-id "$TEAM_ID")
else
  cat << 'EOF'
NOTARIZE  No notarization credentials found in environment.
Provide one of the following authentication methods:
  1. Keychain Profile (recommended):
     export NOTARY_PROFILE="AC_PASSWORD"
     (Create profile with: xcrun notarytool store-credentials "AC_PASSWORD" --apple-id "..." --team-id "..." --password "...")
  2. App Store Connect API Key:
     export APPLE_API_KEY_ID="KEYID123"
     export APPLE_API_ISSUER_ID="issuer-uuid"
     export APPLE_API_KEY_FILE="/path/to/AuthKey_KEYID123.p8"
  3. Apple ID & App-Specific Password:
     export APPLE_ID="user@example.com"
     export APPLE_PASSWORD="abcd-efgh-ijkl-mnop"
     export TEAM_ID="TEAM123456"

Skipping notarization (local ad-hoc build).
EOF
  exit 0
fi

# Submit payload: notarytool accepts .zip, .dmg, or .pkg.
# For .app bundles, create a temporary zip with ditto.
SUBMIT_FILE="$TARGET"
TEMP_ZIP=""

cleanup() {
  if [[ -n "$TEMP_ZIP" && -f "$TEMP_ZIP" ]]; then
    rm -f "$TEMP_ZIP"
  fi
}
trap cleanup EXIT

if [[ -d "$TARGET" ]]; then
  TEMP_ZIP="$(mktemp "${TMPDIR:-/tmp}/banal-notarize.XXXXXX").zip"
  log "compressing $TARGET into temporary archive $TEMP_ZIP"
  ditto -c -k --keepParent "$TARGET" "$TEMP_ZIP"
  SUBMIT_FILE="$TEMP_ZIP"
fi

log "submitting $SUBMIT_FILE to Apple Notary Service..."
xcrun notarytool submit "$SUBMIT_FILE" "${AUTH_ARGS[@]}" --wait

# Staple notarization ticket
log "stapling notarization ticket to $TARGET..."
xcrun stapler staple "$TARGET"

# Validate ticket and Gatekeeper acceptance
log "validating stapled ticket on $TARGET..."
xcrun stapler validate "$TARGET"

if [[ "$TARGET" == *.app ]]; then
  log "assessing Gatekeeper acceptance for $TARGET..."
  spctl --assess --type execute --verbose "$TARGET" || warn "spctl assess returned non-zero (may require online Gatekeeper evaluation)"
fi

log "notarization and stapling complete for $TARGET"
