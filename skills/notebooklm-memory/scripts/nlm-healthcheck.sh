#!/usr/bin/env bash
# nlm-healthcheck.sh: verify NotebookLM memory is really usable by Hermes.
#
#   bash nlm-healthcheck.sh [--server gemini_notebook_mcp] [--profile NAME]
#
# Exit 0 only if every hard check passes. "Connected but 0 tools" is a FAIL.
# Never prints credential contents.
set -uo pipefail

SERVER="gemini_notebook_mcp"
PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --server)  SERVER="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
PFLAG=""
[ -n "$PROFILE" ] && PFLAG="--profile $PROFILE"

fail=0
ok()   { echo "  ✓ $1"; }
bad()  { echo "  ✗ $1"; fail=1; }
warn() { echo "  ! $1"; }

echo "== NotebookLM memory healthcheck =="

# 1. binaries
if command -v nlm >/dev/null 2>&1; then
  ok "nlm: $(command -v nlm) ($(nlm --version 2>/dev/null | head -1))"
else
  bad "nlm not on PATH"
fi
if command -v notebooklm-mcp >/dev/null 2>&1; then
  ok "notebooklm-mcp: $(command -v notebooklm-mcp)"
else
  bad "notebooklm-mcp not on PATH"
fi

# 2. credential dir permissions (metadata only, never contents)
CRED="$HOME/.notebooklm-mcp-cli"
if [ -d "$CRED" ]; then
  mode=$(stat -c '%a' "$CRED" 2>/dev/null || stat -f '%Lp' "$CRED")
  owner=$(stat -c '%u' "$CRED" 2>/dev/null || stat -f '%u' "$CRED")
  if [ "$owner" != "$(id -u)" ]; then
    bad "$CRED owned by uid $owner, expected $(id -u)"
  elif [ "$mode" != "700" ]; then
    warn "$CRED mode $mode (recommend 700)"
  else
    ok "$CRED owner/mode OK"
  fi
else
  bad "$CRED missing (run: nlm login)"
fi

# 3. auth
if command -v nlm >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  if nlm login --check $PFLAG >/dev/null 2>&1; then
    ok "auth active${PROFILE:+ (profile $PROFILE)}"
  else
    bad "auth check failed (nlm auth refresh / nlm login)"
  fi
  # shellcheck disable=SC2086
  if out=$(nlm usage $PFLAG 2>&1); then
    ok "quota: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-160)"
  else
    warn "nlm usage unavailable"
  fi
  # 4. read-only smoke test
  # shellcheck disable=SC2086
  if nlm notebook list --json $PFLAG >/dev/null 2>&1; then
    ok "read-only notebook list"
  else
    bad "notebook list failed"
  fi
  if [ -n "${NLM_MEMORY_NOTEBOOK:-}" ]; then
    # shellcheck disable=SC2086
    if nlm notebook get "$NLM_MEMORY_NOTEBOOK" --json $PFLAG >/dev/null 2>&1; then
      ok "Master Brain notebook reachable"
    else
      bad "Master Brain notebook $NLM_MEMORY_NOTEBOOK not reachable"
    fi
  else
    warn "NLM_MEMORY_NOTEBOOK not set (agent may keep the id in Hermes memory instead)"
  fi
fi

# 5. Hermes MCP registration + tool count (negative gate)
if command -v hermes >/dev/null 2>&1; then
  if out=$(hermes mcp test "$SERVER" 2>&1); then
    n=$(printf '%s' "$out" | grep -oiE '[0-9]+ tools?' | head -1 | grep -oE '[0-9]+')
    if [ -z "$n" ]; then
      warn "hermes mcp test passed but tool count not parsed; check output manually"
    elif [ "$n" -eq 0 ]; then
      bad "MCP '$SERVER' connected but 0 tools: NOT VERIFIED"
    else
      ok "MCP '$SERVER': $n tools"
    fi
  else
    bad "hermes mcp test $SERVER failed"
  fi
else
  warn "hermes CLI not on PATH; MCP registration not checked"
fi

echo
if [ $fail -eq 0 ]; then
  echo "RESULT: HEALTHY"
else
  echo "RESULT: NOT VERIFIED (see ✗ above, and references/troubleshooting.md)"
fi
exit $fail
