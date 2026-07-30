#!/usr/bin/env bash
#
# Update CHANGELOG.md from Conventional Commits. Intended to run on push/merge
# to main. This script is NOT concerned with versioning or tagging: it simply
# logs the commits from the push, grouped by type, each referenced by its short
# commit SHA, under a dated section.
#
# Commit range: the push's before..after (from $BEFORE_SHA/$AFTER_SHA or the
# event payload); falls back to the tip commit for a new branch / local run.
#
# Outputs (to $GITHUB_OUTPUT): changed
#
set -euo pipefail

: "${GITHUB_OUTPUT:=/dev/stdout}"
emit() { printf '%s=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT}"; }

# ---------------------------------------------------------------------------
# 1. Determine the commit range for this push.
# ---------------------------------------------------------------------------
before="${BEFORE_SHA:-}"
after="${AFTER_SHA:-}"
if [ -z "${before}${after}" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  before="$(jq -r '.before // empty' "${GITHUB_EVENT_PATH}")"
  after="$(jq -r '.after // empty' "${GITHUB_EVENT_PATH}")"
fi
after="${after:-HEAD}"

zero="0000000000000000000000000000000000000000"
if [ -n "${before}" ] && [ "${before}" != "${zero}" ]; then
  commits="$(git rev-list --no-merges "${before}..${after}")"
else
  # New branch or local run: log the tip commit only.
  commits="$(git rev-list --no-merges -n 1 "${after}")"
fi

if [ -z "${commits}" ]; then
  echo "No new commits in this push; nothing to log."
  emit changed false
  exit 0
fi

# ---------------------------------------------------------------------------
# 2. Group the commits by type; each entry references its short SHA.
# ---------------------------------------------------------------------------
breaks=(); feats=(); fixes=(); perfs=(); others=()
while IFS= read -r sha; do
  [ -n "${sha}" ] || continue
  subject="$(git log -1 --format=%s "${sha}")"
  body="$(git log -1 --format=%b "${sha}")"
  short="$(git rev-parse --short "${sha}")"
  # Description = subject with the "type(scope)!:" prefix stripped.
  desc="$(printf '%s' "${subject}" | sed -E 's/^[a-z]+(\([^)]+\))?!?:[[:space:]]*//')"
  line="- ${desc} (${short})"
  type="${subject%%[(:!]*}"

  if printf '%s' "${subject}" | grep -Eq '^[a-z]+(\([^)]+\))?!:' \
     || printf '%s' "${body}" | grep -Eq '^(BREAKING[ ]CHANGE|BREAKING-CHANGE):'; then
    bc="$(printf '%s' "${body}" | sed -n -E 's/^(BREAKING[ ]CHANGE|BREAKING-CHANGE):[[:space:]]*(.*)/\2/p' | head -n1)"
    [ -n "${bc}" ] || bc="${desc}"
    breaks+=("- ${bc} (${short})")
  fi

  case "${type}" in
    feat) feats+=("${line}") ;;
    fix)  fixes+=("${line}") ;;
    perf) perfs+=("${line}") ;;
    *)    others+=("${line}") ;;
  esac
done <<< "${commits}"

# ---------------------------------------------------------------------------
# 3. Build the new section, headed by the date and the tip short SHA.
# ---------------------------------------------------------------------------
tip_short="$(git rev-parse --short "${after}")"
section="$(mktemp)"
{
  printf '## %s (%s)\n' "$(date -u +%Y-%m-%d)" "${tip_short}"
  if [ "${#breaks[@]}" -gt 0 ]; then
    printf '\n### ⚠ BREAKING CHANGES\n\n'; printf '%s\n' "${breaks[@]}"
  fi
  if [ "${#feats[@]}" -gt 0 ]; then
    printf '\n### Features\n\n'; printf '%s\n' "${feats[@]}"
  fi
  if [ "${#fixes[@]}" -gt 0 ]; then
    printf '\n### Bug Fixes\n\n'; printf '%s\n' "${fixes[@]}"
  fi
  if [ "${#perfs[@]}" -gt 0 ]; then
    printf '\n### Performance\n\n'; printf '%s\n' "${perfs[@]}"
  fi
  if [ "${#others[@]}" -gt 0 ]; then
    printf '\n### Other Changes\n\n'; printf '%s\n' "${others[@]}"
  fi
  printf '\n'
} > "${section}"

# ---------------------------------------------------------------------------
# 4. Create or update CHANGELOG.md (newest section first).
# ---------------------------------------------------------------------------
header_matter() {
  printf '# Changelog\n\n'
  printf 'All notable changes to this project are documented in this file,\n'
  printf 'grouped by push and referenced by short commit SHA.\n\n'
}

if [ ! -f CHANGELOG.md ]; then
  { header_matter; cat "${section}"; } > CHANGELOG.md
  echo "Created CHANGELOG.md."
else
  # Prepend the new section before the first existing dated section.
  tmp="$(mktemp)"
  awk 'NR==FNR { sect = sect $0 ORS; next }
       /^## / && !ins { printf "%s", sect; ins = 1 }
       { print }
       END { if (!ins) printf "%s%s", ORS, sect }' \
       "${section}" CHANGELOG.md > "${tmp}"
  mv "${tmp}" CHANGELOG.md
  echo "Updated CHANGELOG.md."
fi

emit changed true
