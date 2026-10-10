#!/usr/bin/env bash
# memory-write.sh: CLI fallback to append one memory entry to the Master Brain.
#
#   NLM_MEMORY_NOTEBOOK=<id> bash memory-write.sh --title "mem/2026-10-10/proj-topic" --file entry.md
#   echo "..." | NLM_MEMORY_NOTEBOOK=<id> bash memory-write.sh --title "mem/..." 
#
# Refuses content that looks like it contains secrets. Append-only.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

TITLE=""; FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --file)  FILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$TITLE" ] || { echo "error: --title required (mem/<YYYY-MM-DD>/<project>-<topic>)" >&2; exit 2; }

nlm_require
NB=$(nlm_notebook_id)

TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
if [ -n "$FILE" ]; then cat "$FILE" > "$TMP"; else cat > "$TMP"; fi
[ -s "$TMP" ] || { echo "error: empty entry" >&2; exit 2; }

if nlm_has_secret "$TMP"; then
  echo "error: entry looks like it contains a secret; redact it (<REDACTED>) and retry" >&2
  exit 3
fi

nlm source add "$NB" --text "$(cat "$TMP")" --title "$TITLE" --wait
echo "saved: $TITLE"
