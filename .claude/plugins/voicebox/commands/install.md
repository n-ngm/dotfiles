VoiceBox Plugin のインストールを行う。以下の手順を順番に実行すること。

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

## 3. デフォルトキャラクターの選択

`~/.claude/settings.local.json` に `voicebox.current_speaker` を設定する。

既に設定済みならスキップする。未設定の場合、プラグインの `speakers/` ディレクトリから `.yaml` ファイルの一覧を取得し、各ファイルの `name` フィールドも読み取る。人気のキャラクター4人を選択肢として AskUserQuestion で提示する。質問文に「他のキャラクターも選べます」と記載し、ユーザーが「Other」から入力できるようにすること。

選択されたキャラクターを `~/.claude/settings.local.json` に設定する:

```json
{
  "voicebox": {
    "current_speaker": "<選択されたキャラクター名>"
  }
}
```

## 4. permissions の設定

`~/.claude/settings.json` の `permissions.allow` に `settings.local.json` の読み取り許可が未設定の場合、ユーザーに追加してよいか確認する。

追加する内容:
```
Read(**/.claude/settings.local.json)
```

承諾されたら `permissions.allow` 配列に追記する。既に設定済みならスキップする。

## 5. CLAUDE.md へのインポート設定

`~/.claude/CLAUDE.md` の `### Import` セクションに voicebox の CLAUDE.md インポートが未設定の場合、ユーザーに追加してよいか確認する。

追加する内容:
```
VoiceBox: @<voicebox_dir>/CLAUDE.md
```

`<voicebox_dir>` は voicebox ディレクトリの実際の絶対パスに置き換えること。

承諾されたら `~/.claude/CLAUDE.md` の `### Import` セクションに追記する。既にインポート済みなら「設定済み」と伝えてスキップする。

## 6. 完了報告

設定結果をユーザーに報告する。Claude Code の再起動が必要な旨を伝える。
