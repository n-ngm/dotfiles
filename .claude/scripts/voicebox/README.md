# VoiceBox - Claude Code VOICEVOX 連携

Claude Code の hooks と MCP を使って、VOICEVOX による音声通知・音声読み上げを行うセットアップ。

## 前提条件

- macOS
- [Docker](https://www.docker.com/)
- [terminal-notifier](https://github.com/julienXX/terminal-notifier) (`brew install terminal-notifier`)
- [uv](https://github.com/astral-sh/uv) (Python スクリプト実行用)
- [VOICEVOX MCP Server](https://github.com/trasta298/mcp-server-voicevox) (Claude Code の MCP 設定に追加)

## ディレクトリ構成

```
.claude/scripts/voicebox/
├── README.md
├── AGENTS.md              # Claude Code 向けエージェントルール
├── docker-compose.yml     # VOICEVOX Engine (CPU版)
├── voicevox-notify.py     # 通知スクリプト (Python/uv)
├── voicevox-notify.sh     # 通知スクリプト (Bash版、レガシー)
└── speakers/
    ├── current.yaml -> zundamon.yaml   # 現在のキャラクター (シンボリックリンク)
    ├── zundamon.yaml
    ├── shikoku_metan.yaml
    ├── ankomon.yaml
    └── ...
```

## セットアップ

### 1. VOICEVOX Engine の起動

```bash
cd ~/.claude/scripts/voicebox
docker compose up -d
```

`http://localhost:50021` で VOICEVOX Engine が起動する。

### 2. Claude Code の hooks 設定

`.claude/settings.json` に以下を追加:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/voicebox/voicevox-notify.py"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/voicebox/voicevox-notify.py"
          }
        ]
      }
    ]
  }
}
```

- **Stop**: タスク完了時にデスクトップ通知 + 音声読み上げ
- **Notification**: 権限確認・質問など、ユーザー入力待ち時に通知

### 3. VOICEVOX MCP Server の設定

Claude Code の MCP 設定に VOICEVOX MCP Server を追加すると、Claude が直接音声合成を呼び出せるようになる。

### 4. AGENTS.md の読み込み

`.claude/CLAUDE.md` に以下を追加:

```markdown
### Import

VoiceBox: @scripts/voicebox/AGENTS.md
```

これにより Claude Code がキャラクター口調や音声通知のルールに従うようになる。

## キャラクター設定

### 切り替え

`speakers/current.yaml` のシンボリックリンク先を変更する:

```bash
cd ~/.claude/scripts/voicebox/speakers
ln -sf shikoku_metan.yaml current.yaml
```

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
Claude Code (hooks: Stop/Notification)
  │
  ├── voicevox-notify.py (stdin で JSON を受け取る)
  │     ├── speakers/current.yaml から口調・speaker_id を取得
  │     ├── transcript から最後の応答テキストを抽出
  │     ├── terminal-notifier でデスクトップ通知
  │     └── VOICEVOX Engine (localhost:50021) で音声合成 → afplay で再生
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
cd ~/.claude/scripts/voicebox
docker compose restart
```

### 音声が遅い・MCP が応答しない

MCP サーバープロセスが複数起動している可能性がある:

```bash
pkill -f mcp-server-voicevox
```

Claude Code を再起動すると自動的に新プロセスが起動する。
