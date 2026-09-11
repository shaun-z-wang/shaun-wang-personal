#!/usr/bin/env bash
#
# review-loop.sh — DETERMINISTIC review<->fix<->validate<->commit driver.
#
# This script (not a model) owns the loop. The `while` is real code whose only
# exit conditions are: APPROVE + full suite green (success), no-progress
# escalation, or hitting the round cap. The PR-creating agent calls /shaun-review
# ONCE and hands off; re-review after a fix is structural here, never optional.
#
# Run from inside the target git worktree.
# Usage: review-loop.sh [base_ref]
#   base_ref defaults to the PR base, else origin/master, else origin/main.
#
# Exit codes: 0 = approved (clean), 3 = escalated / hit cap, 2 = usage error.

set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE="${CLAUDE_BIN:-/home/bento/.config/gohan/bin/claude}"
GH="${GH_BIN:-/home/bento/.local/share/devbox/global/default/.devbox/nix/profile/default/bin/gh}"
JQ="${JQ_BIN:-/usr/bin/jq}"
export HOME="${HOME:-/home/bento}"
export PATH="/home/bento/.local/share/devbox/global/default/.devbox/nix/profile/default/bin:/usr/bin:/bin:$PATH"

MAX_ROUNDS="${MAX_ROUNDS:-5}"
OUTDIR=".shaun-review"
mkdir -p "$OUTDIR"
# Make the scratch dir self-ignoring so it can never be swept into a commit.
# carrot's root .gitignore re-includes every top-level dir via `!/*/`, which
# overrides any global excludesFile / .git/info/exclude — but a .gitignore
# INSIDE the dir (ignoring `*`, itself included) still takes effect. This runs
# in every worktree, so no per-worktree setup is ever needed.
printf '*\n' > "$OUTDIR/.gitignore"

# --- resolve base ref -----------------------------------------------------
BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE="$("$GH" pr view --json baseRefName --jq '.baseRefName' 2>/dev/null || true)"
  [[ -n "$BASE" ]] && BASE="origin/$BASE"
fi
if [[ -z "$BASE" ]]; then
  for cand in origin/master origin/main master main; do
    if git rev-parse --verify "$cand" >/dev/null 2>&1; then BASE="$cand"; break; fi
  done
fi
[[ -z "$BASE" ]] && BASE="HEAD~1"
echo "[review-loop] base ref: $BASE" >&2

report() { # write final report + echo it
  printf '%s\n' "$1" > "$OUTDIR/report.md"
  printf '%s\n' "$1"
}

blocking_ids() { # verdict.json -> sorted newline-joined blocking ids
  "$JQ" -r '[.findings[]? | select(.severity=="blocker" or .severity=="important") | .id] | sort | .[]' "$1" 2>/dev/null
}
val_failure_ids() { # validate.json -> sorted signatures of failures
  "$JQ" -r '[.failures[]? | "validate:" + (.file // "") + ":" + ((.message // "")[0:80])] | sort | .[]' "$1" 2>/dev/null
}

round=0
prev_blockers=""
commits_made=0

while (( round < MAX_ROUNDS )); do
  round=$((round + 1))
  echo "[review-loop] === round $round ===" >&2
  verdict_file="$OUTDIR/verdict-round${round}.json"
  prev_scoped="$OUTDIR/validate-round$((round - 1)).json"

  # --- REVIEW ---
  fold_line=""
  [[ -f "$prev_scoped" ]] && fold_line="Also read $prev_scoped (scoped validation from the previous fix) and turn any failures into blocker findings."

  review_prompt="Review the current change in this worktree as Shaun.
Base ref: $BASE. Get the diff with: git diff ${BASE}...HEAD
Read surrounding files as needed for context. This is round $round.
$fold_line
If .shaun-review/declined.json exists, respect recorded rationales (only re-raise a declined item if you can directly rebut its rationale).
Write your verdict JSON to exactly this path: $verdict_file
Follow your output contract precisely."

  "$CLAUDE" -p "$review_prompt" --agent shaun-reviewer \
    --allowedTools "Read Glob Grep Bash Write" \
    > "$OUTDIR/reviewer-round${round}.log" 2>&1

  if [[ ! -s "$verdict_file" ]] || ! "$JQ" -e . "$verdict_file" >/dev/null 2>&1; then
    report "shaun-review: ESCALATE — reviewer produced no valid verdict in round $round (see $OUTDIR/reviewer-round${round}.log). Commits made: $commits_made."
    exit 3
  fi

  verdict="$("$JQ" -r '.verdict' "$verdict_file")"
  blockers="$(blocking_ids "$verdict_file")"
  echo "[review-loop] verdict=$verdict blocking=$(echo -n "$blockers" | grep -c . || true)" >&2

  # --- APPROVE path: gate on FULL suite ---
  if [[ "$verdict" == "APPROVE" ]]; then
    echo "[review-loop] reviewer APPROVED; running full validation gate" >&2
    "$SELF_DIR/validate.sh" --full "$BASE" "$OUTDIR/validate-final.json"
    if [[ "$("$JQ" -r '.pass' "$OUTDIR/validate-final.json" 2>/dev/null)" == "true" ]]; then
      # Stamp the exact reviewed+green commit so the gh-pr-create gate hook can
      # confirm this PR passed review at THIS HEAD (not a stale earlier run).
      git rev-parse HEAD > "$OUTDIR/approved-sha" 2>/dev/null || true
      nits="$("$JQ" -r '[.findings[]? | select(.severity=="nit") | "- " + (.file // "") + ": " + .title] | .[]' "$verdict_file" 2>/dev/null)"
      summary="$("$JQ" -r '.summary // "looks good"' "$verdict_file")"
      report "shaun-review: LGTM ✅ (round $round). $summary
Full suite: green. Commits made this loop: $commits_made.
Non-blocking nits:
${nits:-  (none)}"
      exit 0
    fi
    echo "[review-loop] reviewer APPROVED but full suite is RED — failures become blockers" >&2
    blockers="$(val_failure_ids "$OUTDIR/validate-final.json")"
  fi

  # --- convergence guard: nothing changed since last round => stuck ---
  if [[ -n "$blockers" && "$blockers" == "$prev_blockers" ]]; then
    report "shaun-review: ESCALATE — no progress in round $round; the same blockers persist (disagreement or unfixable). Commits made: $commits_made.
Open blockers:
$blockers
See $verdict_file / $OUTDIR/validate-final.json."
    exit 3
  fi
  prev_blockers="$blockers"

  # --- FIX ---
  blocking_json="$("$JQ" -c '[.findings[]? | select(.severity=="blocker" or .severity=="important")]' "$verdict_file" 2>/dev/null)"
  [[ -z "$blocking_json" || "$blocking_json" == "null" ]] && blocking_json="[]"
  extra_val=""
  [[ -f "$OUTDIR/validate-final.json" ]] && extra_val="Also fix the validation failures in $OUTDIR/validate-final.json (full-suite gate is red)."

  fix_prompt="You are fixing code to address review blockers from Shaun's reviewer. This is round $round.
Blocking findings (JSON): $blocking_json
$extra_val
For each finding, make the minimal correct code change that resolves it. Read the referenced files first.
Do NOT weaken, delete, or skip tests to make them pass — fix the underlying code.
If you genuinely disagree with a finding and choose not to fix it, append an entry to $OUTDIR/declined.json (a JSON array of {id, rationale}) explaining why; the reviewer must rebut that rationale to re-raise it.
Make the edits now."

  "$CLAUDE" -p "$fix_prompt" \
    --allowedTools "Read Edit Write Glob Grep Bash" \
    > "$OUTDIR/fixer-round${round}.log" 2>&1

  # --- per-round SCOPED validation ---
  "$SELF_DIR/validate.sh" --scoped "$BASE" "$OUTDIR/validate-round${round}.json"

  # --- commit this round ---
  git add -A
  if ! git diff --cached --quiet; then
    git commit -q -m "shaun-review: address round $round" \
      && commits_made=$((commits_made + 1)) \
      && echo "[review-loop] committed round $round" >&2
  else
    echo "[review-loop] round $round produced no code changes" >&2
  fi
done

# --- hard cap ---
report "shaun-review: ESCALATE — hit MAX_ROUNDS ($MAX_ROUNDS) with open blockers/failures. Commits made: $commits_made.
Last open blockers:
${prev_blockers:-(see latest verdict)}
Latest verdict: $OUTDIR/verdict-round${round}.json"
exit 3
