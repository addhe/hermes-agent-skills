#!/usr/bin/env bash
# install-hooks.sh: install pre-commit (staged scan) and pre-push (full + gitleaks) hooks.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

cat > .git/hooks/pre-commit <<'EOF'
#!/usr/bin/env bash
exec bash scripts/check-secrets.sh --staged
EOF

cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
set -e
bash scripts/check-secrets.sh
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks git --config .gitleaks.toml --redact --no-banner .
else
  echo "pre-push: gitleaks not installed, history scan skipped (CI still runs it)" >&2
fi
EOF
chmod +x .git/hooks/pre-commit .git/hooks/pre-push
echo "Installed pre-commit and pre-push hooks."
