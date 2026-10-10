#!/usr/bin/env bash
# Shared helpers for notebooklm-memory scripts. Source it, don't execute it.
# Bash 3.2 compatible (macOS).

# Patterns that must never be uploaded to NotebookLM.
# shellcheck disable=SC2016  # literal regexes, no expansion intended
NLM_SECRET_PATTERNS='[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}
-----BEGIN [A-Z ]*PRIVATE KEY-----
AIza[0-9A-Za-z_-]{35}
sk-(or-v1-|ant-|proj-)?[A-Za-z0-9_-]{20,}
gh[pousr]_[A-Za-z0-9]{36,}
xox[baprs]-[A-Za-z0-9-]{10,}
AKIA[0-9A-Z]{16}
\$ANSIBLE_VAULT;
(password|passwd|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*[^[:space:]<]{8,}'

# nlm_has_secret FILE -> exit 0 if FILE looks like it contains a secret.
nlm_has_secret() {
  local f="$1" re
  while IFS= read -r re; do
    [ -z "$re" ] && continue
    if grep -qiE -e "$re" "$f" 2>/dev/null; then
      return 0
    fi
  done <<EOF
$NLM_SECRET_PATTERNS
EOF
  return 1
}

# nlm_notebook_id -> prints the Master Brain notebook id or fails.
nlm_notebook_id() {
  if [ -n "${NLM_MEMORY_NOTEBOOK:-}" ]; then
    printf '%s\n' "$NLM_MEMORY_NOTEBOOK"
    return 0
  fi
  echo "error: set NLM_MEMORY_NOTEBOOK=<Master Brain notebook id> (see: nlm notebook list)" >&2
  return 1
}

nlm_require() {
  command -v nlm >/dev/null 2>&1 || {
    echo "error: nlm not found (uv tool install notebooklm-mcp-cli; check PATH)" >&2
    exit 2
  }
}
