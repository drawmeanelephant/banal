#!/bin/bash
# generate-board.sh — make Board J conflict-free (the real snack)
#
# See .gitattributes: docs/cards/README.md merge=union is the 80% fix.
# This script is the 100%: Board J is never hand-edited.
# You add docs/cards/J-18-*.md and run `make board` — the two tables are
# built from the cards' Status lines, but existing human Gate text is preserved.
#
# Usage:
#   ./Scripts/generate-board.sh           # rewrite docs/cards/README.md Board J
#   ./Scripts/generate-board.sh --check   # exit 1 if README is stale (for CI)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$ROOT/docs/cards/README.md"
CHECK=0
if [[ "${1:-}" == "--check" ]]; then CHECK=1; fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

python3 - "$README" "$tmp" <<'PY'
import re, glob, pathlib, sys

readme_path, tmp_path = sys.argv[1], sys.argv[2]
text = pathlib.Path(readme_path).read_text(encoding="utf-8")

# --- 1) Parse existing Board J rows to preserve human Gate text ---
existing = {}
# Find Board J table
mboard = re.search(r'(\| Card \| Milestone \| Lane \| Gate \|\n\|[^\n]*\n)(.*?)(\nSuggested prefixes:)', text, re.DOTALL)
if mboard:
    body = mboard.group(2)
    for line in body.splitlines():
        # line like "| [J-13 Casa Grande](J-13-casa-grande.md) | M13 | core+app | **landed** — … |"
        mm = re.search(r'\[.*?\]\((J-[^)]+)\)', line)
        if mm:
            existing[mm.group(1)] = line.strip()

cards = sorted(glob.glob("docs/cards/J-1[3-9]-*.md"))
if not cards:
    sys.stderr.write("generate-board: no J cards found\n")
    sys.exit(1)

summary_parts = []
table_rows = []

for card in cards:
    fname = pathlib.Path(card).name
    raw = pathlib.Path(card).read_text(encoding="utf-8")
    # Find the **Milestone:** line
    status_line = ""
    for l in raw.splitlines():
        if l.strip().startswith("**Milestone:"):
            status_line = l.strip()
            break
    if not status_line:
        continue
    # Split on '·' (middle dot)
    parts = [p.strip() for p in status_line.split("·")]
    info = {}
    for p in parts:
        # p is "**Milestone:** M13" etc
        mm = re.search(r'\*\*([A-Za-z]+):\*\*\s*(.*)', p)
        if mm:
            info[mm.group(1)] = mm.group(2).strip()
    milestone = info.get("Milestone", "")
    lane = info.get("Lane", "")
    status_raw = info.get("Status", "")
    branch_raw = info.get("Branch", "")
    # Branch: take first `...`
    mbr = re.search(r'`([^`]+)`', branch_raw)
    branch = mbr.group(1) if mbr else branch_raw.split()[0] if branch_raw else ""
    parent = info.get("Parent", "").split()[0] if info.get("Parent") else ""
    subissues_raw = info.get("Subissues", "")
    # Clean subissues: remove trailing " — closed" etc, keep as is for summary
    subissues_clean = subissues_raw.split("—")[0].strip()
    # Title: "# Card J-14 — Gila Bend — …"
    title_line = raw.splitlines()[0] if raw else ""
    title = fname.replace(".md", "")
    if title_line.startswith("# Card "):
        rest = title_line[len("# Card "):]
        segs = [s.strip() for s in rest.split("—")]
        if len(segs) >= 2:
            title = f"{segs[0]} {segs[1]}"
    short_status = status_raw.split("—")[0].strip().split()[0] if status_raw else "board"
    sha = ""
    msha = re.search(r'`([a-f0-9]{7,40})`', status_raw)
    if msha:
        sha = msha.group(1)[:7]

    # Summary token: keep compact but accurate
    if parent and subissues_clean:
        arrow = f"{parent} → {subissues_clean}"
    elif parent:
        arrow = parent
    else:
        arrow = subissues_clean
    if sha:
        token = f"{title} (`{branch}` {arrow}) {short_status} `{sha}`"
    else:
        token = f"{title} (`{branch}` {arrow}) {short_status}"
    summary_parts.append(token)

    # Table row: preserve existing human Gate if present, else synthesize
    if fname in existing:
        # Update the existing row's first 4 cols (Card/Milestone/Lane/Status) but keep Gate
        # Parse existing row to extract Gate
        old = existing[fname]
        # old is "| [J-13 Casa Grande](J-13-casa-grande.md) | M13 | core+app | **landed** — … |"
        # Split on '|' — parts[1]= Card, 2= Milestone, 3= Lane, 4= Gate
        cols = [c.strip() for c in old.split("|")]
        # cols[0] is '', cols[1] is Card, cols[2] Milestone, cols[3] Lane, cols[4] Gate, cols[5] ''
        gate = cols[4] if len(cols) > 4 else f"**{short_status}** — drive triage"
        # Rebuild with fresh Milestone/Lane/Status but keep Gate's human text after the status bold
        # Gate already contains bold status + " — " + human text, so we keep it as is if status matches, else update bold
        # If short_status changed, replace bold part
        if short_status not in gate:
            # Replace existing **...** with new **short_status**
            gate = re.sub(r'\*\*[^*]+\*\*', f'**{short_status}**', gate, count=1)
        row = f"| [{title}]({fname}) | {milestone} | {lane} | {gate} |"
    else:
        # New card: synthesize simple gate
        gate_hint = "drive triage"
        if "TESTING-WINDOW" in raw:
            gate_hint = "docs/TESTING-WINDOW.md"
        elif "TESTING-NOTES" in raw:
            gate_hint = "docs/TESTING-NOTES-FOLDER.md"
        row = f"| [{title}]({fname}) | {milestone} | {lane} | **{short_status}** — {gate_hint} |"
    table_rows.append(row)

summary_line = "| M13–M19 | **active triage — Drive** — " + ", ".join(summary_parts) + " |"

# Replace M13–M19 summary row
text_new = re.sub(r'^\| M13–M19 \|.*\|$', summary_line, text, count=1, flags=re.MULTILINE)

# Replace Board J table rows
pat = re.compile(r'(\| Card \| Milestone \| Lane \| Gate \|\n\|[^\n]*\n)(.*?)(\nSuggested prefixes:)', re.DOTALL)
def repl(m):
    header = m.group(1)
    tail = m.group(3)
    body = "\n".join(table_rows)
    return header + body + "\n" + tail

text_new, n = pat.subn(repl, text_new, count=1)
if n == 0:
    sys.stderr.write("generate-board: could not find Board J table\n")
    sys.exit(1)

pathlib.Path(tmp_path).write_text(text_new, encoding="utf-8")
PY

if [[ "$CHECK" -eq 1 ]]; then
  if cmp -s "$README" "$tmp"; then
    echo "generate-board: README is fresh"
    exit 0
  else
    echo "generate-board: README is stale — run 'make board' (diff: README vs generated)" >&2
    diff -u "$README" "$tmp" | head -n 80 || true
    exit 1
  fi
else
  mv "$tmp" "$README"
  echo "generate-board: wrote Board J ($(ls docs/cards/J-1[3-9]-*.md | wc -l | tr -d ' ') cards) + M13–M19 summary to $README"
fi
