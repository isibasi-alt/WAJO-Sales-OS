#!/bin/bash
# Mac 全体に本番の鍵をかける。大ちゃん決定 2026-10-27。
#
# 使い方（WAJO-Sales-OS のフォルダで）：
#   bash tools/lock/install-mac-lock.sh          … 何を変えるかを見せるだけ（何も変えない）
#   bash tools/lock/install-mac-lock.sh --apply  … 鍵をかける（元の設定は控えを取ってから）
#
# 1. Claude Code（その Mac の全部のフォルダ）：
#    ~/.claude/settings.json にフックを足す。Notion への書き込みは毎回大ちゃんの承認画面、
#    Worker の本番デプロイは AI から打てない。中身は tools/lock/production-guard.sh。
# 2. Codex（その Mac の全部のフォルダ）：
#    ~/.codex/config.toml の approval_policy を "untrusted" にする。
#    読むだけ以外の命令は、毎回大ちゃんの承認が要る。
#
# 控え：~/wajo-lock-backup-20261027/

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1
BACKUP="$HOME/wajo-lock-backup-20261027"
GUARD_SRC="$HERE/production-guard.sh"
GUARD_DST="$HOME/.claude/hooks/wajo-production-guard.sh"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CODEX_CONFIG="$HOME/.codex/config.toml"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 が見つかりません。止めます。"
  exit 1
fi
if [ ! -f "$GUARD_SRC" ]; then
  echo "鍵の本体 $GUARD_SRC が見つかりません。止めます。"
  exit 1
fi

echo "== Claude Code =="
echo "鍵の本体を置く: $GUARD_DST"
echo "設定に足す: ${CLAUDE_SETTINGS}（フック1つ・拒否ルール3つ。今ある設定は残す）"
echo "== Codex =="
if [ "${WAJO_LOCK_CODEX:-0}" != "1" ]; then
  echo "Codex には触らない（2026-10-28 に Codex が立ち上がらなくなったため止めている）"
elif [ -f "$CODEX_CONFIG" ]; then
  now="$(grep -E '^[[:space:]]*approval_policy[[:space:]]*=' "$CODEX_CONFIG" | head -1)"
  echo "設定を変える: ${CODEX_CONFIG}（今：${now:-approval_policy の指定なし} → approval_policy = \"untrusted\"）"
else
  echo "設定を作る: ${CODEX_CONFIG}（approval_policy = \"untrusted\"）"
fi

if [ "$APPLY" -eq 0 ]; then
  echo "----"
  echo "まだ何も変えていません。よければ --apply を付けてもう一度動かしてください。"
  exit 0
fi

mkdir -p "$BACKUP" "$HOME/.claude/hooks" "$HOME/.codex"
# 控えは最初の1回だけ取る（2回目以降に鍵つきの設定で上書きしない）
[ -f "$CLAUDE_SETTINGS" ] && [ ! -f "$BACKUP/claude-settings.json" ] && cp -p "$CLAUDE_SETTINGS" "$BACKUP/claude-settings.json"
[ -f "$CODEX_CONFIG" ] && [ ! -f "$BACKUP/codex-config.toml" ] && cp -p "$CODEX_CONFIG" "$BACKUP/codex-config.toml"

cp "$GUARD_SRC" "$GUARD_DST"
chmod +x "$GUARD_DST"

python3 - "$CLAUDE_SETTINGS" <<'PY'
import json, os, sys
path = sys.argv[1]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        text = f.read().strip()
    data = json.loads(text) if text else {}
cmd = 'bash "$HOME/.claude/hooks/wajo-production-guard.sh"'
hooks = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
already = any(h.get("command") == cmd for e in hooks for h in e.get("hooks", []))
if not already:
    hooks.append({
        "matcher": "Bash|mcp__.*",
        "hooks": [{"type": "command", "command": cmd, "timeout": 10, "onFailure": "block"}],
    })
deny = data.setdefault("permissions", {}).setdefault("deny", [])
for rule in ["Bash(ntn workers deploy)", "Bash(ntn workers deploy *)", "Bash(NOTION_KEYRING=0 ntn workers deploy *)"]:
    if rule not in deny:
        deny.append(rule)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("Claude Code の設定に鍵を足しました: " + path)
PY

if [ "${WAJO_LOCK_CODEX:-0}" = "1" ]; then
python3 - "$CODEX_CONFIG" <<'PY'
import os, re, sys
path = sys.argv[1]
lines = []
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()
# いちばん上の段（最初の [table] より前）にある approval_policy を置き換える。無ければ先頭に足す。
first_table = next((i for i, l in enumerate(lines) if re.match(r"^\s*\[", l)), len(lines))
done = False
for i in range(first_table):
    if re.match(r"^\s*approval_policy\s*=", lines[i]):
        lines[i] = 'approval_policy = "untrusted"  # 本番の鍵（大ちゃん決定 2026-10-27）'
        done = True
if not done:
    lines.insert(0, 'approval_policy = "untrusted"  # 本番の鍵（大ちゃん決定 2026-10-27）')
with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("Codex の設定に鍵をかけました: " + path)
PY

CODEX_HOOKS="$HOME/.codex/hooks.json"
[ -f "$CODEX_HOOKS" ] && [ ! -f "$BACKUP/codex-hooks.json" ] && cp -p "$CODEX_HOOKS" "$BACKUP/codex-hooks.json"
python3 - "$CODEX_HOOKS" <<'PY'
import json, os, sys
path = sys.argv[1]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        text = f.read().strip()
    data = json.loads(text) if text else {}
cmd = 'WAJO_GUARD_MODE=block bash "$HOME/.claude/hooks/wajo-production-guard.sh"'
hooks = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
if not any(h.get("command") == cmd for e in hooks for h in e.get("hooks", [])):
    hooks.append({"hooks": [{"type": "command", "command": cmd, "timeout": 10}]})
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("Codex のフックに鍵をつなぎました（Notion への書き込みと本番デプロイを止める）: " + path)
PY
else
  echo "Codex には鍵をかけていません（2026-10-28、かけたら Codex が立ち上がらなくなったため止めている。WAJO_LOCK_CODEX=1 で有効。かける前に必ず試すこと）"
fi

echo "----"
echo "鍵をかけました。控え: $BACKUP"
echo "開いている Claude Code と Codex は、いったん閉じて開き直すと鍵が効きます。"
