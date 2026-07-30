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
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0 # needed so the commit range can be resolved
      - uses: mrdoodles/conventional-validator@v1
        with:
          validate-commits: "true"
          validate-branch: "true"
```

### Inputs

| Input                | Default                                                         | Description                                                       |
| -------------------- | -------------------------------------------------------------- | ----------------------------------------------------------------- |
| `validate-commits`   | `true`                                                         | Validate commit messages.                                         |
| `validate-branch`    | `true`                                                         | Validate the branch name.                                         |
| `validate-body`      | `true`                                                         | Check body blank-line separation and `BREAKING CHANGE:` footer.   |
| `commit-types`       | `feat fix docs style refactor perf test build ci chore revert` | Allowed Conventional Commit types.                                |
| `branch-types`       | `feature bugfix hotfix release chore`                          | Allowed Conventional Branch prefixes.                             |
| `require-scope`      | `false`                                                        | Require a scope on every commit, e.g. `feat(api):`.               |
| `max-subject-length` | `100`                                                          | Max commit subject length (`0` disables).                         |
| `protected-branches` | `main`                                                         | Branch names exempt from branch validation.                       |
| `base-ref`           | `""`                                                           | Explicit base ref for the commit range (auto-derived if empty).   |

## Use as a pre-commit hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/mrdoodles/conventional-validator
    rev: v1
    hooks:
      - id: conventional-branch
```

## What is validated

**Commits** — `<type>[optional scope][!]: <description>`, with an optional body
(blank-line separated) and `BREAKING CHANGE:` footer. Merge/revert commits are
skipped.

**Branches** — `<type>/<description>` (lowercase, digits and hyphens).

## Commit range resolution

- `pull_request` — `base.sha..head.sha` from the event payload.
- `push` — `before..after` (falls back to `HEAD` for new branches).
- Otherwise — the single `HEAD` commit, or `base-ref..HEAD` if `base-ref` is set.
