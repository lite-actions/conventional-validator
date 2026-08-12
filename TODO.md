# TODO

Deferred until **after** this action is published to the GitHub Marketplace:

- [ ] Add automated **release notes** (`RELEASE_NOTES.md`) by consuming
      `lite-actions/release-notes`, alongside the existing changelog automation.
- [ ] Confirm the **changelog** automation stays aligned with
      `lite-actions/versioning-tests` (this repo already runs the auto-merged-PR
      changelog flow).
- [ ] Repoint the workflow `uses:` refs from `mrdoodles/*` to `lite-actions/*`
      once those actions are published under the org: `release.yml:41`
      (`release-notes`), `changelog.yml:36` (`conventional-changelog`) and
      `changelog.yml:41` (`release-notes`). Both repos have already been
      transferred, so the old paths resolve **only** via GitHub's rename
      redirect — that stops applying if anything is ever created at the old
      `mrdoodles/*` path, which would silently resolve to a different repo.

Notes:

- `main` is branch-protected here, so both land via the auto-merged-PR flow
  (uses `CHANGELOG_BOT_TOKEN` + `CHANGELOG_APPROVE_TOKEN`, already configured,
  and `MrDClaudeBot` as a code owner).
