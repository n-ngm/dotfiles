#!/usr/bin/env bash
set -euo pipefail

# launch.sh - tmuxウィンドウ+ペイン作成、子エージェント起動
# Usage: launch.sh <tasks-json-file> <session-id>

TASKS_FILE="${1:?Usage: launch.sh <tasks-json-file> <session-id>}"
SESSION_ID="${2:?Usage: launch.sh <tasks-json-file> <session-id>}"

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_DIR="$PROJECT_ROOT/tmp/parallel/$SESSION_ID"

# 前提チェック
for cmd in tmux jq claude; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed" >&2
    exit 1
  fi
done

if [ -z "${TMUX:-}" ]; then
  echo "Error: Not running inside a tmux session" >&2
  exit 1
fi

if [ ! -f "$TASKS_FILE" ]; then
  echo "Error: Tasks file not found: $TASKS_FILE" >&2
  exit 1
fi

# タスク数チェック
TASK_COUNT=$(jq 'length' "$TASKS_FILE")
if [ "$TASK_COUNT" -eq 0 ]; then
  echo "Error: No tasks defined" >&2
  exit 1
fi

# ステータスディレクトリ作成
mkdir -p "$STATUS_DIR"

# タスクJSONをステータスディレクトリにコピー
cp "$TASKS_FILE" "$STATUS_DIR/tasks.json"

# 各タスクのディレクトリ存在を検証
for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_ID=$(jq -r ".[$i].id" "$TASKS_FILE")
  TASK_DIR=$(jq -r ".[$i].dir" "$TASKS_FILE")

  # 相対パスの場合はプロジェクトルートからの絶対パスに変換
  if [[ "$TASK_DIR" != /* ]]; then
    TASK_DIR="$PROJECT_ROOT/$TASK_DIR"
  fi

  if [ ! -d "$TASK_DIR" ]; then
    echo "Error: Directory not found for task '$TASK_ID': $TASK_DIR" >&2
    exit 1
  fi
done

# 個別プロンプトファイルを書き出し
for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_ID=$(jq -r ".[$i].id" "$TASKS_FILE")
  TASK_PROMPT=$(jq -r ".[$i].prompt" "$TASKS_FILE")

  cat > "$STATUS_DIR/$TASK_ID.prompt.md" << PROMPT_EOF
$TASK_PROMPT

---

## 完了時の指示

作業が完了したら、以下のファイルにサマリを書き出してください:

\`$STATUS_DIR/$TASK_ID.summary.md\`

サマリには以下を含めてください:
- 実行した内容の概要
- 結果（成功/失敗）
- 変更したファイル一覧（あれば）
- 注意事項やエラー（あれば）

サマリを書き出したら、ユーザーに完了を報告してください。
PROMPT_EOF
done

# タスク数上限チェック
if [ "$TASK_COUNT" -gt 4 ]; then
  echo "Error: Maximum 4 tasks supported (got $TASK_COUNT)" >&2
  exit 1
fi

# タスク情報を配列に読み込み
declare -a TASK_IDS TASK_DIRS
for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_IDS[$i]=$(jq -r ".[$i].id" "$TASKS_FILE")
  TASK_DIRS[$i]=$(jq -r ".[$i].dir" "$TASKS_FILE")
  if [[ "${TASK_DIRS[$i]}" != /* ]]; then
    TASK_DIRS[$i]="$PROJECT_ROOT/${TASK_DIRS[$i]}"
  fi
done

# 親ペインIDを記録
PARENT_PANE=$(tmux display-message -p '#{pane_id}')

# レイアウト: 同じウィンドウ内で分割
#   2タスク:  |親|子1|子2|
#   3タスク:  |親|子1|子2|
#             |  |子3|   |
#   4タスク:  |親|子1|子2|
#             |  |子3|子4|

declare -a CHILD_PANES

# 子1: 親ペインを右に分割（右側66%を子に）
CHILD_PANES[0]=$(tmux split-window -h -p 66 \
  -t "$PARENT_PANE" -c "${TASK_DIRS[0]}" \
  -P -F '#{pane_id}' \
  "bash '$SCRIPTS_DIR/child.sh' '$STATUS_DIR' '${TASK_IDS[0]}' '${TASK_DIRS[0]}'")
tmux select-pane -t "${CHILD_PANES[0]}" -T "${TASK_IDS[0]}"

if [ "$TASK_COUNT" -ge 2 ]; then
  # 子2: 子1ペインを右に分割（右側50%）
  CHILD_PANES[1]=$(tmux split-window -h -p 50 \
    -t "${CHILD_PANES[0]}" -c "${TASK_DIRS[1]}" \
    -P -F '#{pane_id}' \
    "bash '$SCRIPTS_DIR/child.sh' '$STATUS_DIR' '${TASK_IDS[1]}' '${TASK_DIRS[1]}'")
  tmux select-pane -t "${CHILD_PANES[1]}" -T "${TASK_IDS[1]}"
fi

if [ "$TASK_COUNT" -ge 3 ]; then
  # 子3: 子1ペインを下に分割（下側50%）
  CHILD_PANES[2]=$(tmux split-window -v -p 50 \
    -t "${CHILD_PANES[0]}" -c "${TASK_DIRS[2]}" \
    -P -F '#{pane_id}' \
    "bash '$SCRIPTS_DIR/child.sh' '$STATUS_DIR' '${TASK_IDS[2]}' '${TASK_DIRS[2]}'")
  tmux select-pane -t "${CHILD_PANES[2]}" -T "${TASK_IDS[2]}"
fi

if [ "$TASK_COUNT" -ge 4 ]; then
  # 子4: 子2ペインを下に分割（下側50%）
  CHILD_PANES[3]=$(tmux split-window -v -p 50 \
    -t "${CHILD_PANES[1]}" -c "${TASK_DIRS[3]}" \
    -P -F '#{pane_id}' \
    "bash '$SCRIPTS_DIR/child.sh' '$STATUS_DIR' '${TASK_IDS[3]}' '${TASK_DIRS[3]}'")
  tmux select-pane -t "${CHILD_PANES[3]}" -T "${TASK_IDS[3]}"
fi

# 親ペインにフォーカスを戻す
tmux select-pane -t "$PARENT_PANE"

# セッション情報を保存（ペインIDを含む）
PANE_IDS_JSON=$(printf '%s\n' "${CHILD_PANES[@]}" | jq -R . | jq -s .)
jq -n \
  --arg session_id "$SESSION_ID" \
  --arg project_root "$PROJECT_ROOT" \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg parent_pane "$PARENT_PANE" \
  --argjson task_count "$TASK_COUNT" \
  --argjson child_panes "$PANE_IDS_JSON" \
  '{session_id: $session_id, project_root: $project_root, created_at: $created_at, task_count: $task_count, parent_pane: $parent_pane, child_panes: $child_panes}' \
  > "$STATUS_DIR/session.json"

echo "Launched $TASK_COUNT agents in current window"
echo "Session ID: $SESSION_ID"
echo "Status dir: $STATUS_DIR"
