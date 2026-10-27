#!/bin/bash
# Mac の中の CLAUDE.md / AGENTS.md すべてに「AI の作業報告と本番の変更」の決まりを書き足す。
#
# 使い方：
#   bash add-work-report-rule.sh          … 書き込む先の一覧を出すだけ（何も変えない）
#   bash add-work-report-rule.sh --apply  … 一覧のファイルに書き足す（元のファイルは控えを取ってから）
#
# - ~/.claude/CLAUDE.md（Mac 全体の Claude Code）と ~/.codex/AGENTS.md（Mac 全体の Codex）は、無ければ作る。
# - ホームフォルダの下の CLAUDE.md / AGENTS.md を全部探す（iCloud Drive も含む）。
#   ライブラリ・ゴミ箱・node_modules・.git・プラグイン・会話の記録・キャッシュの中は探さない。
# - すでに書いてあるファイル（印 WAJO-WORK-REPORT-RULE がある）は飛ばす。2回動かしても二重にならない。
# - 控えは ~/wajo-rule-backup-20261027/ に、元の場所と同じ並びで取る。

set -u

MARK="WAJO-WORK-REPORT-RULE v1"
BACKUP="$HOME/wajo-rule-backup-20261027"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

read -r -d '' BLOCK <<'EOF'
<!-- WAJO-WORK-REPORT-RULE v1 -->
## AI の作業報告と本番の変更（全AI共通・大ちゃん決定 2026-10-27）

- 作業報告は Notion の「AI作業報告DB」に1件1行で書く。https://app.notion.com/p/08a4adb54e3647af826b96d5bab1ffd9 （データソース `collection://c1ca2ffe-29d2-4d19-802d-87b80d0d6c1f`）
- 営業が使うDB（案件管理・お問い合わせ・土地情報・企業マスター・社外顧問など）や、ほかのページに作業報告を書かない。
- 1行に書くこと：どのAIか／どのチャンネル・セッションか／事前（何を・どこへ・消えるもの）／事後（実際に変わったもの・消えたもの）／戻し方。
- 本番（Notion のボタン・オートメーション・数式・ビュー・レイアウト・DB・列・ページ、Worker のデプロイ）を変える前に、何をどう変えるかを大ちゃんに見せて OK をもらう。OK の言葉をそのまま「OKの原文」に書き写す。OK が無ければ変えない。
- 調べるように頼まれたときは、調べるだけで終える。見つけた不具合は作業報告に書き、直すかどうかは大ちゃんが決める。
<!-- /WAJO-WORK-REPORT-RULE -->
EOF

LIST="$(mktemp)"

# Mac 全体に効く2つ（無ければ作る）
echo "$HOME/.claude/CLAUDE.md" >> "$LIST"
echo "$HOME/.codex/AGENTS.md" >> "$LIST"

find_rules() {
  find "$1" \
    \( -path "$HOME/Library" -o -path "$HOME/.Trash" -o -path "$BACKUP" \
       -o -path "$HOME/.claude/plugins" -o -path "$HOME/.claude/projects" \
       -o -path "$HOME/.codex/sessions" \
       -o -name node_modules -o -name .git -o -name .cache \) -prune \
    -o -type f \( -name CLAUDE.md -o -name AGENTS.md \) -print 2>/dev/null
}

find_rules "$HOME" >> "$LIST"
[ -d "$HOME/Library/Mobile Documents" ] && find_rules "$HOME/Library/Mobile Documents" >> "$LIST"

TODO=0
SKIP=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [ -f "$f" ] && grep -q "$MARK" "$f" 2>/dev/null; then
    SKIP=$((SKIP + 1))
    continue
  fi
  TODO=$((TODO + 1))
  if [ "$APPLY" -eq 0 ]; then
    if [ -f "$f" ]; then echo "書き足す: $f"; else echo "新しく作る: $f"; fi
    continue
  fi
  mkdir -p "$(dirname "$f")"
  if [ -f "$f" ]; then
    mkdir -p "$BACKUP$(dirname "$f")"
    cp -p "$f" "$BACKUP$f"
    printf '\n\n%s\n' "$BLOCK" >> "$f"
    echo "書き足した: $f"
  else
    printf '%s\n' "$BLOCK" > "$f"
    echo "作った: $f"
  fi
done < <(sort -u "$LIST")

rm -f "$LIST"

echo "----"
if [ "$APPLY" -eq 0 ]; then
  echo "書き込む先: ${TODO} 件（すでに書いてあるので飛ばす: ${SKIP} 件）。まだ何も変えていません。"
  [ "$TODO" -gt 0 ] && echo "よければ --apply を付けてもう一度動かしてください。"
else
  echo "書き込んだ: ${TODO} 件（飛ばした: ${SKIP} 件）。控え: $BACKUP"
fi
