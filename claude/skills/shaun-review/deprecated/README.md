# Deprecated

Moved here 2026-09-11 when the shaun-review skill was simplified to a plain
review-and-report flow (findings list or approve; no fix loop, no lint/test
gate, no `gh pr create` stamp — the PR gate hook was removed from settings).

- `review-loop.sh` — old deterministic review⇄fix⇄validate driver (was
  `~/.claude/shaun-reviewer/review-loop.sh`)
- `validate.sh` — lint/test validation gate, only ever invoked by
  `review-loop.sh`
- `require-shaun-review.sh` — PreToolUse hook that blocked `gh pr create` in
  carrot until `.shaun-review/approved-sha` matched HEAD (was
  `~/.claude/hooks/require-shaun-review.sh`, already unregistered)

The daily learning loop (`~/.claude/shaun-reviewer/daily-refresh.sh`), which
maintains the learned standards in the `shaun-reviewer` agent md, is still
active and does not depend on any of these.
