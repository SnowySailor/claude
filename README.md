# Claude Code statusline

A Claude Code status line that shows model, effort, session cost, token usage, context %, prompt cache countdown, and git branch.

## Requirements

- [Claude Code](https://code.claude.com)
- `jq`
- `git` (for the branch segment)

## Install

```bash
git clone https://github.com/SnowySailor/claude.git
cd claude
./install.sh
```

The installer:

1. Asks before it overwrites an existing, different `~/.claude/statusline.sh`.
2. Copies `statusline.sh` to `~/.claude/statusline.sh` with mode 755.
3. Merges the `statusLine` key from `settings.json` into `~/.claude/settings.json`. Other settings stay unchanged.

Restart Claude Code to see the new status line.

To use another config directory, set `CLAUDE_CONFIG_DIR`:

```bash
CLAUDE_CONFIG_DIR=/path/to/dir ./install.sh
```
