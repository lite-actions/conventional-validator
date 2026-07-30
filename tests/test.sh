#!/usr/bin/env bash
#
# Exercises the validation scripts against known good/bad inputs and asserts
# their exit codes. Run locally or in CI: bash tests/test.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMITS="${ROOT}/scripts/validate-commits.sh"
BRANCH="${ROOT}/scripts/validate-branch.sh"

pass=0
fail=0
check() { # description  expected_exit  actual_exit
  if [ "$2" -eq "$3" ]; then
    echo "  ok   - $1"
    pass=$((pass + 1))
  else
    echo "  FAIL - $1 (expected exit $2, got $3)"
    fail=$((fail + 1))
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}" || exit 1
git init -q
git config user.email test@example.com
git config user.name test

# Neutralise the CI environment so the scripts fall back to HEAD / the ref vars.
export GITHUB_ACTIONS=""
export GITHUB_EVENT_NAME=""
export GITHUB_HEAD_REF=""
export INPUT_COMMIT_TYPES="feat fix docs chore refactor"
export INPUT_MAX_SUBJECT_LENGTH=100
export INPUT_VALIDATE_BODY=true
export INPUT_BRANCH_TYPES="feature bugfix hotfix release chore"
export INPUT_PROTECTED_BRANCHES="main"

echo "commit validation:"
git commit -q --allow-empty -m "feat: a valid subject"
bash "${COMMITS}" >/dev/null 2>&1; check "valid conventional commit passes" 0 $?

git commit -q --allow-empty -m "just a normal sentence"
bash "${COMMITS}" >/dev/null 2>&1; check "non-conventional commit fails" 1 $?

git commit -q --allow-empty -m "feat: has body" -m "no blank line issue is fine when built with -m"
bash "${COMMITS}" >/dev/null 2>&1; check "commit with a proper body passes" 0 $?

# Regression: body prose starting with "breaking change" must NOT be flagged.
git commit -q --allow-empty -F - <<'EOF'
fix: improve retry logic

Breaking change avoidance was the goal here; nothing actually breaks.
EOF
bash "${COMMITS}" >/dev/null 2>&1; check "body prose 'breaking change ...' passes (regression)" 0 $?

# A genuinely malformed breaking-change footer must still fail.
git commit -q --allow-empty -F - <<'EOF'
feat: thing

breaking change: lowercase footer is malformed
EOF
bash "${COMMITS}" >/dev/null 2>&1; check "malformed breaking-change footer fails" 1 $?

echo "branch validation:"
GITHUB_REF_NAME="feature/add-login" bash "${BRANCH}" >/dev/null 2>&1; check "valid branch name passes" 0 $?
GITHUB_REF_NAME="Feature/Bad_Branch" bash "${BRANCH}" >/dev/null 2>&1; check "invalid branch name fails" 1 $?
GITHUB_REF_NAME="main" bash "${BRANCH}" >/dev/null 2>&1; check "protected branch is skipped (passes)" 0 $?

echo
echo "passed: ${pass}, failed: ${fail}"
[ "${fail}" -eq 0 ]
