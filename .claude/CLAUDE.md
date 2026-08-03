### 出力について
- 強調スタイル(**~**)は使用しないこと。
- 一文ずつ適度に改行すること。
- 指示されない限り、表組よりも箇条書きスタイルを優先して使うこと。

### git commit ルール

- 内容が複数ある場合は、コミットを分けることを推奨
- コミットメッセージは以下の形式を推奨:

```
[type]: subject
例: feat: add thread reply feature
```

- typeの種類: feat, fix, docs, style, refactor, test, chore
- シンプルな内容なら、1行
- 説明を書く場合、箇条書きで3~5行に納める

### タスク管理ルール

- ユーザーのタスク管理には **Todoist** を使用する（Todoist MCP 経由）
- ユーザーのタスク確認・作成・更新はすべて Todoist MCP ツールで行うこと
- タイトルの内容や期限から優先度を推測し、適切な priority を設定すること
  - 例: 「緊急」「今すぐ」→ p1、期限が近い → p2、通常 → p3、メモ程度 → p4
- Claude 自身の作業管理には内蔵の TaskCreate/TaskUpdate を使ってよい

### ファイル出力ルール

- Write/Edit でファイルに書き込む内容に Markdown の太字装飾 `**~**` を使わない
- 強調が必要な場合は見出し・箇条書き・プレーンテキストで構造化する
- チャット返信での太字は対象外（ファイル出力に限る）

### Import

VoiceVox: @~/.claude/plugins/voicevox/CLAUDE.md
