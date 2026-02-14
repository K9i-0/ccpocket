#!/usr/bin/env bash
#
# check-secrets.sh — Detect accidental secret leaks in staged files.
# Used as a pre-commit hook and can also be run standalone.
#
set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ERRORS=0

# ── 1. Forbidden file patterns ──────────────────────────────────────────────
# Files that should NEVER be committed regardless of content.
FORBIDDEN_FILES=(
  '\.env$'
  '\.env\.local$'
  '\.env\.production$'
  '\.env\.development$'
  'id_rsa$'
  'id_ed25519$'
  '\.pem$'
  '\.key$'
  '\.p12$'
  '\.pfx$'
  '\.keystore$'
  '\.jks$'
  'credentials\.json$'
  'service-account.*\.json$'
  'google-services\.json$'
  'GoogleService-Info\.plist$'
)

# ── 2. Suspicious content patterns ──────────────────────────────────────────
# Regex patterns that likely indicate hardcoded secrets.
# Each entry: "pattern|description"
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}|AWS Access Key ID'
  'sk-[a-zA-Z0-9]{20,}|OpenAI / Stripe secret key'
  'sk-ant-[a-zA-Z0-9-]{20,}|Anthropic API key'
  'ghp_[a-zA-Z0-9]{36}|GitHub personal access token'
  'gho_[a-zA-Z0-9]{36}|GitHub OAuth token'
  'github_pat_[a-zA-Z0-9_]{22,}|GitHub fine-grained PAT'
  'xoxb-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24}|Slack bot token'
  'xoxp-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24}|Slack user token'
  'hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[a-zA-Z0-9]+|Slack webhook URL'
  'AIza[0-9A-Za-z_-]{35}|Google API key'
  '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----|Private key file'
  'BRIDGE_API_KEY\s*=\s*["\x27][^"\x27]{8,}|Hardcoded BRIDGE_API_KEY value'
  'password\s*[:=]\s*["\x27][^"\x27]{8,}|Hardcoded password'
  'secret\s*[:=]\s*["\x27][^"\x27]{8,}|Hardcoded secret'
  'token\s*[:=]\s*["\x27][^"\x27]{8,}|Hardcoded token'
)

# ── 3. Allowlist ────────────────────────────────────────────────────────────
# Patterns to ignore (template placeholders, test fixtures, etc.)
ALLOWLIST=(
  'YOUR_SECRET_KEY_HERE'
  'YOUR_USERNAME'
  'your[-_]?api[-_]?key'
  'placeholder'
  'example\.com'
  'test[-_]?key'
  'dummy'
  'xxxx'
  'check-secrets\.sh'     # This script itself
)

# Build grep -v pattern from allowlist
build_allowlist_pattern() {
  local pattern=""
  for item in "${ALLOWLIST[@]}"; do
    if [ -z "$pattern" ]; then
      pattern="$item"
    else
      pattern="$pattern|$item"
    fi
  done
  echo "$pattern"
}

ALLOWLIST_PATTERN=$(build_allowlist_pattern)

# ── Get staged files ────────────────────────────────────────────────────────
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  echo "No staged files to check."
  exit 0
fi

# ── Check 1: Forbidden files ───────────────────────────────────────────────
echo "Checking for forbidden files..."
for file in $STAGED_FILES; do
  for pattern in "${FORBIDDEN_FILES[@]}"; do
    if echo "$file" | grep -qE "$pattern"; then
      echo -e "${RED}BLOCKED${NC}: $file matches forbidden pattern ($pattern)"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# ── Check 2: Secret patterns in file content ──────────────────────────────
echo "Scanning staged content for secrets..."
for file in $STAGED_FILES; do
  # Skip binary files
  if file "$file" 2>/dev/null | grep -q "binary"; then
    continue
  fi

  # Skip files that don't exist (deleted files)
  if [ ! -f "$file" ]; then
    continue
  fi

  # Get staged content (not working tree)
  STAGED_CONTENT=$(git show ":$file" 2>/dev/null || true)
  if [ -z "$STAGED_CONTENT" ]; then
    continue
  fi

  for entry in "${SECRET_PATTERNS[@]}"; do
    pattern="${entry%%|*}"
    description="${entry##*|}"

    # Search staged content, filter allowlist
    MATCHES=$(echo "$STAGED_CONTENT" \
      | grep -nEi "$pattern" 2>/dev/null \
      | grep -vEi "$ALLOWLIST_PATTERN" 2>/dev/null \
      || true)

    if [ -n "$MATCHES" ]; then
      echo -e "${RED}BLOCKED${NC}: Potential secret in ${YELLOW}$file${NC}"
      echo "  Pattern: $description"
      echo "$MATCHES" | head -3 | while IFS= read -r line; do
        echo "  > $line"
      done
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# ── Check 3: Large files (might be binaries / data dumps) ─────────────────
echo "Checking for large files..."
for file in $STAGED_FILES; do
  if [ -f "$file" ]; then
    SIZE=$(wc -c < "$file" 2>/dev/null || echo 0)
    # 1MB threshold
    if [ "$SIZE" -gt 1048576 ]; then
      echo -e "${YELLOW}WARNING${NC}: Large file ($((SIZE / 1024))KB): $file"
      echo "  Consider adding to .gitignore if this is generated/binary."
    fi
  fi
done

# ── Result ─────────────────────────────────────────────────────────────────
echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo -e "${RED}Secret check failed with $ERRORS issue(s).${NC}"
  echo ""
  echo "If this is a false positive, you can:"
  echo "  1. Add the pattern to ALLOWLIST in scripts/check-secrets.sh"
  echo "  2. Bypass with: git commit --no-verify (use with caution!)"
  exit 1
else
  echo "Secret check passed."
  exit 0
fi
