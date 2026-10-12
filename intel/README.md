# WAJO インテル（業界ニュースの自動巡回と朝刊）

営業マン全員が、毎朝これ1本を読めば業界の流れがつかめる。読む・読まないは本人次第。**毎朝必ず配ることが大事。**

## 流れ

```
[Mac Studio] 巡回エージェント（2時間おき・24時間）
   行政の一次情報 → 業界の反応 → SNS → 競合・業界地図
        │  1記事＝1行
        ▼
[Notion] 業界ニュースDB（既存のDBを使う。DB・列は増やさない）
        ▲
        │  毎朝 4:52 JST
[クラウド] 朝刊エージェント（Claude Code のルーティン）
   前日分を読み、取りこぼしを補い、【朝刊】を1行（🔴 必読）
        │
        ▼
[Notion] DISCOVER AI（WANiPO情報集め）→ ワニポの日報 → STAFF HOME
```

## ファイル

| ファイル | 中身 |
|---|---|
| `sources.md` | 巡回先・競合・キーワード。**競合の会社名はここに足す** |
| `prompts/crawl.md` | 巡回エージェントの指示書（Mac Studio） |
| `prompts/morning-edition.md` | 朝刊エージェントの指示書（クラウドのルーティンに同じ文を登録済み） |
| `mac/install.sh` | Mac Studio に登録するスクリプト |

## Mac Studio の準備（1回だけ）

```bash
# 1. Claude Code を入れて、大ちゃんのアカウントでログイン
curl -fsSL https://claude.ai/install.sh | bash
claude            # 起動してログイン

# 2. Notion をつなぐ（claude を開いて /mcp → notion → ログイン）
claude mcp add --scope user --transport http notion https://mcp.notion.com/mcp

# 3. このリポジトリを取ってきて登録
git clone https://github.com/isibasi-alt/WAJO-Sales-OS.git ~/WAJO-Sales-OS
~/WAJO-Sales-OS/intel/mac/install.sh
```

- 24時間動かすには：システム設定 → エネルギー →「ディスプレイがオフのときに自動でスリープさせない」をオン。
- ログ：`~/Library/Logs/wajo-intel/`
- 止める：`launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.wajo.intel-crawl.plist`

## 決めごと

- 書き込むのは業界ニュースDBだけ。新しいDB・列・選択肢は作らない。
- 記事の種類はタイトルの頭で分ける：【行政】【業界】【競合】【業界地図】【SNS】【朝刊】
- `トーク作成` には触らない（営業トーク自動生成のクレジットを勝手に使わないため）。
- 書いていないことは作らない。確かめられないものは「未確認」。

## クラウドのルーティン（朝刊）

- 名前：`WAJO 朝刊（業界ニュース）`／毎朝 4:52 JST／毎回新しいセッションで動く
- 管理画面：https://claude.ai/code/routines
- **Notion をつなぐこと**：ルーティンの編集画面で、コネクタに Notion を足す（足さないと朝刊を書き込めない）。
- 指示文を変えたら、`prompts/morning-edition.md` も同じように直す。
