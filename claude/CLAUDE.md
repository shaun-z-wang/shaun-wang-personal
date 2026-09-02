# Use graft for branching

When creating a branch for code changes in the carrot monorepo, use graft instead of raw git commands:

```bash
graft new <branch-name> <project-path> --edit --sparse
```

- **IMPORTANT**: `/home/bento` is NOT a git repo. Always run graft from anywhere — it uses registered repos (default: `carrot` at `/home/bento/carrot`).
- Project path should NOT have a leading slash (e.g. `customers/customers-backend/domains/foo`, not `/customers/...`).
- Do NOT use `git checkout -b` or `git branch`. Graft creates an isolated worktree and opens a new editor window.
- `--from origin/master` is the default. Use `--from <branch>` to base off a different branch.
- If you need additional directories mid-task, run `graft add-dir /<path>` to expand the sparse checkout.
- If the build breaks after pulling latest from master in a worktree (likely missing sparse dependencies), try `graft refresh` first before reaching for `graft add-dir`. Refresh re-resolves the sparse cone and usually fixes it.
- To clean up merged worktrees: `graft sync`.
- To remove a specific worktree: `graft rm <branch-name>`.

**Confirmation rule**: Run graft commands freely without asking. The inverse applies: if you are about to make code changes and you are NOT in a graft worktree (cwd not under `.claude/worktrees/`), stop and ask for confirmation before editing. Show what you intend to change and wait for approval (or for the user to tell you to graft first).

# Check for existing worktree before creating one

When the user shares a PR, first check whether a worktree for that branch already exists before creating a new one. Run `graft list` (or `git worktree list` within the carrot repo) to find an existing worktree matching the PR's branch. If one exists, use it (enter it / `graft cd` into it) instead of creating a new one. Only create a new worktree with `graft new` when no matching worktree exists.

# Plan implementation workflow

When implementing changes from a plan, always create a graft worktree first before making any edits. This ensures changes are made on an isolated branch rather than polluting the main working tree. The workflow is:

1. Create a graft worktree with the relevant project path
2. Apply all changes in the worktree
3. Commit and create the PR from the worktree

# Link stacked PRs on GitHub with gh stack

When creating a traditional stacked PR (graft branch off the parent + `gh pr create --base <parent-branch> --draft`), ALSO register it into a GitHub-native stack with the `github/gh-stack` extension (already installed; docs: https://gh.io/stacks).

- `gh stack link <bottom> <top> [<more> ...]` — args in stack order, BOTTOM (closest to master) to TOP. Each arg is a branch name, PR number, or PR URL. e.g. `gh stack link 845779 848083` stacks #848083 on top of #845779.
- `link` creates the stack if none exists, or updates an existing one; existing PRs are NEVER removed. Shortcut: pass an existing stack NUMBER (from the GitHub stack UI) as the first arg to append PRs to its top without re-listing.
- Prefer `gh stack link` — it's metadata-only and needs no local tracking (ideal since graft manages branches). Avoid `gh stack checkout`/`view`; they can be slow or hang in this environment.
- To undo: `gh stack unstack <stack-number>` removes the whole stack on GitHub (metadata only; PRs/branches untouched), `--local` removes only local tracking. `link` can't remove a single PR — `unstack` then re-`link`.
- Gotcha: once a PR is in a stack, `gh pr edit <n> --base <branch>` is REJECTED ("Cannot change the base branch because the pull request is part of a stack") — `gh stack unstack` first to retarget.

# PR description format (keep it short)

My PR descriptions are short. Claude's default is far too long and I always have to trim it before requesting review. Write the description the way I would, matching these merged examples: #848717, #846337, #843586, #843350.

**Structure**: A single `## Summary` section. That's it. No `## Changes`, no `## Testing`, no `## Notes`, no file-by-file breakdown. The diff already shows what changed — the description explains *why*.

**Length**: 2-5 sentences (a short paragraph or two). If it's running longer than that, cut it.

**Voice**: First person and conversational, e.g. "When I was doing testing I ran into...", "While I'm adding integration tests I needed...". Explain the context/motivation and the gist of the change, not a mechanical list.

**Closing (optional)**: When there's a judgment call, uncertainty, or a decision reviewers should weigh in on, end with a soft note like "Let me know if you have any concerns" or a specific question. Don't add it just to have one.

**Do NOT**:
- Enumerate every changed file or list each test/command run.
- Add a `## Testing` section — I'll mention testing inline in the summary only if it's relevant to the reasoning.
- Include the "🤖 Generated with Claude Code" footer in the PR body.

Exception: for a stacked PR that's part of a numbered series (e.g. T1/T2/T3), a terse bullet list of the key changes is fine (see #853359) — but still keep it tight.

# Keep PR description in sync

Every time you push a change to a PR, review the PR description and update it if it no longer accurately reflects the code being shipped. Do not leave the description stale after adding, removing, or altering commits.

# Always name spawned agents

Whenever you spawn an agent, ALWAYS give it a name (via the `name` parameter) so it can be addressed later with SendMessage if needed.

# File path references

When referencing files, always use the full absolute path starting from `/home/bento/...` (e.g. `/home/bento/carrot/src/foo/bar.rb:42`) so it can be easily looked up in Cursor.

# Column & metadata verification (MANDATORY)

Every time you modify an existing SQL query or write a new one, you MUST first use the Portal MCP (`portal-mcp-v2`, e.g. `describe_table`) to verify the columns available on each referenced table and read their annotations/descriptions before proceeding with the change. Do not reference a column until its existence and meaning are confirmed via Portal MCP. This applies in the main session and all subagents.

# Ask, don't assume

When something in a request is ambiguous, underspecified, or could reasonably be interpreted multiple ways, ask me for clarification before proceeding. Do not guess at intent, invent missing details, or pick a direction silently. A short clarifying question is always preferable to going down the wrong path.

# Clarifying before acting

Before committing to an approach or taking action:

- Check for ambiguity, missing decisions, or assumptions that could materially affect the result or make rework costly.
- First resolve what you can from the request, available context, and relevant read-only inspection. Do not ask for information you can determine yourself.
- Ask only about material issues that lack a safe, reasonable, reversible default. Treat everything else as non-blocking.
- Ask the fewest questions needed. For genuine choices, offer a small set of concrete options with brief trade-offs and a recommendation when useful. If fixed options would be artificial, ask a focused open question.
- Batch independent questions. Ask dependent questions one at a time only when an earlier answer changes what should be asked next.
- If nothing material is blocking, briefly state only consequential assumptions and proceed without seeking confirmation. Do not restate the request.

# 5 whys

When investigating (e.g. a bug) or critically evaluating (e.g. a plan or code), apply the 5 whys to reach the root cause rather than stopping at the first plausible explanation.

# Comments

Never add any comments in the code unless it's following existing patterns in the surrounding code.

# Shell functions

When adding or modifying shell functions, always:

1. Put them in `~/.zshrc.d/<name>.zsh` (never append directly to `~/.zshrc`)
2. Also save a copy to `~/shaun-wang-personal/setup/<name>.zsh`
3. Commit and push changes to the personal repo (`~/shaun-wang-personal`)
