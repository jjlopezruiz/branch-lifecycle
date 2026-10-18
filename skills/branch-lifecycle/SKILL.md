---
name: branch-lifecycle
description: Run the whole life of a Git branch when several people or several AI agents work on one repository in parallel — start isolated, stay aligned with the base branch, resolve conflicts in the right order, and close with push, pull request and cleanup. Use at the start of any change in a repo ("start a branch", "work on X", "spin up an agent for Y"), when a push is rejected or conflicts keep coming back, when a pull is refused, when the editor's Git panel looks wrong, before opening a pull request, and when work is done ("finish", "close the branch", "ship it", "open the PR"). Also use when the session-start status line says the branch is behind, long-lived, unpushed or conflicted.
license: MIT
---

# Branch lifecycle

One rule sits under everything here:

> **You cannot resolve a conflict until your branch is aligned with the branch you want to merge
> into.** Bring the base down first, resolve on your own branch, prove it builds, then push.

Everything in Git can be undone except a carelessly resolved conflict. Spend the care there.

**Announce at start:** "Using branch-lifecycle: <start | sync | finish>."

Three moments. Identify which one you are in, then follow only that section.

| You are… | Go to |
|---|---|
| about to change anything | **1. Start** |
| mid-work, behind the base, conflicted, refused, or confused by the panel | **2. Sync** |
| done, or asked to push / open a PR / close the branch | **3. Finish** |

---

## 0. Read the state first, every time

```bash
"<skill-dir>/scripts/branch-status.sh" --fetch
```

It prints one line (`branch · N behind / M ahead of origin/<base> · open Xd · unpushed ·
uncommitted · conflicts · worktrees`) and, when something needs doing, a `next:` line. It is
read-only. **Trust it over the editor's Git sidebar**, which shows a cached picture and can show
the wrong branch.

**The base branch** is resolved in this order: `git config branch-lifecycle.base` → `develop` if
`origin/develop` exists → origin's default branch → `main`/`master`. If the repo uses something
else, set it once: `git config branch-lifecycle.base <name>`. If the work clearly forked from a
different branch than the detected one, ask before merging into anything: a merge into the wrong
base is expensive to undo.

---

## 1. Start

1. **Never work on the base branch.** If the status line says you are on it, branch off before
   the first edit.
2. **Already isolated?** Check before creating anything:
   ```bash
   [ "$(git rev-parse --git-dir)" != "$(git rev-parse --git-common-dir)" ] && echo "linked worktree"
   ```
   (`git rev-parse --show-superproject-working-tree` returning a path means a submodule, not a
   worktree.) If you are already in a linked worktree, do not create another; go to step 4.
3. **Create the isolation, preferring the host's own tool** — it owns placement and cleanup, and a
   hand-made `git worktree add` behind its back creates state it cannot see:
   - **Orca**: `orca worktree create --name <name> --base-branch <base> [--agent <id>] [--issue <n>]`
   - **Claude Code**: its native worktree tool (`EnterWorktree`), or a subagent with worktree
     isolation
   - **Neither**: `git worktree add .worktrees/<name> -b <type>/<name> origin/<base>`, after
     checking `git check-ignore -q .worktrees` (add it to `.gitignore` first if not ignored)
   - **One person, no agents, small change**: a plain branch is enough:
     `git switch -c <type>/<name> origin/<base>`
4. **Start from a fresh base**: the branch is cut from `origin/<base>` *after* a fetch, never
   from a stale local copy.
5. **Name it by kind**: `feature/…`, `fix/…`, `docs/…`, `hotfix/…`. The prefix is a convention,
   not Git mechanics; it groups branches and says what they are.

### Parallel work — the split rule

| Two workers (people or agents) touch… | Do |
|---|---|
| different features | different branches, different worktrees |
| the same feature, different files | one branch is possible, but it is a bet; say so |
| the **same file** | **never** in parallel. Separate branches, or sequence them |

Before dispatching several agents, list the files each will touch. If two lists overlap, re-split.

---

## 2. Sync

### The order that works

```
fetch  →  merge <base> INTO your branch  →  resolve here  →  build  →  commit  →  push
```

Down, not up. The common failure is the loop: push → rejected → resolve → push → rejected with
*new* conflicts. It means you are resolving against a moving target. Stop resolving and align:

```bash
git fetch origin
git merge origin/<base>          # into the current branch
```

Merge (not rebase) is the default here because it keeps a shared branch's history intact. Use
rebase only on a branch nobody else has pulled, and only if the repo asks for linear history.

### Conflicts that "came back after I fixed them"

After days apart, branches diverge **structurally**: files deleted on one side, moved or renamed
(Git sees delete + add), content added to files the other side does not have. That is not a
line-level conflict to eyeball. Merging the base down shows the whole picture at once. The longer
a branch lives, the bigger the bill: merge the base down regularly, not once at the end. The status
line flags any branch open 3+ days.

### When someone else is still pushing

If you resolve while another person or agent keeps pushing to the same branches, neither finishes.
There is no technical fix. **Ask them to stop and push everything**, pull once, resolve, push
immediately. Tell the user to send that message; do not keep retrying.

### A pull is refused

```
error: Your local changes … would be overwritten by merge. Please commit your changes or stash them
```

```bash
git stash          # set uncommitted work aside; the tree goes clean (the work is NOT lost)
git pull
git stash pop      # put it back on top
```

**If a rebase fails, do not fight it.** `git rebase --abort`, then the same three commands.

### Reading a conflict

```
<<<<<<< HEAD
yours
=======
theirs
>>>>>>> origin/develop
```

Choose one block, the other, or write a third that combines them. Then search for leftovers before
committing — a stray marker breaks the build:

```bash
git diff --check
grep -rn '^<<<<<<< \|^>>>>>>> ' -- $(git diff --name-only HEAD) 2>/dev/null
```

### Resolving with an agent

- **Say the outcome, not the method**: "resolve the conflicts so both changes survive and the build
  passes". Not "keep lines 40–58 from ours". A detailed how-to hands the agent your guess as a
  constraint, and the guess is the weakest part of the instruction.
- **The agent resolves; a human verifies the build** — not the diff. A resolution that builds and
  renders is almost always right; one that does not is caught in seconds instead of on Friday.

### The panel looks wrong

"Publish branch" offered for a branch already published, or the sidebar showing a different branch
from the one commits go to, is a stale editor state, not Git. Fetch, reload the window, and read the
branch from `git branch --show-current` before any push.

---

## 3. Finish

1. **Sync first** (section 2). A PR from a branch that is behind its base hands the conflict to the
   reviewer.
2. **Build / test the tree you are about to ship**, after the sync. A green run earlier in the
   session proves nothing about the merged tree. If it fails, stop and report; nothing gets pushed.
3. **Commit** what belongs together, with a real message (`feat: …`, `fix: …`, `docs: …`). Leave
   unrelated changes out of the commit rather than sweeping them in.
4. **Push.** A commit exists only on this machine until it is pushed. Push before closing an agent's
   session: work left in a discarded workspace is gone.
   - Rejected push = the remote moved. Go back to section 2. **Never force-push** unless the user
     asks for it in so many words.
   - Pushing is the last human checkpoint. Do not disable the confirmation the host asks for.
5. **Open the PR against the branch you branched from.** Off `develop` → into `develop`.
   With GitHub: `gh pr create --base <base> --fill` (follow the repo's PR template if present).
   Report the URL.
6. **Review goes to a peer, not upwards.** People test the way they always test; a second person
   clicks what the author never clicks. Suggest a peer reviewer. A documentation-only PR can be
   self-approved.
7. **Present the choice, do not assume it.** After the PR is open, offer:
   ```
   1. Leave it for review (keep the branch and worktree for review fixes)
   2. Merge now (only if the repo allows self-merge and the user says so)
   3. Keep as-is
   ```
8. **After the merge**: the branch is finished. Delete it (`git branch -d <branch>`; the remote one
   via the PR's button or `git push origin --delete <branch>`), remove its worktree through the tool
   that created it (`orca worktree rm`, the host's exit tool, or `git worktree remove` for one you
   made under `.worktrees/`), and start the next piece of work from a fresh branch off the updated
   base. Do not keep working on a merged branch.

### Never, without the user's explicit word

- `git push --force`, `git reset --hard`, `git clean -fd`, `git branch -D`, `git worktree remove
  --force`. If a removal is refused because of uncommitted files, show the files and ask: commit
  them, move them, or delete them.
- Deleting or cleaning a worktree you did not create.
- Merging into a base you have not confirmed.

### Hotfix

Production is broken and the base (`develop`) carries unfinished work: branch from **`main`**, fix
only that, PR into `main`, then bring the same fix into `develop` so the next release does not undo
it.

---

## Quick reference

| Situation | Do |
|---|---|
| Push rejected, conflicts | Merge `origin/<base>` **into your branch**, resolve, build, push |
| Conflicts keep coming back | Someone is still pushing. Agree who stops |
| "Commit or stash your changes" | `git stash` → `git pull` → `git stash pop` |
| Rebase failed | `git rebase --abort`, then stash / pull / pop |
| Pull isn't showing their changes | `git fetch` first |
| Panel shows the wrong branch | Fetch, reload, check `git branch --show-current` |
| `<<<<<<<` in a file | Unresolved conflict. It will break the build |
| Branch open 3+ days | Merge the base down now; aim to land it |
| Two agents, same file | Separate branches, or sequence them |
| Agent resolved conflicts | Verify the build, not the diff |
| PR merged | Delete branch + worktree, start fresh from the base |

## Optional: the session hooks

`references/hooks.md` installs two **warning-only** Claude Code hooks: the status line at session
start, and a reminder at the end of a turn when commits are unpushed. They never run a merge, pull
or push.

## Credits

The worktree detection and the finishing menu are adapted from
[obra/superpowers](https://github.com/obra/superpowers) (`using-git-worktrees`,
`finishing-a-development-branch`), MIT. The working rules come from pairing sessions with a
developer, debugging real conflicts on a shared repository with people and agents.
