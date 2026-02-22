# /parallel: tmuxベース並列エージェント実行

複数リポジトリで子Claude Codeを並列起動し、tmuxペインで管理する。

## 引数の解釈

`$ARGUMENTS` は以下のいずれかの形式:

1. **JSON配列**: `[{"id":"cms-test","dir":"apps/page/cms","prompt":"テスト実行して"}]`
2. **`workers=N` 付きJSON配列**: `workers=2 [{"id":"t1","dir":"apps/page","prompt":"..."},...]`
3. **自然言語**: 対話でタスクリストを確定させる

JSON配列でない場合は、ユーザーと対話してタスクリストを確定させること。

## モード判定

以下のいずれかに該当する場合は **プールモード** を使用する:
- 引数に `workers=N` が含まれている
- タスク数が 5 以上

それ以外は **通常モード**（1タスク=1ペイン）を使用する。

---

## 通常モード（1:1）

### Step 1: セッション準備

```bash
SESSION_ID=$(uuidgen)
SCRIPTS_DIR=".claude/scripts/tmux-agents"
```

タスクJSONを一時ファイルに書き出す:

```bash
mkdir -p tmp/parallel
TASKS_FILE="tmp/parallel/${SESSION_ID}-tasks.json"
cat > "$TASKS_FILE" << 'TASKS_EOF'
<ここにタスクJSON配列>
TASKS_EOF
```

### Step 2: 起動

```bash
bash "$SCRIPTS_DIR/launch.sh" "$TASKS_FILE" "$SESSION_ID"
```

### Step 3: バックグラウンド完了監視 + ユーザー案内

起動直後に、バックグラウンドで完了監視を開始する。
Bashツールの `run_in_background: true` を使うこと:

```bash
while ! bash "$SCRIPTS_DIR/status.sh" "$SESSION_ID" 2>/dev/null; do sleep 5; done && bash "$SCRIPTS_DIR/collect.sh" "$SESSION_ID"
```

その後、同じレスポンス内でユーザーに案内する:
- 右側のペインでClaude Codeが起動するので、権限承認が必要
- `Ctrl-b o` でペイン切り替え、`Ctrl-b q` でペイン番号確認
- 全タスク完了時に自動で結果を報告する

### Step 4: 完了待機

`TaskOutput` ツールで完了を待機する（`block: true`, `timeout: 600000`）。
ユーザーからの「戻ってきた」報告は不要。自動で検知する。

完了を検知したら結果をユーザーに報告する（collectの出力がTaskOutputに含まれる）。

### Step 5: クリーンアップ

```bash
bash "$SCRIPTS_DIR/cleanup.sh" "$SESSION_ID"
```

---

## プールモード（N:M ワーカープール）

タスク数 > ワーカー数のケースに対応。空いたワーカーに次のタスクをキューから自動配信する。

### Step 1: セッション準備

```bash
SESSION_ID=$(uuidgen)
SCRIPTS_DIR=".claude/scripts/tmux-agents"
```

引数から `workers=N` を抽出し、タスクJSONを一時ファイルに書き出す:

```bash
mkdir -p tmp/parallel
TASKS_FILE="tmp/parallel/${SESSION_ID}-tasks.json"
cat > "$TASKS_FILE" << 'TASKS_EOF'
<ここにタスクJSON配列>
TASKS_EOF
```

### Step 2: プール起動

```bash
bash "$SCRIPTS_DIR/launch-pool.sh" "$TASKS_FILE" "$SESSION_ID" <worker-count>
```

worker-count は `workers=N` の値。省略時は `min(タスク数, 4)`。

### Step 3: ディスパッチャー起動 + ユーザー案内

起動直後に、バックグラウンドでディスパッチャーを開始する。
Bashツールの `run_in_background: true` を使うこと:

```bash
bash "$SCRIPTS_DIR/dispatch.sh" "$SESSION_ID"
```

その後、同じレスポンス内でユーザーに案内する:
- 右側のペインでClaude Codeが起動するので、権限承認が必要
- `Ctrl-b o` でペイン切り替え、`Ctrl-b q` でペイン番号確認
- プールモード: N個のワーカーがM個のタスクを順次処理する
- 全タスク完了時に自動で結果を報告する

### Step 4: 完了待機

`TaskOutput` ツールで完了を待機する（`block: true`, `timeout: 600000`）。
dispatch.sh が完了時に collect.sh を自動実行するため、TaskOutput の出力にレポートが含まれる。

完了を検知したら結果をユーザーに報告する。

### Step 5: クリーンアップ

```bash
bash "$SCRIPTS_DIR/cleanup.sh" "$SESSION_ID"
```

---

## 注意事項

- `--dangerously-skip-permissions` は使わない。ユーザーが各ペインで権限承認する
- 通常モード推奨タスク数上限: 4（tmuxペインの視認性）
- プールモードのワーカー数上限: 4
- tmuxセッション内での実行が前提
- 子Claudeの作業結果は `summary.md` で受け取る
