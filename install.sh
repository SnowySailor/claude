#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET_SCRIPT="$CLAUDE_DIR/statusline.sh"
TARGET_SETTINGS="$CLAUDE_DIR/settings.json"

command -v jq > /dev/null || { echo "jq is required but not installed." >&2; exit 1; }

mkdir -p "$CLAUDE_DIR"

if [ -e "$TARGET_SCRIPT" ] && ! cmp -s "$SOURCE_DIR/statusline.sh" "$TARGET_SCRIPT"; then
    read -r -p "$TARGET_SCRIPT exists and differs. Overwrite? [y/N] " answer
    case "$answer" in
        [yY] | [yY][eE][sS]) ;;
        *) echo "Aborted."; exit 1 ;;
    esac
fi

install -m 755 "$SOURCE_DIR/statusline.sh" "$TARGET_SCRIPT"

[ -f "$TARGET_SETTINGS" ] || echo '{}' > "$TARGET_SETTINGS"

tmp=$(mktemp)
jq --slurpfile new "$SOURCE_DIR/settings.json" '. + $new[0]' "$TARGET_SETTINGS" > "$tmp"
mv "$tmp" "$TARGET_SETTINGS"

echo "Installed $TARGET_SCRIPT and updated statusLine in $TARGET_SETTINGS."
