# tmux-status

Shows Claude Code status icons in your tmux window name.

| Icon | State |
|------|-------|
| ⌛️ | Thinking / processing |
| 🔴 | Tool call failed |
| ✅ | Done |

## Requirements

- tmux
- jq

## Install

1. Copy the script:

```bash
cp tmux-status.sh ~/.claude/hooks/tmux-status.sh
chmod +x ~/.claude/hooks/tmux-status.sh
```

2. Add the following hooks to your `~/.claude/settings.json` inside the `"hooks"` object:

```json
"UserPromptSubmit": [
  { "hooks": [{ "type": "command", "command": "~/.claude/hooks/tmux-status.sh" }] }
],
"PreToolUse": [
  { "hooks": [{ "type": "command", "command": "~/.claude/hooks/tmux-status.sh" }] }
],
"PostToolUse": [
  { "hooks": [{ "type": "command", "command": "~/.claude/hooks/tmux-status.sh" }] }
],
"PostToolUseFailure": [
  { "hooks": [{ "type": "command", "command": "~/.claude/hooks/tmux-status.sh" }] }
],
"Stop": [
  { "hooks": [{ "type": "command", "command": "~/.claude/hooks/tmux-status.sh" }] }
]
```

3. Restart Claude Code for hooks to take effect.
