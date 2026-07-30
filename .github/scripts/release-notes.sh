#!/usr/bin/env bash
#
# Generate release notes from Conventional Commits for a manual release.
#
# Considers only BREAKING / feat / fix commits in the range FROM_REF..TO_REF
# (defaults: last release tag .. HEAD) and computes the next semver version
# from them (BREAKING -> major, feat -> minor, fix -> patch), unless an explicit
# VERSION is supplied.
#
# Writes the notes to RELEASE_NOTES.md and emits outputs (to $GITHUB_OUTPUT):
#   changed, version, tag
#
set -euo pipefail

: "${GITHUB_OUTPUT:=/dev/stdout}"
emit() { printf '%s=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT}"; }

FROM_REF="${FROM_REF:-}"
TO_REF="${TO_REF:-HEAD}"
VERSION="${VERSION:-}"

last_tag="$(git tag --sort=-v:refname | head -n1 || true)"

# Range: explicit FROM_REF wins; otherwise since the last tag; otherwise all.
if [ -n "${FROM_REF}" ]; then
  range="${FROM_REF}..${TO_REF}"
elif [ -n "${last_tag}" ]; then
  range="${last_tag}..${TO_REF}"
else
  range=""
fi

if [ -n "${range}" ]; then
  commits="$(git rev-list --no-merges "${range}")"
else
  commits="$(git rev-list --no-merges "${TO_REF}")"
fi

# ---------------------------------------------------------------------------
# Classify commits: keep only breaking / feat / fix.
# ---------------------------------------------------------------------------
breaks=(); feats=(); fixes=()
while IFS= read -r sha; do
  [ -n "${sha}" ] || continue
  subject="$(git log -1 --format=%s "${sha}")"
  body="$(git log -1 --format=%b "${sha}")"
  short="$(git rev-parse --short "${sha}")"
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
  esac
done <<< "${commits}"

if [ "${#breaks[@]}" -eq 0 ] && [ "${#feats[@]}" -eq 0 ] && [ "${#fixes[@]}" -eq 0 ]; then
  echo "No BREAKING / feat / fix commits in ${range:-history}; nothing to release."
  emit changed false
  exit 0
fi

# ---------------------------------------------------------------------------
# Determine the version (relative to the last release tag).
# ---------------------------------------------------------------------------
if [ -n "${VERSION}" ]; then
  next="${VERSION#v}"
else
  base="${last_tag#v}"; base="${base:-0.0.0}"
  IFS=. read -r ma mi pa <<< "${base}"
  if   [ "${#breaks[@]}" -gt 0 ]; then ma=$((ma + 1)); mi=0; pa=0
  elif [ "${#feats[@]}"  -gt 0 ]; then mi=$((mi + 1)); pa=0
  else                                 pa=$((pa + 1)); fi
  next="${ma}.${mi}.${pa}"
fi
tag="v${next}"

if git rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  echo "::error::Tag ${tag} already exists. Provide a different 'version' input or delete the tag."
  exit 1
fi

# ---------------------------------------------------------------------------
# Write RELEASE_NOTES.md (latest release only).
# ---------------------------------------------------------------------------
{
  printf '# Release %s - %s\n' "${tag}" "$(date -u +%Y-%m-%d)"
  if [ "${#breaks[@]}" -gt 0 ]; then
    printf '\n### ⚠ BREAKING CHANGES\n\n'; printf '%s\n' "${breaks[@]}"
  fi
  if [ "${#feats[@]}" -gt 0 ]; then
    printf '\n### Features\n\n'; printf '%s\n' "${feats[@]}"
  fi
  if [ "${#fixes[@]}" -gt 0 ]; then
    printf '\n### Bug Fixes\n\n'; printf '%s\n' "${fixes[@]}"
  fi
  printf '\n'
} > RELEASE_NOTES.md

echo "Generated RELEASE_NOTES.md for ${tag}:"
echo "  BREAKING: ${#breaks[@]}, features: ${#feats[@]}, fixes: ${#fixes[@]}"

emit changed true
emit version "${next}"
emit tag "${tag}"
