---
name: shaun-review
description: Run the automated Shaun-persona review⇄fix⇄validate loop on a draft PR / current branch. Invoked by /shaun-review, typically by the agent that just created a PR, to review the change as Shaun would, auto-fix real blockers, enforce lint/tests, and either approve cleanly or escalate. Use when asked to "shaun review", "review as Shaun", or to run the review loop on a change.
---

# Shaun Review

Runs the **deterministic** review loop (`review-loop.sh`). The driver script — not
you — owns the review⇄fix⇄re-review loop, so re-review after a fix is guaranteed.
Your job is only to resolve the target and launch the driver, then surface its
final report.

## What the loop does (context)

- Reviews the diff with the `shaun-reviewer` persona (default verdict = APPROVE;
  blocks only on concrete correctness/design problems or violations of Shaun's
  learned standards; style issues are non-blocking nits).
- On REQUEST_CHANGES: a fixer addresses the blockers, scoped lint+tests run, and
  the round is committed (`shaun-review: address round <k>`).
- On APPROVE: the **full** lint+test suite runs as a final gate. Only if it is
  green does the loop stop with "LGTM". If it's red, the failures become blockers
  and the loop continues — it never ships red tests.
- Terminates on: clean approval, no-progress escalation, or the round cap.
- Feedback stays local (worktree files under `.shaun-review/` + verdict JSON). It
  posts NO GitHub comments.

## Steps

1. **Resolve the target.** `$ARGUMENTS` may be empty, a branch, a PR number/URL,
   or a path.
   - Determine the working directory: if a path/worktree is given, `cd` there;
     otherwise use the current worktree.
   - The driver auto-resolves the base ref (PR base → `origin/master` →
     `origin/main`). You normally do not need to pass one. If the user named a
     specific base, pass it as the first arg.
   - Confirm there is actually a diff to review
     (`git diff --stat <base>...HEAD`). If the tree is clean vs base, report
     "nothing to review" and stop.

2. **Launch the driver** from the worktree root:
   ```bash
   /home/bento/.claude/shaun-reviewer/review-loop.sh [base_ref]
   ```
   Let it run to completion. It prints a final report and writes
   `.shaun-review/report.md`. Exit codes: `0` approved, `3` escalated / hit cap.

3. **Surface the result.** Relay the driver's final report to the user verbatim-ish:
   - **Approved (exit 0):** state "LGTM", how many rounds, commits made, and list
     any non-blocking nits.
   - **Escalated / hit cap (exit 3):** state why it stopped (no-progress vs cap),
     the remaining open blockers, commits made so far, and point at
     `.shaun-review/verdict-round<k>.json` and the reviewer/fixer logs so the
     human can take over.

## Notes

- Each round is its own commit, so the human can inspect or drop rounds.
- Never post to GitHub; all feedback is local by design.
- If `review-loop.sh` can't find a test command, the validation gate reports that
  (it does not silently pass) — surface it.
