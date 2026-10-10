#!/usr/bin/env bash
# check-secrets.sh: block secrets and private data from entering this PUBLIC repo.
# Works with macOS bash 3.2.
#
#   bash scripts/check-secrets.sh            # all tracked + untracked-not-ignored files
#   bash scripts/check-secrets.sh --staged   # staged files only (pre-commit)
#
# Prints file:line only, never the secret value. Exits 1 on any finding.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

LIST=$(mktemp)
trap 'rm -f "$LIST"' EXIT

if [ "${1:-}" = "--staged" ]; then
  git diff --cached --name-only --diff-filter=ACMR > "$LIST"
else
  { git ls-files; git ls-files --others --exclude-standard; } | sort -u > "$LIST"
fi
total=$(grep -c . "$LIST" || true)
[ "$total" -eq 0 ] && { echo "check-secrets: nothing to scan"; exit 0; }
echo "check-secrets: scanning $total file(s)"

fail=0
report() { echo "  ✗ $1"; fail=1; }

# files that legitimately contain secret-detecting regexes
SELF_SKIP='^(scripts/check-secrets\.sh|\.gitleaks\.toml|skills/[^/]+/scripts/lib\.sh)$'

# 1. forbidden paths (credentials, browser profiles, private memory, archives)
while IFS= read -r f; do
  case "$f" in
    *.env.example) ;;
    .env|*/.env|*.env|*.pem|*.key|*.p12|*id_rsa*|*id_ed25519*|\
    *credentials.json|*service-account*.json|*cookies.json|*cookies.txt|*Cookies|\
    *storage_state*.json|*"Local State"*|*.notebooklm-mcp-cli/*|*chrome-profiles/*|*profiles/default/*|\
    *vault*.yml|*vault*.yaml|*secrets.yml|*secrets.yaml|\
    */memories/*|*MEMORY.md|*USER.md|*DREAMS.md|*.tar.gz|*.tgz|*.zip|*.sqlite|*.db)
      report "forbidden file: $f" ;;
  esac
done < "$LIST"

# 2. content patterns (label|regex)
# shellcheck disable=SC2016  # literal regexes, no expansion intended
PATTERNS='vault-ciphertext|\$ANSIBLE_VAULT;
telegram-bot-token|[0-9]{8,10}:AA[A-Za-z0-9_-]{30,}
private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----
gcp-sa-json|"private_key":[[:space:]]*"-----BEGIN
google-api-key|AIza[0-9A-Za-z_-]{35}
google-session-cookie|(__Secure-[0-9]PSID|SAPISID|HSID|SSID|APISID)[\"=:[:space:]]+[A-Za-z0-9_./-]{20,}
openai/anthropic/openrouter|sk-(or-v1-|ant-|proj-)?[A-Za-z0-9_-]{20,}
github-token|gh[pousr]_[A-Za-z0-9]{36,}
slack-token|xox[baprs]-[A-Za-z0-9-]{10,}
aws-key|AKIA[0-9A-Z]{16}'

while IFS= read -r f; do
  [ -f "$f" ] || continue
  echo "$f" | grep -qE "$SELF_SKIP" && continue
  while IFS='|' read -r label regex; do
    hits=$(grep -nIE -e "$regex" "$f" 2>/dev/null | cut -d: -f1 | paste -sd, -)
    [ -n "$hits" ] && report "$label in $f (line $hits)"
  done <<< "$PATTERNS"
done < "$LIST"

if [ $fail -ne 0 ]; then
  echo "check-secrets: ✗ BLOCKED, fix the findings above before committing."
  exit 1
fi
echo "check-secrets: ✓ clean"
