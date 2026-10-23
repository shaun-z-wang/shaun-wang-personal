# ~/.zshenv on bento — makes gohan-managed tools (graft, etc.) visible to
# non-interactive/non-login zsh, e.g. `ssh bento 'graft ...'` and the maverick
# remote worker's isolated-workspace (graft) support. ~/.profile and ~/.bashrc
# only cover login/interactive shells.
# Context: https://instacart.slack.com/archives/C0C24DBBHRP/p1792782517652979 (MAV-704)
export PATH="$HOME/.config/gohan/bin:$PATH"
