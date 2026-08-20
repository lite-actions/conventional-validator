# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Scope

A composite **GitHub Action** (pure shell) that validates **Conventional
Commits** and **Conventional Branch** names, and _also_ ships a **pre-commit
hook** for local branch-name validation. Two surfaces, one codebase:

1. Action: `uses: lite-actions/conventional-validator@v1` in a workflow.
2. Pre-commit: `repo: https://github.com/lite-actions/conventional-validator`,
   `hooks: [{id: conventional-branch, args: [...]}]`.

It is Marketplace-oriented and dogfoods itself (its own PRs run the action; its
pre-commit config uses its own hook).

## Layout

- `action.yml` — composite; two shell steps run `scripts/validate-commits.sh`
  and `scripts/validate-branch.sh` with `INPUT_*` env.
- `scripts/common.sh` — shared helpers: `gh_error`/`gh_notice`,
  `normalize_list`, `to_alternation`, `list_contains`.
- `scripts/validate-commits.sh`, `scripts/validate-branch.sh` — the validators.
- `.pre-commit-hooks.yaml` — defines the `conventional-branch` hook (entry:
  `scripts/validate-branch.sh`, `language: script`, `pass_filenames: false`).
- `tests/test.sh` — the behavioural spec (assert-based).
- `README.md`, `LICENSE` (MIT), `SECURITY.md`, `CONTRIBUTING.md`, `TODO.md`.
- **Full CI/CD governance** under `.github/` — see that section below.

## How the validators work

**Inputs** (`action.yml`): `validate-commits`, `validate-branch`,
`validate-body`, `commit-types`, `branch-types`, `require-scope`,
`max-subject-length`, `protected-branches`, `allow-underscores`, `base-ref`.

**`validate-commits.sh`** — resolves the commit range (`INPUT_BASE_REF`, else
the `pull_request` `base..head` from the event JSON, else `push`
`before..after`, else just `HEAD`), then per commit checks the subject regex
`^(<types>)(\(scope\))?(!)?: .+`, subject length, and (when `validate-body`)
that a body is blank-line-separated and any `BREAKING CHANGE:` footer is
well-formed. Merge/revert commits are skipped.

**`validate-branch.sh`** — gets the branch from `GITHUB_HEAD_REF` /
`GITHUB_REF_NAME` / `git symbolic-ref`; skips protected branches; validates
`<type>/<description>`. **Branch types are configurable two ways** with
precedence: positional **CLI args** (pre-commit `args:`) > `INPUT_BRANCH_TYPES`
env (the Action) > built-in default.

**`common.sh`** — `gh_error`/`gh_notice` emit GitHub `::error::`/`::notice::`
annotations only when `GITHUB_ACTIONS=true`, and plain text otherwise (so output
is clean when run as a local pre-commit hook).

### Behaviours that are locked by tests (don't regress)

- **Breaking-change prose is not a footer.** A body line that merely _starts
  with_ "breaking change" must pass; only a real footer (`BREAKING CHANGE:` with
  the colon) is enforced. The malformed-footer check requires the trailing
  colon.
- **`allow-underscores`** is off by default (spec-pure). When `true`, branch
  segments may contain `_` — needed for Dependabot branches like
  `dependabot/github_actions/…`. Dependabot support is opt-in per consumer
  (`branch-types: "… dependabot"` + `allow-underscores: "true"`); see README
  "Using with Dependabot". The default lists must stay spec-compliant.
- Commit-type and branch-type default lists are **intentionally different**
  vocabularies (`feat/fix/…` vs `feature/bugfix/…`; only `chore` overlaps) —
  keep them independent.

## Commands

```bash
bash tests/test.sh
shellcheck -x --severity=warning scripts/*.sh tests/*.sh
pre-commit run conventional-branch          # exercise the hook locally
```

## Coding style

- Pure `bash` with `set -euo pipefail`; must pass
  `shellcheck -x --severity=warning` (the `lint` workflow enforces it).
- The regexes are the heart of the tool — change them alongside a test. Quote
  `done` when literal (SC1010); prefer `awk`/`printf` over `sed | head`.
- Keep CI-vs-local output correct via `gh_error`/`gh_notice` (don't print raw
  `::error::` unconditionally).
- Untrusted input (commit messages, branch names) is only pattern-matched and
  printed, never `eval`'d. Consumers run it on `pull_request`, not
  `pull_request_target`.

## CI/CD governance (this repo has the full treatment; `main` is protected)

- **Branch protection**: required checks `validate` + `lint` (the `test`
  workflow also runs but isn't required), 1 review with code-owner + last-push
  approval, `enforce_admins`. `CODEOWNERS` lists `@mrdoodles` + `@MrDClaudeBot`.
- **Landing changes**: PR only, approved by the second `MrDClaudeBot` account
  (you can't self-approve); auto-merge with `--rebase`; **squash disabled**.
- **`changelog.yml`** maintains `CHANGELOG.md` via an auto-merged PR using two
  PAT secrets (`CHANGELOG_BOT_TOKEN` opens the PR so checks run;
  `CHANGELOG_APPROVE_TOKEN`, a **classic** `MrDClaudeBot` PAT, approves). **Do
  not hand-edit `CHANGELOG.md`.**
- **`publish.yml`** (manual `workflow_dispatch`): computes the version from
  BREAKING/feat/fix, tags `vX.Y.Z`, **force-moves the `vN` major tag** so `@v1`
  consumers get updates, and publishes a GitHub Release. It uses tags only, so
  it needs no PAT (tags aren't branch-protected).
- `@v1` is the moving major tag (currently v1.3.3). Cut new versions via
  `publish.yml`, not by hand.
- `publish.yml` only cuts a version when the range contains BREAKING/feat/fix
  commits; a run of pure `chore`/`ci`/`docs` commits reports "nothing to
  release". Use the `version` input to force one.
- **`TODO.md`** tracks deferred work: add release-notes automation (consume
  `lite-actions/release-notes`) _after_ Marketplace publish.

## Versioning & publishing

Releases are cut by `publish.yml` (`workflow_dispatch`) — never by hand, and
never through the GitHub web UI:

```bash
gh workflow run publish.yml --repo lite-actions/conventional-validator
```

The workflow is named `publish` rather than `release` because "release" is
overloaded here: `release-notes` generates notes, `rust-release` builds
binaries, and this cuts and publishes a version. `publish` names the intent.

It computes the version from the commits since the last `vX.Y.Z` tag, tags the
release, force-moves `@vN`, and publishes the GitHub Release with the generated
notes as its body. `@vN` is the moving major tag consumers use.

**Never create a release through the web UI.** The "publish to the Marketplace"
checkbox is required only for an action's *first* publish; once a listing
exists, releases cut by the workflow appear on it automatically — verified
2026-08-20 on `git-checkout`, where `v1.1.0` reached the listing with nothing
ticked. Using the UI afterwards is what produced the `v1.12` and `1.3.5` tags,
and left `@v1` pointing at an old commit three times. The workflow types
nothing, so it cannot mistype.

## Marketplace notes

Publishing needs a globally-unique `name:` in `action.yml`, 2FA on the account,
and publishing a release that contains the current code.
