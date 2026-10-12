#!/bin/bash
# Mac Studio で巡回エージェントを1回動かす。launchd から2時間おきに呼ばれる。
set -euo pipefail

INTEL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$HOME/Library/Logs/wajo-intel"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/crawl-$(date +%Y%m%d).log"

# launchd は PATH が最小なので、claude の場所を足す
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

cd "$INTEL_DIR/prompts"
{
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') start ==="
  claude -p "$(cat crawl.md)" \
    --allowedTools "WebSearch,WebFetch,Read,mcp__notion" \
    --output-format text
  echo "=== $(date '+%Y-%m-%d %H:%M:%S') end ==="
} >>"$LOG" 2>&1

# 30日より古いログは消す
find "$LOG_DIR" -name 'crawl-*.log' -mtime +30 -delete
