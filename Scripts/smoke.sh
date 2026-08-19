#!/usr/bin/env bash
# Startup smoke test for the signed BANAL.app.
#
# Launches dist/BANAL.app with BANAL_VAULT pointing at a scratch folder.
# When BANAL_SMOKE_TEST is set the app quits itself once the work is done,
# through the normal terminate path (applicationWillTerminate runs, exit
# status 0). This script asserts:
#   1. bootstrap() actually opened the vault (.banal/config.json + assets/),
#   2. the process stayed alive while opening it,
#   3. an external .cook file handed to the running app via LaunchServices
#      (`open -a`, the Finder/Open With path) is imported into the vault —
#      byte-identical and exactly once,
#   4. the app exited on its own with status 0 — a crash exits nonzero.
#
# This is not a sit. It proves the signed binary launches, opens a folder,
# and processes an open-file event through .onOpenURL. The source file is
# placed inside the app's container so the sandbox can read it without a
# powerbox grant — the real Finder gesture (out-of-container source) is a
# human gate in TESTING-WINDOW.md.
#
# Overrides: APP (app bundle path), SMOKE_VAULT (a sandbox-writable vault
# path, e.g. inside the app's container), SMOKE_TIMEOUT (seconds to wait
# for the vault to open), SMOKE_OPEN_LEAF (the file to deliver; defaults
# to risotto.cook from the sample vault).

set -euo pipefail

APP="${APP:-dist/BANAL.app}"
BIN="$APP/Contents/MacOS/BANAL"
TIMEOUT="${SMOKE_TIMEOUT:-10}"
OPEN_LEAF="${SMOKE_OPEN_LEAF:-risotto.cook}"

# The signed app is sandboxed and can only write inside its own container,
# so the scratch vault defaults there — TMPDIR is blocked by the sandbox.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || echo dev.drawmeanelephant.banal)"
CONTAINER_TMP="$HOME/Library/Containers/$BUNDLE_ID/Data/tmp"
mkdir -p "$CONTAINER_TMP"
VAULT="${SMOKE_VAULT:-$(mktemp -d "$CONTAINER_TMP/banal-smoke.XXXXXX")}"
SOURCE_DIR="$(mktemp -d "$CONTAINER_TMP/banal-smoke-source.XXXXXX")"
SOURCE="$SOURCE_DIR/$OPEN_LEAF"

log()  { printf 'SMOKE  %s\n' "$*"; }
fail() { printf 'SMOKE FAIL  %s\n' "$*" >&2; exit 1; }

[[ -x "$BIN" ]] || fail "missing $BIN — run 'make app' first"

# The open-event source: the sample risotto when present, else a minimal
# cooklang note, so CI does not depend on the sample vault.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE="$SCRIPT_DIR/../Examples/sample-vault/Recipes/$OPEN_LEAF"
if [[ -f "$SAMPLE" ]]; then
  cp "$SAMPLE" "$SOURCE"
else
  printf 'Add @salt{1%%tsp} to the pan.\n\nStir.\n' > "$SOURCE"
fi
SOURCE_SHA="$(shasum -a 256 "$SOURCE" | awk '{print $1}')"

APP_PID=""
cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  rm -rf "$VAULT" "$SOURCE_DIR"
}
trap cleanup EXIT

log "launching $APP with BANAL_VAULT=$VAULT"
BANAL_VAULT="$VAULT" BANAL_SMOKE_TEST=1 BANAL_SMOKE_OPEN_FILE="$OPEN_LEAF" "$BIN" >"$VAULT/app.log" 2>&1 &
APP_PID=$!

# 1. The notes folder resolves: bootstrap() writes .banal/config.json + assets/.
for _ in $(seq 1 "$((TIMEOUT * 5))"); do
  [[ -f "$VAULT/.banal/config.json" ]] && break
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    CODE=0
    wait "$APP_PID" || CODE=$?
    fail "app exited before opening the vault (status $CODE; log: $(tail -5 "$VAULT/app.log"))"
  fi
  sleep 0.2
done
[[ -f "$VAULT/.banal/config.json" ]] || fail "vault never opened: no .banal/config.json after ${TIMEOUT}s"
[[ -d "$VAULT/assets" ]] || fail "vault never opened: no assets/ directory"
log "notes folder resolved ($VAULT/.banal/config.json)"

# 2. Still alive after the vault is open — no crash-on-launch.
sleep 1
kill -0 "$APP_PID" 2>/dev/null || fail "app died right after opening the vault"

# 3. Deliver the open-file event, the way Finder / Open With does. A SwiftUI
# WindowGroup routes this to .onOpenURL, which imports the file into the
# vault; the app hook (BANAL_SMOKE_OPEN_FILE) quits only after the import
# lands on disk, so a dropped event fails loudly instead of false-passing.
APP_ABS="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
log "delivering $OPEN_LEAF to the running app via open -a"
open -a "$APP_ABS" "$SOURCE" || fail "open -a failed to deliver $SOURCE"
sleep 1
kill -0 "$APP_PID" 2>/dev/null || fail "app died while processing the open event"

# 4. Quits cleanly: BANAL_SMOKE_TEST terminates through NSApp with status 0.
CODE=0
wait "$APP_PID" || CODE=$?
[[ "$CODE" -eq 0 ]] || fail "app exited with status $CODE (log: $(tail -5 "$VAULT/app.log"))"
grep -q "BANAL smoke: ready" "$VAULT/app.log" || fail "app never reached the ready marker (log: $(tail -5 "$VAULT/app.log"))"

# 5. The open-event import actually landed: byte-identical, exactly once.
[[ -f "$VAULT/$OPEN_LEAF" ]] || fail "open-event import never landed: no $VAULT/$OPEN_LEAF (log: $(tail -5 "$VAULT/app.log"))"
IMPORT_SHA="$(shasum -a 256 "$VAULT/$OPEN_LEAF" | awk '{print $1}')"
[[ "$SOURCE_SHA" == "$IMPORT_SHA" ]] || fail "imported $OPEN_LEAF differs from the source (source $SOURCE_SHA, vault $IMPORT_SHA)"
DUPS="$(ls "$VAULT" | grep -c "$OPEN_LEAF" || true)"
[[ "$DUPS" -eq 1 ]] || fail "expected exactly one imported $OPEN_LEAF, found $DUPS"

log "quit cleanly with status 0 and imported $OPEN_LEAF byte-identical — smoke passed"
