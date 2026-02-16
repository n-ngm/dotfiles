# VoiceBox - Claude Code VOICEVOX 連携

Claude Code のプラグインと MCP を使って、VOICEVOX による音声通知・音声読み上げを行うセットアップ。

## 前提条件

- macOS or Linux
- [Docker](https://www.docker.com/)
- [uv](https://github.com/astral-sh/uv) (Python スクリプト実行用)
- [VOICEVOX MCP Server](https://github.com/trasta298/mcp-server-voicevox) (Claude Code の MCP 設定に追加)
- macOS: [terminal-notifier](https://github.com/julienXX/terminal-notifier) (`brew install terminal-notifier`)
- Linux: `notify-send` (通知用), `paplay`/`aplay`/`mpv` (音声再生用、いずれか1つ)

## ディレクトリ構成

```
voicebox/
├── .claude-plugin/
│   └── plugin.json            # プラグインマニフェスト
├── commands/
│   └── install.md             # /voicebox:install コマンド
├── speakers/
│   ├── zundamon.yaml
│   ├── shikoku_metan.yaml
│   ├── ankomon.yaml
│   └── ...
├── .mcp.json                  # VOICEVOX MCP Server 設定
├── CLAUDE.md                  # Claude Code 向けキャラクター口調ルール
├── notify.py         # 通知スクリプト (Python/uv)
├── setup.py                   # セットアップスクリプト (hooks 設定)
├── docker-compose.yml         # VOICEVOX Engine (CPU版)
└── README.md
```

## セットアップ

### marketplace からインストール（推奨）

```bash
claude marketplace add /path/to/dotfiles/voicebox
```

セッション内で `/plugin install voicebox@voicebox` を実行。

その後 `/voicebox:install` を実行すると、以下が順番に行われる:

1. 前提条件チェック (docker, terminal-notifier, uv)
2. VOICEVOX Engine の起動 (Docker)
3. デフォルトキャラクターの選択
4. permissions の設定

### 手動セットアップ

#### 1. VOICEVOX Engine の起動

```bash
docker compose -f /path/to/voicebox/docker-compose.yml up -d
```

`http://localhost:50021` で VOICEVOX Engine が起動する。

#### 2. VOICEVOX MCP Server の設定

プラグインの `.mcp.json` で自動設定される。手動で設定する場合は Claude Code の MCP 設定に VOICEVOX MCP Server を追加する。

## キャラクター設定

### キャラクター切り替え

`settings.local.json` の `voicebox.current_speaker` で設定する:

```json
{
  "voicebox": {
    "current_speaker": "zundamon"
  }
}
```

**解決の優先度:**
1. `{プロジェクトディレクトリ}/.claude/settings.local.json`
2. `~/.claude/settings.local.json`
3. デフォルト: `zundamon`

### キャラクター YAML の構造

```yaml
character:
  name: キャラクター名
  personality: 性格の説明

styles:
  - id: 1           # VOICEVOX の speaker_id
    name: "ノーマル"
    default: true    # デフォルトスタイル

speech_style:
  suffix: "語尾パターン"
  description: 口調の説明

examples:
  命令受領時: "了解なのだ"
  完了時: "完了なのだ"

notifications:
  default: "通知メッセージ"
  task_complete: "タスク完了メッセージ"
  permission_needed: "許可要求メッセージ"
  question: "質問メッセージ"
  tool_permission: "{tool}の許可メッセージ"
```

### 利用可能なキャラクター

| ファイル | キャラクター |
|----------|------------|
| zundamon.yaml | ずんだもん |
| shikoku_metan.yaml | 四国めたん |
| kasukabe_tsumugi.yaml | 春日部つむぎ |
| tohoku_zunko.yaml | 東北ずん子 |
| tohoku_kiritan.yaml | 東北きりたん |
| tohoku_itako.yaml | 東北イタコ |
| shirakami_kotarou.yaml | 白上虎太郎 |
| kurono_takehiro.yaml | 玄野武宏 |
| chibishikijii.yaml | ちび式じい |
| ankomon.yaml | あんこもん |

## 仕組み

```
Claude Code
  │
  ├── setup.py → settings.json に hooks を登録
  │
  ├── notify.py (hooks から呼ばれる、stdin で JSON を受け取る)
  │     ├── settings.local.json → current_speaker を解決
  │     ├── speakers/{current_speaker}.yaml から口調・speaker_id を取得
  │     ├── transcript から最後の応答テキストを抽出
  │     ├── デスクトップ通知 (macOS: terminal-notifier / Linux: notify-send)
  │     └── VOICEVOX Engine (localhost:50021) で音声合成 → 再生 (macOS: afplay / Linux: paplay/aplay/mpv)
  │
  ├── CLAUDE.md → キャラクター口調・speaker_id ルール
  │
  └── VOICEVOX MCP Server (明示的に指示した場合のみ)
        └── Claude が直接テキスト読み上げを実行
```

## トラブルシューティング

### VOICEVOX Engine に接続できない

```bash
# Engine の状態確認
curl http://localhost:50021/version

# 再起動
docker compose -f /path/to/voicebox/docker-compose.yml restart
```

### 音声が遅い・MCP が応答しない

MCP サーバープロセスが複数起動している可能性がある:

```bash
pkill -f mcp-server-voicevox
```

Claude Code を再起動すると自動的に新プロセスが起動する。
