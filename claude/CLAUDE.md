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

# Plan implementation workflow

When implementing changes from a plan, always create a graft worktree first before making any edits. This ensures changes are made on an isolated branch rather than polluting the main working tree. The workflow is:

1. Create a graft worktree with the relevant project path
2. Apply all changes in the worktree
3. Commit and create the PR from the worktree

# File path references

When referencing files, always use the full absolute path starting from `/home/bento/...` (e.g. `/home/bento/carrot/src/foo/bar.rb:42`) so it can be easily looked up in Cursor.

# Ask, don't assume

When something in a request is ambiguous, underspecified, or could reasonably be interpreted multiple ways, ask me for clarification before proceeding. Do not guess at intent, invent missing details, or pick a direction silently. A short clarifying question is always preferable to going down the wrong path.

# Shell functions

When adding or modifying shell functions, always:

1. Put them in `~/.zshrc.d/<name>.zsh` (never append directly to `~/.zshrc`)
2. Also save a copy to `~/shaun-wang-personal/setup/<name>.zsh`
3. Commit and push changes to the personal repo (`~/shaun-wang-personal`)
