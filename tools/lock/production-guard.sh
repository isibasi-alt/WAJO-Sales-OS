#!/bin/bash
# 本番の鍵（Claude Code の PreToolUse フック）。大ちゃん決定 2026-10-27。
#
# - Notion に書き込む道具（作る・直す・消す・動かす・コメントなど）を AI が使おうとしたら、
#   毎回、大ちゃんの承認画面を出す（ask）。読むだけの道具は止めない。
#   例外：AI作業報告DB と 業界ニュースDB に新しい行を作るときだけは止めない。
# - Worker を本番に出す命令（ntn workers deploy・deploy-gate）は、AI からは打てない（deny）。
#   本番に出すのは大ちゃんが自分で打つ。
# - Notion の API を直接たたく命令（api.notion.com）も、毎回承認画面を出す。
# - 止めたものは ~/.claude/wajo-guard.log に記録する。
#
# jq を使わない（Mac に無いことがあるため）。

input="$(cat)"

tool="$(printf '%s' "$input" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"

REPORT_DS="c1ca2ffe-29d2-4d19-802d-87b80d0d6c1f"   # AI作業報告DB
NEWS_DS="15273928-a119-4b42-8801-185f54e55c58"     # 業界ニュースDB

log() {
  mkdir -p "$HOME/.claude" 2>/dev/null
  printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$tool" >> "$HOME/.claude/wajo-guard.log" 2>/dev/null
}

decide() {
  # $1 = ask / deny、$2 = 理由
  log "$1"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$1" "$2"
  exit 0
}

lower="$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]')"

# Notion の道具
case "$lower" in
  *notion*)
    action="${lower##*__}"
    # 読むだけの道具は止めない
    if printf '%s' "$action" | grep -Eq '(search|query|fetch|retrieve|get|list|read|download|wait|show)'; then
      exit 0
    fi
    if printf '%s' "$action" | grep -Eq '(create|update|delete|patch|post|put|move|duplicate|restore|upload|append|archive|set|send|spawn|stop|convert|cancel|trash)'; then
      # AI作業報告DB・業界ニュースDB に新しい行を作るときだけは止めない
      if printf '%s' "$action" | grep -Eq 'create-pages$' && printf '%s' "$input" | grep -Eq "$REPORT_DS|$NEWS_DS"; then
        exit 0
      fi
      decide ask "本番のNotionへの書き込みです。何をどう変えるかを大ちゃんに見せて、OKをもらってから承認してください（AI作業報告DBの決まり）。"
    fi
    exit 0
    ;;
esac

# シェルの命令
if [ "$tool" = "Bash" ]; then
  if printf '%s' "$input" | grep -Eq 'ntn[[:space:]]+workers[[:space:]]+deploy|deploy-gate'; then
    decide deny "Worker の本番デプロイは AI からは打てません。大ちゃんが自分で打ちます。"
  fi
  if printf '%s' "$input" | grep -q 'api\.notion\.com'; then
    decide ask "Notion の API を直接使う命令です。本番を変える場合は、大ちゃんのOKをもらってから承認してください。"
  fi
fi

exit 0
