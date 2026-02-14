#!/usr/bin/env bash
#
# setup-hooks.sh — Install git hooks for the project.
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."

# pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'HOOK'
#!/usr/bin/env bash
# Auto-installed by scripts/setup-hooks.sh
# Runs secret detection before every commit.

REPO_ROOT="$(git rev-parse --show-toplevel)"
exec "$REPO_ROOT/scripts/check-secrets.sh"
HOOK

chmod +x "$HOOKS_DIR/pre-commit"

echo "Installed: pre-commit (secret detection)"
echo "Done. Hooks are active."
