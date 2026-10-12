#!/bin/bash
# Mac Studio に巡回エージェントを登録する（1回だけ実行）。
set -euo pipefail

INTEL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$INTEL_DIR/mac/com.wajo.intel-crawl.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.wajo.intel-crawl.plist"

command -v claude >/dev/null || { echo "claude が見つかりません。先に Claude Code を入れてください。"; exit 1; }
claude mcp list 2>/dev/null | grep -qi notion || {
  echo "Notion の MCP がありません。次を実行して、claude を開き /mcp で Notion にログインしてください："
  echo "  claude mcp add --scope user --transport http notion https://mcp.notion.com/mcp"
  exit 1
}

chmod +x "$INTEL_DIR/mac/run-crawl.sh"
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__INTEL_DIR__|$INTEL_DIR|g" "$PLIST_SRC" >"$PLIST_DST"

launchctl bootout "gui/$(id -u)" "$PLIST_DST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
echo "登録しました。ログ: ~/Library/Logs/wajo-intel/"
echo "止めるとき: launchctl bootout gui/$(id -u) $PLIST_DST"
