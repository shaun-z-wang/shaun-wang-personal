---
name: save-config
description: Sync local config files (tmux, zsh, Claude settings/hooks/skills) to ~/shaun-wang-personal repo. Use when the user says /save-config or asks to back up, sync, or save their configs to the personal repo.
---

# Save Config

Detect changes in local config files and sync them to `~/shaun-wang-personal`, then commit and push.

## Files to sync

| Source | Destination | Notes |
|--------|-------------|-------|
| `~/.tmux.conf` | `~/shaun-wang-personal/setup/tmux.conf` | Full tmux config |
| `~/.zshrc.d/ccd.zsh` | `~/shaun-wang-personal/setup/ccd.zsh` | Directory shortcuts |
| `~/.zshrc.d/rename.zsh` | `~/shaun-wang-personal/setup/rename.zsh` | Tmux rename helper |
| `~/.claude/settings.json` | `~/shaun-wang-personal/claude/settings.json` | Claude Code user settings |
| `~/.claude/CLAUDE.md` | `~/shaun-wang-personal/claude/CLAUDE.md` | User-level CLAUDE.md |
| `~/.claude/hooks/tmux-status.sh` | `~/shaun-wang-personal/claude/hooks/tmux-status.sh` | tmux-status hook |
| `~/.claude/hooks/tmux-status/` | `~/shaun-wang-personal/claude/hooks/tmux-status/` | tmux-status hook directory |
| `~/.claude/skills/*/SKILL.md` | `~/shaun-wang-personal/claude/skills/<name>/SKILL.md` | All skill definitions |

## Excluded files (do NOT sync)

- `~/.zshrc.d/claude.zsh` — only contains aliases, not worth tracking
- `~/.zshrc.d/user.zsh` — contains API keys/secrets
- `~/.claude/hooks/fix-ssh-auth-sock.sh` — machine-specific
- `~/.claude/settings.local.json` — machine-specific overrides
- `~/.claude/projects/` — conversation data
- `~/.claude/memory/` — memory data

## Workflow

### Step 1: Detect changes

For each source/destination pair above:
1. Check if the source file exists
2. Run `diff` between source and destination
3. Collect all files that differ or are missing from the destination

If nothing has changed, tell the user everything is already in sync and stop.

### Step 1.5: Secrets scan

For every file that has changes (new or modified), scan its content for potential secrets:
- Grep for patterns: `TOKEN`, `SECRET`, `KEY`, `PASSWORD`, `BEARER`, `api_key`, `auth`, `credential`, URLs with embedded credentials, long base64-like strings (40+ chars of alphanumeric)
- Use case-insensitive matching
- If any file contains a likely secret, **exclude it from the sync** and warn the user: show the file name, the matching line (redacted), and why it was excluded
- Do NOT silently skip — always tell the user which files were excluded and why

### Step 2: Show summary and wait for confirmation

Display a table of what will be updated:

```
Files to sync:
  [changed] ~/.tmux.conf -> setup/tmux.conf
  [new]     skills/save-config/SKILL.md
  ...
```

**STOP here and ask the user to confirm before proceeding.** Do not copy, commit, or push until the user explicitly approves.

### Step 3: Copy files

Only after user confirmation, copy each changed/new file from source to destination using `cp`. For directories (like `hooks/tmux-status/`), use `cp -r`. For skills, mirror the directory structure: create `~/shaun-wang-personal/claude/skills/<skill-name>/SKILL.md` for each skill.

### Step 4: Commit and push

```bash
cd ~/shaun-wang-personal
git add setup/ claude/
git status  # show what's staged
git commit -m "Sync local configs: <brief list of what changed>"
git push
```

Use a descriptive commit message that lists which configs were updated (e.g., "Sync local configs: tmux.conf, settings.json, 5 skills").

### Step 5: Confirm

Tell the user what was synced and that it's been pushed.

## Important

- If a file exists in the personal repo but NOT locally, warn the user (it may have been intentionally deleted) — do not auto-delete
- When new `.zsh` files appear in `~/.zshrc.d/` that aren't in the excluded list, ask the user if they should be added to the sync list
