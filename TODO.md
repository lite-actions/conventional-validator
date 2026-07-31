# TODO

Deferred until **after** this action is published to the GitHub Marketplace:

- [ ] Add automated **release notes** (`RELEASE_NOTES.md`) by consuming
      `mrdoodles/release-notes`, alongside the existing changelog automation.
- [ ] Confirm the **changelog** automation stays aligned with
      `mrdoodles/versioning-tests` (this repo already runs the auto-merged-PR
      changelog flow).

Notes:

- `main` is branch-protected here, so both land via the auto-merged-PR flow
  (uses `CHANGELOG_BOT_TOKEN` + `CHANGELOG_APPROVE_TOKEN`, already configured,
  and `MrDClaudeBot` as a code owner).
