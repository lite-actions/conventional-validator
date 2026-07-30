#!/usr/bin/env bash
#
# Validate commit messages against the Conventional Commits 1.0.0 spec.
# https://www.conventionalcommits.org/
#
# Format: <type>[optional scope][!]: <description>
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "${SCRIPT_DIR}/common.sh"

TYPES_ALT="$(to_alternation "${INPUT_COMMIT_TYPES:-feat fix docs style refactor perf test build ci chore revert}")"
REQUIRE_SCOPE="${INPUT_REQUIRE_SCOPE:-false}"
MAX_SUBJECT_LENGTH="${INPUT_MAX_SUBJECT_LENGTH:-100}"
VALIDATE_BODY="${INPUT_VALIDATE_BODY:-true}"

# The scope portion is required or optional depending on the input.
if [ "${REQUIRE_SCOPE}" = "true" ]; then
  SCOPE_RE='\([a-z0-9][a-z0-9._-]*\)'
else
  SCOPE_RE='(\([a-z0-9][a-z0-9._-]*\))?'
fi

# Full subject line regex (extended regex, anchored).
HEADER_RE="^(${TYPES_ALT})${SCOPE_RE}(!)?: .+"

# ---------------------------------------------------------------------------
# Determine the commit range to validate.
# ---------------------------------------------------------------------------
range=""
if [ -n "${INPUT_BASE_REF:-}" ]; then
  range="${INPUT_BASE_REF}..HEAD"
elif [ "${GITHUB_EVENT_NAME:-}" = "pull_request" ] || \
     [ "${GITHUB_EVENT_NAME:-}" = "pull_request_target" ]; then
  base_sha="$(jq -r '.pull_request.base.sha // empty' "${GITHUB_EVENT_PATH}")"
  head_sha="$(jq -r '.pull_request.head.sha // empty' "${GITHUB_EVENT_PATH}")"
  if [ -n "${base_sha}" ] && [ -n "${head_sha}" ]; then
    range="${base_sha}..${head_sha}"
  fi
elif [ "${GITHUB_EVENT_NAME:-}" = "push" ]; then
  before="$(jq -r '.before // empty' "${GITHUB_EVENT_PATH}")"
  after="$(jq -r '.after // empty' "${GITHUB_EVENT_PATH}")"
  # A new branch (or first push) reports an all-zero "before" sha.
  if [ -n "${before}" ] && [ "${before}" != "0000000000000000000000000000000000000000" ]; then
    range="${before}..${after}"
  fi
fi

# Collect the commit SHAs to check. Fall back to just HEAD when we have no
# usable range (e.g. brand new branch, manual dispatch, or local run).
# Read into an array without mapfile for portability with older bash.
commits=()
if [ -n "${range}" ]; then
  rev_output="$(git rev-list --no-merges "${range}")"
else
  rev_output="$(git rev-list --no-merges -n 1 HEAD)"
fi
while IFS= read -r line; do
  [ -n "${line}" ] && commits+=("${line}")
done <<< "${rev_output}"

if [ "${#commits[@]}" -eq 0 ]; then
  gh_notice "No commits to validate."
  exit 0
fi

echo "Validating ${#commits[@]} commit(s) against: ${HEADER_RE}"
echo

failures=0
for sha in "${commits[@]}"; do
  subject="$(git log -1 --format=%s "${sha}")"
  short="$(git rev-parse --short "${sha}")"

  # Skip auto-generated merge and revert commits.
  case "${subject}" in
    "Merge "*|"Revert "*)
      echo "⏭  ${short}  skipped (merge/revert): ${subject}"
      continue
      ;;
  esac

  reasons=()

  # --- Subject line ------------------------------------------------------
  if ! [[ "${subject}" =~ ${HEADER_RE} ]]; then
    reasons+=("subject does not match <type>[scope][!]: <description>")
  fi
  if [ "${MAX_SUBJECT_LENGTH}" -gt 0 ] && \
     [ "${#subject}" -gt "${MAX_SUBJECT_LENGTH}" ]; then
    reasons+=("subject is ${#subject} chars (max ${MAX_SUBJECT_LENGTH})")
  fi

  # --- Body & footers ----------------------------------------------------
  if [ "${VALIDATE_BODY}" = "true" ]; then
    # Full message body: everything after the subject line.
    second_line="$(git log -1 --format=%B "${sha}" | sed -n '2p')"
    if [ -n "${second_line}" ]; then
      reasons+=("body must be separated from the subject by a blank line")
    fi

    # A "!" in the header signals a breaking change; so does a footer.
    header_breaking=0
    [[ "${subject}" =~ ^[^:]*!: ]] && header_breaking=1

    footer_breaking=0
    while IFS= read -r line; do
      # Strict, spec-compliant breaking-change footer.
      if [[ "${line}" =~ ^(BREAKING[ ]CHANGE|BREAKING-CHANGE):\ .+ ]]; then
        footer_breaking=1
      # Same token written incorrectly (wrong case / missing space after ":").
      # The trailing ":" requirement is what distinguishes an intended footer
      # from ordinary prose that merely starts with the words "breaking change".
      elif [[ "${line}" =~ ^[Bb][Rr][Ee][Aa][Kk][Ii][Nn][Gg][\ -][Cc][Hh][Aa][Nn][Gg][Ee][[:space:]]*: ]]; then
        reasons+=("breaking change footer must be 'BREAKING CHANGE: <description>'")
      fi
    done <<< "$(git log -1 --format=%b "${sha}")"

    if [ "${header_breaking}" -eq 1 ] && [ "${footer_breaking}" -eq 0 ]; then
      # '!' is valid on its own, but a description is recommended.
      gh_notice "Commit ${short} marks a breaking change with '!'; consider adding a 'BREAKING CHANGE:' footer describing it."
    fi
  fi

  if [ "${#reasons[@]}" -eq 0 ]; then
    echo "✅ ${short}  ${subject}"
  else
    echo "❌ ${short}  ${subject}"
    for r in "${reasons[@]}"; do
      gh_error "Commit ${short}: ${r}"
    done
    failures=$((failures + 1))
  fi
done

echo
if [ "${failures}" -gt 0 ]; then
  gh_error "${failures} commit(s) failed Conventional Commits validation."
  cat >&2 <<'EOF'

Expected format:
  <type>[optional scope][!]: <description>

  [optional body, separated by a blank line]

  [optional footer(s), e.g. BREAKING CHANGE: <description>]

Examples:
  feat: add user login endpoint

  fix(api): handle empty payload

  refactor!: drop support for node 16

  feat(auth): add SSO support

  BREAKING CHANGE: sessions are now stored server-side
EOF
  exit 1
fi

echo "All commits follow the Conventional Commits spec. 🎉"
