#!/usr/bin/env bash
#
# Validate the branch name against the Conventional Branch spec.
# https://conventional-branch.github.io/
#
# Format: <type>/<description>
#   - lowercase alphanumerics and hyphens in each segment
#   - "/" as the delimiter (nested segments allowed, e.g. feature/issue-42/foo)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

DEFAULT_BRANCH_TYPES="feature bugfix hotfix release chore"
# Precedence: positional CLI args (e.g. a pre-commit hook's `args:`) override the
# INPUT_BRANCH_TYPES env var (used by the GitHub Action), which overrides the
# built-in default.
if [ "$#" -gt 0 ]; then
  BRANCH_TYPES="$*"
else
  BRANCH_TYPES="${INPUT_BRANCH_TYPES:-${DEFAULT_BRANCH_TYPES}}"
fi
TYPES_ALT="$(to_alternation "${BRANCH_TYPES}")"

# Segment character set. The Conventional Branch spec allows lowercase letters,
# digits and hyphens. Underscores are off by default (spec-pure); opt in with
# INPUT_ALLOW_UNDERSCORES=true, e.g. to accept Dependabot branches like
# dependabot/github_actions/... (see README "Using with Dependabot").
if [ "${INPUT_ALLOW_UNDERSCORES:-false}" = "true" ]; then
  SEG="a-z0-9_-"
else
  SEG="a-z0-9-"
fi
PROTECTED="$(normalize_list "${INPUT_PROTECTED_BRANCHES:-main}")"

# ---------------------------------------------------------------------------
# Determine the branch name being validated.
# For pull requests GITHUB_HEAD_REF holds the source branch; otherwise use the
# short ref name of whatever triggered the run.
# ---------------------------------------------------------------------------
branch="${GITHUB_HEAD_REF:-}"
if [ -z "${branch}" ]; then
  branch="${GITHUB_REF_NAME:-}"
fi
if [ -z "${branch}" ]; then
  # symbolic-ref resolves the branch even on an unborn branch (first commit);
  # fall back to rev-parse for the detached-HEAD case.
  branch="$(git symbolic-ref --short HEAD 2>/dev/null \
    || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
fi

if [ -z "${branch}" ]; then
  gh_error "Could not determine the branch name to validate."
  exit 1
fi

echo "Validating branch name: ${branch}"

# Exempt protected / long-lived branches.
if list_contains "${branch}" ${PROTECTED}; then
  gh_notice "Branch '${branch}' is protected; skipping validation."
  exit 0
fi

# <type>/<segment>[/<segment>...] with lowercase, digits and hyphens.
BRANCH_RE="^(${TYPES_ALT})/[a-z0-9]([${SEG}]*[a-z0-9])?(/[a-z0-9]([${SEG}]*[a-z0-9])?)*$"

if [[ "${branch}" =~ ${BRANCH_RE} ]]; then
  echo "✅ Branch '${branch}' follows the Conventional Branch spec."
  exit 0
fi

gh_error "Branch '${branch}' does not follow the Conventional Branch spec."
cat >&2 <<EOF

Expected format:
  <type>/<description>

Allowed types:
  $(normalize_list "${BRANCH_TYPES}")

Rules:
  - lowercase letters, digits and hyphens only
  - "/" separates the type from the description
  - no leading/trailing/double hyphens in a segment

Examples:
  feature/add-login
  bugfix/issue-123-null-pointer
  release/2.1.0
EOF
exit 1
