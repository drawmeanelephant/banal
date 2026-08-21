#!/bin/bash
# gen-5k-vault.sh — El Centro snack
# Creates a synthetic vault with N notes (default 5000) for the
# M16 El Centro gate: cold open <400ms, ⌘F instant, 30s type sane.
# No second DB — just Files. Finder must still make sense.
#
# Usage: ./Scripts/gen-5k-vault.sh [output_dir] [count]
#   output_dir defaults to /tmp/banal-5k-vault
#   count defaults to 5000 (use 100 for quick smoke)
#
# The vault is plain Markdown/Textile/Cooklang + a few folders + assets/
# references, never an illustration or a database.

set -euo pipefail

OUT="${1:-/tmp/banal-5k-vault}"
COUNT="${2:-5000}"
FOLDERS=("Essays" "Recipes" "Inbox" "Notes" "Archive/2024" "Archive/2025")

echo "gen-5k-vault: $COUNT notes -> $OUT"

rm -rf "$OUT"
mkdir -p "$OUT/.banal" "$OUT/assets"

# Minimal .banal/config.json so NoteStore.open doesn't treat it as naked
cat > "$OUT/.banal/config.json" <<'JSON'
{
  "cloudflareCustomDomain" : "",
  "cloudflareProjectName" : "banal-notes",
  "siteAuthor" : "",
  "siteBaseURL" : "",
  "siteTitle" : "Notes"
}
JSON

# Pre-create folders (so empty-folder truth is exercised)
for f in "${FOLDERS[@]}"; do
  mkdir -p "$OUT/$f"
done

# A small tag pool — Tags are a filter, not a place
TAGS=("life" "work" "draft" "recipe" "inbox" "idea" "travel" "code" "reading" "music")

# Deterministic-ish generation without external deps
for i in $(seq 1 "$COUNT"); do
  # Round-robin folder + language
  folder_idx=$(( (i-1) % ${#FOLDERS[@]} ))
  folder="${FOLDERS[$folder_idx]}"
  case $(( i % 10 )) in
    0) ext="cook"; lang_title="Recipe $i"; ;;
    1) ext="textile"; lang_title="Textile $i"; ;;
    *) ext="md"; lang_title="Note $i"; ;;
  esac

  # Title with occasional markdown sigils for WhisperScan
  if (( i % 7 == 0 )); then
    title="# $lang_title — a heading that hugs"
  elif (( i % 11 == 0 )); then
    title="$lang_title — *emphasis* and **strong**"
  else
    title="$lang_title"
  fi

  tag_idx1=$(( (i-1) % ${#TAGS[@]} ))
  tag_idx2=$(( i % ${#TAGS[@]} ))
  tag1="${TAGS[$tag_idx1]}"
  tag2="${TAGS[$tag_idx2]}"
  # Published every 5th note
  if (( i % 5 == 0 )); then published="true"; else published="false"; fi

  # Cooklang is not YAML — use >> metadata style; body stays source
  if [[ "$ext" == "cook" ]]; then
    fname=$(printf "recipe-%05d.cook" "$i")
    cat > "$OUT/$folder/$fname" <<COOK
>> title: $title
>> tags: $tag1, $tag2

Add @arborio rice{300%g} and @stock{800%ml} for $tag1.

Stir for @time{20%minutes}.

Note: synthetic vault — do not cook.
COOK
  else
    fname=$(printf "note-%05d.%s" "$i" "$ext")
    # Frontmatter + body; use ISO-8601 so NoteIO sorts correctly
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$OUT/$folder/$fname" <<MD
---
title: $title
created: $now
updated: $now
tags: [$tag1, $tag2]
published: $published
---
# $title

This is synthetic note $i in \`$folder\`. It exists so El Centro can prove the caret never waits.

- A bullet that should continue on Return
- Tag $tag1 and $tag2

\`\`\`swift
// fence — smart quotes off inside
let x = "$tag1"
\`\`\`

MD
    # Sprinkle an image link every 250 notes to exercise assets/ flatness
    if (( i % 250 == 0 )); then
      echo "" >> "$OUT/$folder/$fname"
      echo "![alt](assets/photo.png)" >> "$OUT/$folder/$fname"
    fi
  fi
done

# Keep one empty folder to test sidebar truth (J-14a)
mkdir -p "$OUT/Empty Sit"

# Count for gate output
found=$(find "$OUT" -type f \( -name "*.md" -o -name "*.textile" -o -name "*.cook" \) | wc -l | tr -d ' ')
folders=$(find "$OUT" -type d -mindepth 1 | wc -l | tr -d ' ')
echo "gen-5k-vault: wrote $found notes, $folders folders -> $OUT"
echo "Next: BANAL_VAULT=\"$OUT\" swift run banal-cli  # or: make smoke BANAL_VAULT=\"$OUT\""
echo "Measure: time swift test --filter testFilesystemMonitorObservesExternalCreate  # and Instruments Hang trace while typing 30s"
