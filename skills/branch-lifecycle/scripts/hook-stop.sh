#!/usr/bin/env bash
# Stop hook: if this repo has commits that were never pushed, or a branch that
# was never published, show one warning line to the user. Never blocks
# (always exit 0), never pushes. Silent when there is nothing to say, and says
# it once per session per HEAD, so it does not repeat after every answer.
set -u
INPUT=$(cat)
read -r CWD ACTIVE SID <<<"$(printf '%s' "$INPUT" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("cwd") or ".", str(d.get("stop_hook_active", False)).lower(), d.get("session_id") or "nosession")' 2>/dev/null)"
[ "${ACTIVE:-false}" = "true" ] && exit 0
cd "${CWD:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
BRANCH=$(git branch --show-current 2>/dev/null); [ -z "$BRANCH" ] && exit 0
msg=""
if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  n=$(git rev-list --count '@{u}..HEAD' 2>/dev/null)
  [ "${n:-0}" -gt 0 ] && msg="$n commit(s) on $BRANCH not pushed — they exist only on this machine"
elif git remote get-url origin >/dev/null 2>&1 && [ "$(git rev-list --count HEAD 2>/dev/null)" -gt 0 ]; then
  base=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  if [ -z "$base" ] || [ "$(git rev-list --count "$base..HEAD" 2>/dev/null)" -gt 0 ]; then
    msg="branch $BRANCH has never been pushed"
  fi
fi
[ -z "$msg" ] && exit 0
STAMP="${TMPDIR:-/tmp}/branch-lifecycle-${SID}-$(git rev-parse --short HEAD 2>/dev/null)"
[ -e "$STAMP" ] && exit 0
: > "$STAMP" 2>/dev/null
python3 -c 'import json,sys; print(json.dumps({"systemMessage": "git: " + sys.argv[1]}))' "$msg"
exit 0
