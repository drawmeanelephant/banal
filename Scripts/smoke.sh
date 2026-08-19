#!/usr/bin/env bash
# Startup smoke test for the signed BANAL.app.
#
# Launches dist/BANAL.app with BANAL_VAULT pointing at a scratch folder.
# When BANAL_SMOKE_TEST is set the app quits itself once the work is done,
# through the normal terminate path (applicationWillTerminate runs, exit
# status 0). This script asserts:
#   1. bootstrap() actually opened the vault (.banal/config.json + assets/),
#   2. the process stayed alive while opening it,
#   3. external files handed to the running app via LaunchServices
#      (`open -a`, the Finder/Open With path) are imported into the vault —
#      all of them, byte-identical and exactly once. Two files are
#      delivered in one call, which exercises both delivery routes: a
#      SwiftUI WindowGroup routes the first URL to `.onOpenURL` and the
#      rest to the AppKit delegate's openURLs hook,
#   4. the app exited on its own with status 0 — a crash exits nonzero.
#
# This is not a sit. It proves the signed binary launches, opens a folder,
# and processes multi-file open events end to end. The source files are
# placed inside the app's container so the sandbox can read them without a
# powerbox grant — the real Finder gesture (out-of-container source) is a
# human gate in TESTING-WINDOW.md.
#
# Overrides: APP (app bundle path), SMOKE_VAULT (a sandbox-writable vault
# path, e.g. inside the app's container), SMOKE_TIMEOUT (seconds to wait
# for the vault to open), SMOKE_OPEN_LEAF (comma-separated file names to
# deliver; defaults to risotto.cook,a-page.textile — names that do not
# collide with the bootstrap Welcome.md).

set -euo pipefail

APP="${APP:-dist/BANAL.app}"
BIN="$APP/Contents/MacOS/BANAL"
TIMEOUT="${SMOKE_TIMEOUT:-10}"
OPEN_LEAVES="${SMOKE_OPEN_LEAF:-risotto.cook,a-page.textile}"
IFS=',' read -ra LEAVES <<< "$OPEN_LEAVES"

# The signed app is sandboxed and can only write inside its own container,
# so the scratch vault defaults there — TMPDIR is blocked by the sandbox.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || echo dev.drawmeanelephant.banal)"
CONTAINER_TMP="$HOME/Library/Containers/$BUNDLE_ID/Data/tmp"
mkdir -p "$CONTAINER_TMP"
VAULT="${SMOKE_VAULT:-$(mktemp -d "$CONTAINER_TMP/banal-smoke.XXXXXX")}"
SOURCE_DIR="$(mktemp -d "$CONTAINER_TMP/banal-smoke-source.XXXXXX")"

log()  { printf 'SMOKE  %s\n' "$*"; }
fail() { printf 'SMOKE FAIL  %s\n' "$*" >&2; exit 1; }

[[ -x "$BIN" ]] || fail "missing $BIN — run 'make app' first"

# Sources: the sample-vault files when present (root or Recipes/), else a
# minimal note per language, so CI does not depend on the sample vault.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
make_source() {
  local leaf="$1" out="$2"
  if [[ -f "$SCRIPT_DIR/../Examples/sample-vault/$leaf" ]]; then
    cp "$SCRIPT_DIR/../Examples/sample-vault/$leaf" "$out"
  elif [[ -f "$SCRIPT_DIR/../Examples/sample-vault/Recipes/$leaf" ]]; then
    cp "$SCRIPT_DIR/../Examples/sample-vault/Recipes/$leaf" "$out"
  else
    case "$leaf" in
      *.cook)    printf 'Add @salt{1%%tsp} to the pan.\n\nStir.\n' > "$out";;
      *.textile) printf 'h1. Smoke note\n\nA textile note for the smoke test.\n' > "$out";;
      *)         printf -- '---\ntitle: Smoke note\n---\n\nA markdown note for the smoke test.\n' > "$out";;
    esac
  fi
}
SOURCES=()
for leaf in "${LEAVES[@]}"; do
  make_source "$leaf" "$SOURCE_DIR/$leaf"
  SOURCES+=("$SOURCE_DIR/$leaf")
done

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
BANAL_VAULT="$VAULT" BANAL_SMOKE_TEST=1 BANAL_SMOKE_OPEN_FILE="$OPEN_LEAVES" "$BIN" >"$VAULT/app.log" 2>&1 &
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

# 3. Deliver all files in one call, the way Finder multi-select / Open With
# does. The app hook (BANAL_SMOKE_OPEN_FILE) quits only after every leaf
# lands on disk, so a dropped event fails loudly instead of false-passing.
# The app is *expected* to exit quickly once the imports land, so we do not
# require it to survive the delivery; step 4 judges the exit — a crash
# exits nonzero, a dropped event quits without the ready marker.
APP_ABS="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
log "delivering ${#SOURCES[@]} files ($OPEN_LEAVES) to the running app via open -a"
open -a "$APP_ABS" "${SOURCES[@]}" || fail "open -a failed to deliver $OPEN_LEAVES"

# 4. Quits cleanly: BANAL_SMOKE_TEST terminates through NSApp with status 0.
CODE=0
wait "$APP_PID" || CODE=$?
[[ "$CODE" -eq 0 ]] || fail "app exited with status $CODE (log: $(tail -5 "$VAULT/app.log"))"
grep -q "BANAL smoke: ready" "$VAULT/app.log" || fail "app never reached the ready marker (log: $(tail -5 "$VAULT/app.log"))"

# 5. Every open-event import landed: byte-identical, exactly once.
for leaf in "${LEAVES[@]}"; do
  [[ -f "$VAULT/$leaf" ]] || fail "open-event import never landed: no $VAULT/$leaf (log: $(tail -5 "$VAULT/app.log"))"
  IMPORT_SHA="$(shasum -a 256 "$VAULT/$leaf" | awk '{print $1}')"
  SOURCE_SHA="$(shasum -a 256 "$SOURCE_DIR/$leaf" | awk '{print $1}')"
  [[ "$SOURCE_SHA" == "$IMPORT_SHA" ]] || fail "imported $leaf differs from the source (source $SOURCE_SHA, vault $IMPORT_SHA)"
  DUPS="$(ls "$VAULT" | grep -c "$leaf" || true)"
  [[ "$DUPS" -eq 1 ]] || fail "expected exactly one imported $leaf, found $DUPS"
done

log "quit cleanly with status 0 and imported $OPEN_LEAVES byte-identical — smoke passed"
