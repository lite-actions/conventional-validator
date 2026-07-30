#!/usr/bin/env bash
# Shared helpers for the conventional-validator scripts.

set -euo pipefail

# Emit an error. Uses the GitHub Actions annotation syntax when running in
# Actions, otherwise a plain message (e.g. when used as a local pre-commit hook).
gh_error() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'Error: %s\n' "$*" >&2
  fi
}

# Emit a notice. Annotation syntax in Actions, plain message otherwise.
gh_notice() {
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    printf '::notice::%s\n' "$*"
  else
    printf '%s\n' "$*"
  fi
}

# Normalise a space/comma separated list into space separated, trimmed tokens.
normalize_list() {
  # shellcheck disable=SC2001
  echo "$1" | tr ',' ' ' | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//'
}

# Turn a token list into a regex alternation, e.g. "feat fix" -> "feat|fix".
to_alternation() {
  normalize_list "$1" | tr ' ' '|'
}

# Test whether a whitespace-separated list contains an exact value.
list_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}
