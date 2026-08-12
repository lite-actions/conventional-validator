# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately via GitHub's
[private security advisories](https://github.com/lite-actions/conventional-validator/security/advisories/new)
rather than opening a public issue. You can expect an initial response within a
few days.

## Scope and design notes

This is a composite action implemented in `bash`. It reads untrusted input
(commit messages and branch names) but only uses them for pattern matching and
display — it never `eval`s or executes them.

Consuming workflows should trigger it with `pull_request` (not
`pull_request_target`) so that pull requests from forks cannot access repository
secrets. Pin the action to a released tag (e.g. `@v1`) or, for stricter supply-
chain guarantees, to a full commit SHA.
