---
name: shaun-review
description: Review the current change / draft PR as Shaun would and report a simple list of things to fix, or approve it. Pure code review — no lint, no tests, no auto-fixes; the caller handles any fixes itself. Use when asked to "shaun review", "review as Shaun", or to review a change before PR.
---

# Shaun Review

A plain code review in Shaun's style. The output is a simple list of things to
fix — or an approval if there's nothing worth fixing. The skill does NOT fix
anything, run lint, or run tests; whoever invoked it reads the findings,
decides what's worth addressing, and fixes it itself.

The review criteria (persona, severity model, learned standards) already live
in the `shaun-reviewer` agent definition (`~/.claude/agents/shaun-reviewer.md`)
— do not restate them here; delegate to that agent.

## Steps

1. **Resolve the target.** `$ARGUMENTS` may be empty, a branch, a PR
   number/URL, or a path.
   - If a path/worktree is given, `cd` there; otherwise use the current
     worktree.
   - Determine the base ref: PR base → `origin/master` → `origin/main`.
   - Confirm there is actually a diff to review
     (`git diff --stat <base>...HEAD`). If the tree is clean vs base, report
     "nothing to review" and stop.

2. **Review the diff.** Spawn the `shaun-reviewer` agent with the worktree
   path and the base ref, asking for a plain-text findings list (severity,
   `file:line`, and a one-line how-to-fix per finding) — not the verdict
   JSON. If you cannot spawn agents, apply the shaun-reviewer persona from
   its agent md directly.

3. **Report.** Relay the findings as a simple list of things to fix, most
   severe first, each with `file:line` and a one-line fix. Clearly label
   which are correctness/design issues vs style nits, but don't block on
   anything — the caller decides what to act on. If there's nothing worth
   fixing, say it's approved and stop.

## Notes

- Review only: no fixes, no commits, no lint, no tests, no GitHub posts.
- After fixing findings, the caller can re-run `/shaun-review` for a re-check.
