# branch-lifecycle

An agent skill for the whole life of a Git branch when **several people or several AI agents** work
on one repository in parallel: start isolated, stay aligned with the base branch, resolve conflicts
in the right order, close with push, pull request and cleanup.

It is built around one rule, learned the hard way on a shared repository:

> You cannot resolve a conflict until your branch is aligned with the branch you want to merge into.
> Bring the base down first, resolve on your own branch, prove it builds, then push.

## What it does

- **Start** — detects whether you are already in an isolated worktree; if not, creates one with the
  host's own tool (Orca, Claude Code) or `git worktree`, from a freshly fetched base. Splits parallel
  work so two agents never edit the same file.
- **Sync** — the fetch → merge base *into* your branch → resolve → build → push order; `stash` when a
  pull is refused; what to do when a rebase fails, when someone else is still pushing, when the Git
  panel shows the wrong branch.
- **Finish** — build the merged tree, push, open the PR against the branch you came from, send it to a
  peer, then delete the branch and its worktree. No force-push, hard reset or forced cleanup without
  the user's explicit word.
- **`scripts/branch-status.sh`** — one read-only line: branch, behind/ahead of the base, days open,
  unpushed, uncommitted, conflicts, stashes, worktrees, plus a `next:` hint.
- **Optional hooks** — a status line at session start and an "unpushed" reminder at the end of a turn.
  Warning-only. See [`references/hooks.md`](skills/branch-lifecycle/references/hooks.md).

The base branch is detected per repo: `git config branch-lifecycle.base` → `develop` if
`origin/develop` exists → origin's default branch → `main`/`master`.

## Install

```bash
npx skills add jjlopezruiz/branch-lifecycle
```

Add `-g` to install for all your projects. Works with any agent that reads `SKILL.md` skills; the
optional hooks are Claude Code specific.

## Status

**0.1 — draft, under review.** Feedback and pull requests welcome.

## Credits

Worktree detection and the finishing menu adapted from
[obra/superpowers](https://github.com/obra/superpowers) (MIT). The working rules come from pairing
sessions with a developer on a shared repository.

## License

MIT
