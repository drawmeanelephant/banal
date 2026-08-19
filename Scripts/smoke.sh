#!/usr/bin/env bash
# Startup smoke test for the signed BANAL.app.
#
# Launches dist/BANAL.app with BANAL_VAULT pointing at a scratch folder.
# When BANAL_SMOKE_TEST is set the app quits itself after a beat, through
# the normal terminate path (applicationWillTerminate runs, exit status 0).
# This script asserts:
#   1. bootstrap() actually opened the vault (.banal/config.json + assets/),
#   2. the process stayed alive while opening it,
#   3. the app exited on its own with status 0 — a crash exits nonzero.
#
# This is not a sit. It proves the signed binary launches and opens a folder.
# Overrides: APP (app bundle path), SMOKE_VAULT (a sandbox-writable vault
# path, e.g. inside the app's container), SMOKE_TIMEOUT (seconds to wait
# for the vault to open).

set -euo pipefail

APP="${APP:-dist/BANAL.app}"
BIN="$APP/Contents/MacOS/BANAL"
TIMEOUT="${SMOKE_TIMEOUT:-10}"

# The signed app is sandboxed and can only write inside its own container,
# so the scratch vault defaults there — TMPDIR is blocked by the sandbox.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || echo dev.drawmeanelephant.banal)"
CONTAINER_TMP="$HOME/Library/Containers/$BUNDLE_ID/Data/tmp"
mkdir -p "$CONTAINER_TMP"
VAULT="${SMOKE_VAULT:-$(mktemp -d "$CONTAINER_TMP/banal-smoke.XXXXXX")}"

log()  { printf 'SMOKE  %s\n' "$*"; }
fail() { printf 'SMOKE FAIL  %s\n' "$*" >&2; exit 1; }

[[ -x "$BIN" ]] || fail "missing $BIN — run 'make app' first"

APP_PID=""
cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  rm -rf "$VAULT"
}
trap cleanup EXIT

log "launching $APP with BANAL_VAULT=$VAULT"
BANAL_VAULT="$VAULT" BANAL_SMOKE_TEST=1 "$BIN" >"$VAULT/app.log" 2>&1 &
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

# 3. Quits cleanly: BANAL_SMOKE_TEST terminates through NSApp with status 0.
CODE=0
wait "$APP_PID" || CODE=$?
[[ "$CODE" -eq 0 ]] || fail "app exited with status $CODE (log: $(tail -5 "$VAULT/app.log"))"
grep -q "BANAL smoke: ready" "$VAULT/app.log" || fail "app never reached the ready marker"
log "quit cleanly with status 0 — smoke passed"
