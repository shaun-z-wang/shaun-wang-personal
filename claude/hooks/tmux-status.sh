#!/bin/bash
if [ -n "$TMUX" ]; then
  event=$(cat | jq -r '.hook_event_name // empty' 2>/dev/null)
  current_name=$(tmux display-message -p -t "$TMUX_PANE" '#W')
  base_name=$(echo "$current_name" | sed 's/ *[^a-zA-Z0-9_-]*$//')

  case "$event" in
    UserPromptSubmit)   icon="⌛️" ;;
    PreToolUse)         icon="⌛️" ;;
    PostToolUse)        icon="⌛️" ;;
    PostToolUseFailure) icon="🔴" ;;
    Notification)
      # Don't override ✅ — notification can fire after Stop
      case "$current_name" in *✅) exit 0 ;; esac
      icon="🔒" ;;
    Stop)               icon="✅" ;;
    *) exit 0 ;;
  esac

  tmux rename-window -t "$TMUX_PANE" "${base_name} ${icon}"

  # Ring terminal bell on stop and permission request
  case "$event" in
    Stop) printf '\a' ;;
  esac
fi
