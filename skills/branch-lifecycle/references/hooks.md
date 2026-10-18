# Optional session hooks (Claude Code)

A skill cannot switch hooks on by itself: Claude Code reads hooks only from settings files or
plugins ([hooks docs](https://code.claude.com/docs/en/hooks)). So these two are opt-in. Both are
**warning-only**: they read Git state and print one line. They never merge, pull, push or block.

| Hook | When | What it shows |
|---|---|---|
| `hook-session-start.sh` | session start / resume | `git fetch` (8 s cap), then the status line from `branch-status.sh` — to you, and to Claude as context |
| `hook-stop.sh` | end of each answer | "N commit(s) not pushed" or "branch never pushed" — once per session per commit, silent otherwise |

Outside a Git repository both stay silent.

## Install

1. Install the skill globally (`npx skills add jjlopezruiz/branch-lifecycle -g`), so the scripts sit
   at `~/.claude/skills/branch-lifecycle/scripts/`. Check the path: `ls ~/.claude/skills/branch-lifecycle/scripts`.
2. Merge this into `~/.claude/settings.json` (all projects) or `.claude/settings.json` (one repo).
   **Merge, do not overwrite** — keep any hooks already there.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          { "type": "command", "command": "~/.claude/skills/branch-lifecycle/scripts/hook-session-start.sh", "timeout": 15 }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/skills/branch-lifecycle/scripts/hook-stop.sh", "timeout": 10 }
        ]
      }
    ]
  }
}
```

3. Open a new session in a repository. The first line should read like
   `git: branch feature/x · 4 behind / 2 ahead of origin/develop · open 3d · 1 unpushed`.

## Requirements

`bash`, `git`, `python3` (to read the hook's JSON input) and `perl` (for the fetch timeout; macOS has
no `timeout`). All present on stock macOS and most Linux.

## Turning them off

Remove the two entries from `settings.json`. Nothing else was changed.
