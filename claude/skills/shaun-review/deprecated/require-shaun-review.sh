#!/usr/bin/env bash
#
# require-shaun-review.sh — PreToolUse(Bash) gate.
#
# Blocks `gh pr create` in the instacart/carrot repo unless the current change
# has passed the Shaun review loop AT THE CURRENT HEAD. The review loop
# (~/.claude/shaun-reviewer/review-loop.sh) writes .shaun-review/approved-sha
# with the reviewed+green commit on a clean LGTM; this hook allows the PR only
# when that stamp equals the worktree's current HEAD.
#
# Rationale: a CLAUDE.md rule is probabilistic (a session can skip it); this
# hook fires deterministically on every gh-pr-create, so review can't be
# forgotten. Scoped to carrot so it never interferes with other repos.
#
# Output: legacy PreToolUse block format {"decision":"block","reason":...},
# matching the other hooks in this settings.json. Exit 0 (allow) otherwise.

set -uo pipefail

JQ="${JQ_BIN:-/usr/bin/jq}"
command -v "$JQ" >/dev/null 2>&1 || JQ="jq"

input="$(cat)"
cmd="$(printf '%s' "$input" | "$JQ" -r '.tool_input.command // empty' 2>/dev/null)"
cwd="$(printf '%s'  "$input" | "$JQ" -r '.cwd // empty' 2>/dev/null)"

# Only guard actual `gh pr create` invocations (flags between gh and pr allowed).
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])gh[[:space:]].*pr[[:space:]]+create([[:space:]]|$)' || exit 0

[[ -n "$cwd" ]] && cd "$cwd" 2>/dev/null

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[[ -z "$root" ]] && exit 0

# Enforce only in the carrot repo.
remote="$(git -C "$root" config --get remote.origin.url 2>/dev/null || true)"
printf '%s' "$remote" | grep -q 'instacart/carrot' || exit 0

# Determine the PR's target branch from --head, or from the session worktree.
branch=""
read -r -a command_args <<< "$cmd"
previous=""
for arg in "${command_args[@]}"; do
  if [[ "$previous" == "--head" ]]; then
    branch="$arg"
    break
  fi
  case "$arg" in
    --head=*)
      branch="${arg#--head=}"
      break
      ;;
  esac
  previous="$arg"
done
[[ "$branch" == *:* ]] && branch="${branch#*:}"
[[ "$branch" == refs/heads/* ]] && branch="${branch#refs/heads/}"

if [[ -z "$branch" ]]; then
  branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"
fi

head="$(git -C "$root" rev-parse "$branch" 2>/dev/null || true)"

# Find the approval stamp in the worktree for the PR branch or HEAD.
approved=""
approval_match=0
wt=""
wt_branch=""
wt_head=""

consider_worktree() {
  [[ -z "$wt" ]] && return 0
  if { [[ -n "$branch" && "$wt_branch" == "refs/heads/$branch" ]] ||
       [[ -n "$head" && "$wt_head" == "$head" ]]; }; then
    stamp="$(cat "$wt/.shaun-review/approved-sha" 2>/dev/null || true)"
    if [[ -n "$stamp" ]]; then
      [[ -z "$approved" || "$stamp" == "$head" ]] && approved="$stamp"
      [[ "$stamp" == "$head" ]] && approval_match=1
    fi
  fi
}

while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      consider_worktree
      wt="${line#worktree }"
      wt_branch=""
      wt_head=""
      ;;
    HEAD\ *) wt_head="${line#HEAD }" ;;
    branch\ *) wt_branch="${line#branch }" ;;
  esac
done < <(git -C "$root" worktree list --porcelain 2>/dev/null)
consider_worktree

# Fall back to the session worktree's stamp for the original happy path.
stamp="$(cat "$root/.shaun-review/approved-sha" 2>/dev/null || true)"
if [[ -n "$stamp" ]]; then
  [[ -z "$approved" || "$stamp" == "$head" ]] && approved="$stamp"
  [[ "$stamp" == "$head" ]] && approval_match=1
fi

# Reviewed at exactly this commit -> allow.
[[ -n "$head" && "$approval_match" == 1 ]] && exit 0

reason="Blocked: this change has not passed shaun-review at the current commit.
  current HEAD:  ${head:-<unknown>}
  approved SHA:  ${approved:-<none on file>}

Run the Shaun review loop first, then retry:
  /shaun-review

It reviews the diff, applies fixes, runs the full validation gate, and on a
clean LGTM writes .shaun-review/approved-sha for this HEAD. Once that stamp
matches HEAD, gh pr create is allowed. (This gate only applies to instacart/carrot.)"

"$JQ" -cn --arg r "$reason" '{decision:"block", reason:$r}'
exit 0
