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
- To clean up merged worktrees: `graft sync`.
- To remove a specific worktree: `graft rm <branch-name>`.

**TESTING MODE**: Always ask for confirmation before running any graft command. Show the exact command you plan to run and wait for approval.

# Plan implementation workflow

When implementing changes from a plan, always create a graft worktree first before making any edits. This ensures changes are made on an isolated branch rather than polluting the main working tree. The workflow is:

1. Create a graft worktree with the relevant project path
2. Apply all changes in the worktree
3. Commit and create the PR from the worktree

# File path references

When referencing files, always use the full absolute path starting from `/home/bento/...` (e.g. `/home/bento/carrot/src/foo/bar.rb:42`) so it can be easily looked up in Cursor.

# Shell functions

When adding or modifying shell functions, always:

1. Put them in `~/.zshrc.d/<name>.zsh` (never append directly to `~/.zshrc`)
2. Also save a copy to `~/shaun-wang-personal/setup/<name>.zsh`
3. Commit and push changes to the personal repo (`~/shaun-wang-personal`)
