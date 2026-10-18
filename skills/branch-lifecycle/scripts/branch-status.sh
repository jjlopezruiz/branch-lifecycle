#!/usr/bin/env bash
# branch-status.sh — one honest line about where this branch stands.
#
# Usage: branch-status.sh [--fetch] [--json] [path]
#   --fetch   refresh origin first (8 s cap, never prompts for credentials)
#   --json    machine-readable output instead of the one-liner
#
# Read-only. It never merges, pulls, pushes or touches the working tree.
# Base branch: `git config branch-lifecycle.base` if set, else `develop` if
# origin has one, else origin's default branch, else main/master.

set -u

FETCH=0 JSON=0 DIR="."
for arg in "$@"; do
  case "$arg" in
    --fetch) FETCH=1 ;;
    --json)  JSON=1 ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) DIR="$arg" ;;
  esac
done

cd "$DIR" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0   # not a repo: say nothing

g() { git "$@" 2>/dev/null; }

HAS_ORIGIN=0
g remote get-url origin >/dev/null && HAS_ORIGIN=1

FETCHED="no"
if [ "$FETCH" = 1 ] && [ "$HAS_ORIGIN" = 1 ]; then
  # macOS has no `timeout`; perl's alarm is everywhere git is.
  if GIT_TERMINAL_PROMPT=0 perl -e 'alarm shift; exec @ARGV' 8 git fetch --quiet --prune origin 2>/dev/null; then
    FETCHED="yes"
  else
    FETCHED="failed"
  fi
fi

BRANCH=$(g branch --show-current)
[ -z "$BRANCH" ] && BRANCH="(detached)"

# --- base branch -----------------------------------------------------------
BASE=$(g config --get branch-lifecycle.base)
if [ -z "$BASE" ]; then
  if g show-ref --verify --quiet refs/remotes/origin/develop; then
    BASE=develop
  else
    BASE=$(g symbolic-ref --quiet --short refs/remotes/origin/HEAD | sed 's#^origin/##')
  fi
fi
if [ -z "$BASE" ]; then
  for b in main master; do
    if g show-ref --verify --quiet "refs/heads/$b" || g show-ref --verify --quiet "refs/remotes/origin/$b"; then BASE=$b; break; fi
  done
fi
BASE_REF="origin/$BASE"
g rev-parse --verify --quiet "$BASE_REF" >/dev/null || BASE_REF="$BASE"

# --- counts ----------------------------------------------------------------
BEHIND="" AHEAD="" AGE_DAYS=""
if [ -n "$BASE" ] && [ "$BRANCH" != "$BASE" ] && g rev-parse --verify --quiet "$BASE_REF" >/dev/null; then
  read -r BEHIND AHEAD <<<"$(g rev-list --left-right --count "$BASE_REF...HEAD")"
  FIRST=$(g log --reverse --format=%ct "$BASE_REF..HEAD" | head -1)
  [ -n "$FIRST" ] && AGE_DAYS=$(( ( $(date +%s) - FIRST ) / 86400 ))
fi

UPSTREAM=$(g rev-parse --abbrev-ref --symbolic-full-name '@{u}')
UNPUSHED=""
if [ -n "$UPSTREAM" ]; then
  UNPUSHED=$(g rev-list --count '@{u}..HEAD')
elif [ "$BRANCH" != "(detached)" ]; then
  UNPUSHED="unpublished"
fi

DIRTY=$(g status --porcelain | wc -l | tr -d ' ')
STASHES=$(g stash list | wc -l | tr -d ' ')
WORKTREES=$(g worktree list --porcelain | grep -c '^worktree ')
CONFLICTS=$(g diff --name-only --diff-filter=U | wc -l | tr -d ' ')

# --- output ----------------------------------------------------------------
if [ "$JSON" = 1 ]; then
  printf '{"branch":"%s","base":"%s","behind":"%s","ahead":"%s","age_days":"%s","upstream":"%s","unpushed":"%s","dirty":%s,"stashes":%s,"worktrees":%s,"conflicts":%s,"fetched":"%s"}\n' \
    "$BRANCH" "$BASE" "$BEHIND" "$AHEAD" "$AGE_DAYS" "$UPSTREAM" "$UNPUSHED" "$DIRTY" "$STASHES" "$WORKTREES" "$CONFLICTS" "$FETCHED"
  exit 0
fi

parts=("branch $BRANCH")
if [ "$BRANCH" = "$BASE" ]; then
  parts+=("you are ON the base branch — branch off before changing anything")
elif [ -n "$BEHIND" ]; then
  parts+=("$BEHIND behind / $AHEAD ahead of $BASE_REF")
  [ -n "$AGE_DAYS" ] && parts+=("open ${AGE_DAYS}d")
fi
case "$UNPUSHED" in
  ""|0) ;;
  unpublished) parts+=("never pushed") ;;
  *) parts+=("$UNPUSHED unpushed") ;;
esac
[ "$DIRTY" != 0 ] && parts+=("$DIRTY uncommitted")
[ "$CONFLICTS" != 0 ] && parts+=("$CONFLICTS UNRESOLVED CONFLICTS")
[ "$STASHES" != 0 ] && parts+=("$STASHES stash")
[ "$WORKTREES" -gt 1 ] && parts+=("$WORKTREES worktrees")
[ "$FETCHED" = failed ] && parts+=("fetch failed — counts may be stale")
[ "$FETCHED" = no ] && [ "$HAS_ORIGIN" = 1 ] && parts+=("not fetched")

line=$(IFS='|'; echo "${parts[*]}" | sed 's/|/ · /g')

# Advice: one line, only when something needs doing.
advice=""
if [ "$CONFLICTS" != 0 ]; then
  advice="resolve the conflicts, then build before committing"
elif [ -n "$BEHIND" ] && [ "$BEHIND" != 0 ]; then
  advice="bring $BASE into this branch before resolving or opening a PR"
elif [ -n "$AGE_DAYS" ] && [ "$AGE_DAYS" -ge 3 ]; then
  advice="long-lived branch: merge $BASE down now, and aim to land it"
fi

echo "git: $line"
[ -n "$advice" ] && echo "next: $advice"
exit 0
