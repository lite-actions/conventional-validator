# Contributing

Thanks for your interest in improving Conventional Validator.

## Ground rules

- **Conventional Commits** — commit messages must follow the
  [Conventional Commits](https://www.conventionalcommits.org/) spec. This repo
  validates its own PRs with the action.
- **Conventional Branch** — branch names follow the
  [Conventional Branch](https://conventional-branch.github.io/) spec, e.g.
  `feature/...`, `bugfix/...`, `chore/...`.
- **Pure shell** — the action stays dependency-free (`bash`, `git`, `jq` only).

## Local checks

```bash
# Run the test suite
bash tests/test.sh

# Lint the scripts (matches CI)
shellcheck -x --severity=warning scripts/*.sh .github/scripts/*.sh

# Optional: install the pre-commit hooks
pre-commit install
```

## Pull requests

Open a PR against `main`. CI runs conventional validation, shellcheck, and the
test suite; all must pass. A maintainer review is required before merge.

## Releases

Releases are cut via the **Release** workflow (Actions → Release → Run
workflow). It computes the next version from the Conventional Commits since the
last release, tags `vX.Y.Z`, moves the `vN` major tag, and publishes a GitHub
Release.
