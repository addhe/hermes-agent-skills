#!/usr/bin/env bash
# seed-memory.sh: bulk-import existing markdown notes into the Master Brain.
#
#   NLM_MEMORY_NOTEBOOK=<id> bash seed-memory.sh [--apply] [--prefix seed] FILE_OR_DIR...
#
# Default is DRY RUN (lists what would be uploaded). Pass --apply to upload.
# Each .md/.txt file becomes one text source titled "<prefix>/<relative-path>".
# Files that look like they contain secrets are SKIPPED. Redact and re-run.
# Mind your account's per-notebook source cap: merge small files first if needed.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$DIR/lib.sh"

APPLY=0; PREFIX="seed"; SLEEP="${NLM_SEED_SLEEP:-3}"
ARGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)  APPLY=1; shift ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) ARGS="$ARGS
$1"; shift ;;
  esac
done
[ -n "$ARGS" ] || { echo "error: give at least one file or directory" >&2; exit 2; }

LIST=$(mktemp); trap 'rm -f "$LIST"' EXIT
# each line: <path to read>|<title suffix relative to the given dir>
printf '%s\n' "$ARGS" | while IFS= read -r p; do
  [ -z "$p" ] && continue
  if [ -d "$p" ]; then
    (cd "$p" && find . -type f \( -name '*.md' -o -name '*.txt' \) | sort) \
      | sed -E 's#^\./##' | while IFS= read -r rel; do
          printf '%s|%s\n' "${p%/}/$rel" "$rel"
        done
  elif [ -f "$p" ]; then
    printf '%s|%s\n' "$p" "$(basename "$p")"
  fi
done > "$LIST"

total=$(grep -c . "$LIST" || true)
echo "seed-memory: $total candidate file(s); mode: $([ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN)"
[ "$total" -eq 0 ] && exit 0

if [ $APPLY -eq 1 ]; then
  nlm_require
  NB=$(nlm_notebook_id)
fi

up=0; skip=0
while IFS='|' read -r f rel; do
  title="$PREFIX/$rel"
  if [ ! -s "$f" ]; then
    echo "  - skip (empty): $f"; skip=$((skip+1)); continue
  fi
  if nlm_has_secret "$f"; then
    echo "  ✗ skip (possible secret, redact first): $f"; skip=$((skip+1)); continue
  fi
  if [ $APPLY -eq 1 ]; then
    if nlm source add "$NB" --text "$(cat "$f")" --title "$title" --wait >/dev/null; then
      echo "  ✓ $title"; up=$((up+1))
    else
      echo "  ✗ upload failed: $f (stopping, check quota with: nlm usage)"; exit 1
    fi
    sleep "$SLEEP"
  else
    echo "  · would upload: $title ($(wc -c < "$f" | tr -d ' ') bytes)"
  fi
done < "$LIST"

echo "seed-memory: uploaded=$up skipped=$skip"
