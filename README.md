# Conventional Validator

A composite GitHub Action (pure shell) that validates:

1. **Commit messages** against the
   [Conventional Commits](https://www.conventionalcommits.org/) spec.
2. **Branch names** against the
   [Conventional Branch](https://conventional-branch.github.io/) spec.

It also ships a [pre-commit](https://pre-commit.com/) hook for local branch-name
validation. No Node/Docker runtime — just `bash`, `git` and `jq` (all
preinstalled on GitHub-hosted runners).

## Use as a GitHub Action

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0 # needed so the commit range can be resolved
      - uses: lite-actions/conventional-validator@v1
        with:
          validate-commits: "true"
          validate-branch: "true"
```

`@v1` tracks the latest `v1.x.y` release. For stricter supply-chain guarantees,
pin to a full commit SHA instead:

```yaml
- uses: lite-actions/conventional-validator@<commit-sha> # v1.3.4
```

Any checkout action works, as long as it fetches full history.
[`lite-actions/git-checkout`](https://github.com/lite-actions/git-checkout) is a
pure-shell drop-in replacement for `actions/checkout` — same inputs, one line to
swap:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: lite-actions/git-checkout@v1
        with:
          fetch-depth: 0 # needed so the commit range can be resolved
      - uses: lite-actions/conventional-validator@v1
        with:
          validate-commits: "true"
          validate-branch: "true"
```

### Inputs

| Input                | Default                                                        | Description                                                     |
| -------------------- | -------------------------------------------------------------- | --------------------------------------------------------------- |
| `validate-commits`   | `true`                                                         | Validate commit messages.                                       |
| `validate-branch`    | `true`                                                         | Validate the branch name.                                       |
| `validate-body`      | `true`                                                         | Check body blank-line separation and `BREAKING CHANGE:` footer. |
| `commit-types`       | `feat fix docs style refactor perf test build ci chore revert` | Allowed Conventional Commit types.                              |
| `branch-types`       | `feature bugfix hotfix release chore`                          | Allowed Conventional Branch prefixes.                           |
| `require-scope`      | `false`                                                        | Require a scope on every commit, e.g. `feat(api):`.             |
| `max-subject-length` | `100`                                                          | Max commit subject length (`0` disables).                       |
| `protected-branches` | `main`                                                         | Branch names exempt from branch validation.                     |
| `allow-underscores`  | `false`                                                        | Allow underscores in branch segments (off = spec-pure).         |
| `base-ref`           | `""`                                                           | Explicit base ref for the commit range (auto-derived if empty). |

## Use as a pre-commit hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/lite-actions/conventional-validator
    rev: v1
    hooks:
      - id: conventional-branch
```

The allowed branch types default to `feature bugfix hotfix release chore`. To
use a different list, pass it as `args` (each type is a separate entry):

```yaml
- id: conventional-branch
  args: [feature, bugfix, hotfix, release, chore, dependabot]
```

## What is validated

**Commits** — `<type>[optional scope][!]: <description>`, with an optional body
(blank-line separated) and `BREAKING CHANGE:` footer. Merge/revert commits are
skipped.

**Branches** — `<type>/<description>` (lowercase, digits and hyphens).

## Using with Dependabot

Dependabot branch names are always `dependabot/…` and, for some ecosystems,
contain underscores (e.g. `dependabot/github_actions/actions/checkout-5`).
Neither the `dependabot` prefix nor the underscore can be changed via
`dependabot.yml`, so by default such branches **fail** branch validation.

The defaults stay spec-pure. To let Dependabot PRs pass, opt in per-consumer by
adding `dependabot` to `branch-types` **and** enabling `allow-underscores`:

```yaml
- uses: lite-actions/conventional-validator@v1
  with:
    branch-types: "feature bugfix hotfix release chore dependabot"
    allow-underscores: "true"
```

Also set a conventional commit prefix in `dependabot.yml` so the commits pass
commit validation and read cleanly:

```yaml
# .github/dependabot.yml
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
    commit-message:
      prefix: "chore(deps)"
```

> **Consequence of removing it:** if you drop `dependabot` from `branch-types`
> (or disable `allow-underscores`), Dependabot pull requests will fail the
> branch check on GitHub and can't be merged until the check is satisfied.
> Alternatively, skip validation for Dependabot in your workflow with
> `if: github.actor != 'dependabot[bot]'`.

## Commit range resolution

- `pull_request` — `base.sha..head.sha` from the event payload.
- `push` — `before..after` (falls back to `HEAD` for new branches).
- Otherwise — the single `HEAD` commit, or `base-ref..HEAD` if `base-ref` is
  set.
