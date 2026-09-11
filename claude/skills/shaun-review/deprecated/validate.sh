#!/usr/bin/env bash
#
# validate.sh — auto-detect + run lint/tests for the current change, return
# structured pass/fail JSON. No per-repo config: a headless claude subagent
# inspects the repo tooling, picks the right invocation, runs it, and reports.
# Determinism comes from the REAL command's exit code, which the subagent
# captures; the driver gates on the parsed `pass`.
#
# Usage:
#   validate.sh --scoped <base_ref> <out_json>   # per round: changed files/targets only
#   validate.sh --full   <base_ref> <out_json>   # final gate: full lint + full suite
#
# Writes JSON to <out_json>:
#   { "pass": bool, "command": "...", "failures": [{"file":"...","message":"..."}],
#     "note": "..." }
# On its own failure (detection impossible, timeout) it writes pass=false with a
# note — never silently passes.

set -uo pipefail

CLAUDE="${CLAUDE_BIN:-/home/bento/.config/gohan/bin/claude}"
JQ="${JQ_BIN:-/usr/bin/jq}"
export HOME="${HOME:-/home/bento}"
export PATH="/home/bento/.local/share/devbox/global/default/.devbox/nix/profile/default/bin:/usr/bin:/bin:$PATH"

MODE_FLAG="${1:-}"; BASE="${2:-}"; OUT="${3:-}"
case "$MODE_FLAG" in
  --scoped) SCOPE="scoped" ;;
  --full)   SCOPE="full" ;;
  *) echo "usage: $0 --scoped|--full <base_ref> <out_json>" >&2; exit 2 ;;
esac
[[ -z "$OUT" ]] && { echo "usage: $0 --scoped|--full <base_ref> <out_json>" >&2; exit 2; }

RUN_TIMEOUT="${VALIDATE_TIMEOUT:-1200}"   # seconds; hard cap on the whole detect+run
LOGDIR="$(dirname "$OUT")"
mkdir -p "$LOGDIR"
CAPTURE="$LOGDIR/$(basename "$OUT" .json).log"

CHANGED="$(git diff --name-only "$BASE"...HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")"

if [[ "$SCOPE" == "scoped" ]]; then
  SCOPE_INSTR="Run in SCOPED mode: lint + tests limited to the CHANGED files and
the test targets/packages that cover them. This must be fast enough to run every
loop round. Do NOT run the entire repo suite. If the toolchain can only run
whole packages, run just the package(s) containing changed files."
else
  SCOPE_INSTR="Run in FULL mode: the complete lint + the full test suite for this
project (or the affected service if the repo is a large monorepo where a single
global suite is impractical — in that case run the full suite of every
top-level project/service touched by the change). This is the final gate before
approval; be thorough, not fast."
fi

read -r -d '' PROMPT <<EOF
You are a validation runner for an automated code-review loop. Working directory
is a git worktree with uncommitted or recently committed changes.

Changed files (vs base ref \`$BASE\`):
$CHANGED

$SCOPE_INSTR

Steps:
1. Inspect the repo to determine the correct lint and test commands. Look for
   Makefile, BUILD/bazel, package.json scripts, Gemfile/Rakefile, go.mod,
   pyproject/tox, Cargo.toml, etc. Prefer the project's canonical invocation.
2. Actually RUN the lint and the tests with the Bash tool. Capture their real
   exit codes. Do not guess results — run them.
3. pass = true ONLY if every command you ran exited 0. Any non-zero exit => pass
   = false, and collect the failures (file + concise message) from the output.
4. If you genuinely cannot find a test command for this project, set pass=false
   and explain in "note" (do NOT report a pass you didn't verify).

Write your result as JSON to this exact path using the Write tool: $OUT
Schema (write ONLY this JSON to that file, nothing else):
{
  "pass": true,
  "command": "the exact lint/test command(s) you ran",
  "failures": [{"file": "path", "message": "what failed"}],
  "note": "detection notes, or why validation could not run"
}
After writing the file, print a one-line summary to stdout.
EOF

echo "[validate.sh] mode=$SCOPE base=$BASE out=$OUT timeout=${RUN_TIMEOUT}s" | tee "$CAPTURE"

timeout "$RUN_TIMEOUT" "$CLAUDE" -p "$PROMPT" \
  --allowedTools "Bash Read Glob Grep Write" \
  >> "$CAPTURE" 2>&1
rc=$?

if [[ $rc -eq 124 ]]; then
  "$JQ" -n --arg cap "$CAPTURE" \
    '{pass:false, command:"(none)", failures:[{file:"", message:"validation timed out"}], note:("timed out; see " + $cap)}' \
    > "$OUT"
  echo "[validate.sh] TIMEOUT after ${RUN_TIMEOUT}s" | tee -a "$CAPTURE"
  exit 0
fi

# The subagent should have written valid JSON to $OUT. If it didn't, fail closed.
if [[ ! -s "$OUT" ]] || ! "$JQ" -e . "$OUT" >/dev/null 2>&1; then
  "$JQ" -n --arg cap "$CAPTURE" \
    '{pass:false, command:"(unknown)", failures:[{file:"", message:"validation subagent produced no valid JSON"}], note:("no/invalid verdict written; see " + $cap)}' \
    > "$OUT"
  echo "[validate.sh] no valid JSON verdict; failing closed" | tee -a "$CAPTURE"
  exit 0
fi

pass="$("$JQ" -r '.pass' "$OUT")"
echo "[validate.sh] pass=$pass" | tee -a "$CAPTURE"
exit 0
