VoiceBox のインストールを行う。以下の手順を順番に実行すること。

## 1. 前提条件チェック

以下のコマンドが利用可能か確認する。不足があればユーザーに通知して中断する。

- `docker` (Docker)
- `terminal-notifier` (`brew install terminal-notifier`)
- `uv` (Python スクリプト実行用)

## 2. VOICEVOX Engine の起動

voicebox ディレクトリの `docker-compose.yml` を使って VOICEVOX Engine を起動する。

```bash
docker compose -f <voicebox_dir>/docker-compose.yml up -d
```

起動後、`curl -s http://localhost:50021/version` でエンジンが応答するか確認する。

## 3. セットアップスクリプトの実行

`~/.claude/settings.json` に hooks（Stop/Notification）、`~/.claude/settings.local.json` に speakers_dir を設定する旨をユーザーに伝え、実行してよいか確認する。

承諾されたら以下を実行する:

```bash
python3 <voicebox_dir>/setup.py
```

## 4. CLAUDE.md へのインポート設定

`~/.claude/CLAUDE.md` の `### Import` セクションに voicebox の CLAUDE.md インポートが未設定の場合、ユーザーに追加してよいか確認する。

追加する内容:
```
VoiceBox: @<voicebox_dir>/CLAUDE.md
```

`<voicebox_dir>` は voicebox ディレクトリの実際の絶対パスに置き換えること。

承諾されたら `~/.claude/CLAUDE.md` の `### Import` セクションに追記する。既にインポート済みなら「設定済み」と伝えてスキップする。

## 5. 完了報告

設定結果をユーザーに報告する。Claude Code の再起動が必要な旨を伝える。
