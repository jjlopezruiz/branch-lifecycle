#!/usr/bin/env bash
# SessionStart hook: fetch, then put the branch status line in front of both
# Claude (additionalContext) and the user (systemMessage). Warning-only:
# it never merges, pulls or pushes. Silent outside a Git repository.
set -u
INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null)
[ -z "$CWD" ] && CWD=$PWD
HERE="$(cd "$(dirname "$0")" && pwd)"
STATUS=$("$HERE/branch-status.sh" --fetch "$CWD")
[ -z "$STATUS" ] && exit 0
python3 - "$STATUS" <<'PY'
import json, sys
s = sys.argv[1]
print(json.dumps({
  "systemMessage": s,
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": s + "\n(branch-lifecycle skill: follow its Sync section if the branch is behind, conflicted or long-lived.)"
  }
}))
PY
