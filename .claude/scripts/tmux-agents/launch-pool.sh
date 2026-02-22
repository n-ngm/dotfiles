#!/usr/bin/env bash
set -euo pipefail

# launch-pool.sh - ワーカープールモードの起動
# Usage: launch-pool.sh <tasks-json-file> <session-id> [worker-count]

TASKS_FILE="${1:?Usage: launch-pool.sh <tasks-json-file> <session-id> [worker-count]}"
SESSION_ID="${2:?Usage: launch-pool.sh <tasks-json-file> <session-id> [worker-count]}"

PROJECT_ROOT="$(pwd)"
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

# ワーカー数の決定: 引数 > min(task_count, 4)
if [ -n "${3:-}" ]; then
  WORKER_COUNT="$3"
else
  WORKER_COUNT=$((TASK_COUNT < 4 ? TASK_COUNT : 4))
fi

if [ "$WORKER_COUNT" -lt 1 ]; then
  echo "Error: Worker count must be at least 1" >&2
  exit 1
fi

if [ "$WORKER_COUNT" -gt 4 ]; then
  echo "Error: Maximum 4 workers supported (got $WORKER_COUNT)" >&2
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

  if [[ "$TASK_DIR" != /* ]]; then
    TASK_DIR="$PROJECT_ROOT/$TASK_DIR"
  fi

  if [ ! -d "$TASK_DIR" ]; then
    echo "Error: Directory not found for task '$TASK_ID': $TASK_DIR" >&2
    exit 1
  fi
done

# 全タスクのプロンプトファイル生成（作業ディレクトリ指示を追加）
for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_ID=$(jq -r ".[$i].id" "$TASKS_FILE")
  TASK_PROMPT=$(jq -r ".[$i].prompt" "$TASKS_FILE")
  TASK_DIR=$(jq -r ".[$i].dir" "$TASKS_FILE")

  if [[ "$TASK_DIR" != /* ]]; then
    TASK_DIR="$PROJECT_ROOT/$TASK_DIR"
  fi

  cat > "$STATUS_DIR/$TASK_ID.prompt.md" << PROMPT_EOF
$TASK_PROMPT

---

## 作業ディレクトリ

以下のディレクトリで作業してください: \`$TASK_DIR\`

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

# queue.json 初期化
PENDING_IDS=$(jq '[.[].id]' "$TASKS_FILE")
jq -n \
  --argjson pending "$PENDING_IDS" \
  '{pending: $pending, assigned: {}, completed: []}' \
  > "$STATUS_DIR/queue.json"

# 親ペインIDを記録
PARENT_PANE=$(tmux display-message -p '#{pane_id}')

# ワーカーペイン作成（launch.sh と同じレイアウト）
declare -a CHILD_PANES

# ワーカー1: 親ペインを右に分割（右側66%を子に）
CHILD_PANES[0]=$(tmux split-window -h -p 66 \
  -t "$PARENT_PANE" -c "$PROJECT_ROOT" \
  -P -F '#{pane_id}' \
  "bash '$SCRIPTS_DIR/pool-child.sh' '$STATUS_DIR' 'worker-0'")
tmux select-pane -t "${CHILD_PANES[0]}" -T "worker-0"

if [ "$WORKER_COUNT" -ge 2 ]; then
  CHILD_PANES[1]=$(tmux split-window -h -p 50 \
    -t "${CHILD_PANES[0]}" -c "$PROJECT_ROOT" \
    -P -F '#{pane_id}' \
    "bash '$SCRIPTS_DIR/pool-child.sh' '$STATUS_DIR' 'worker-1'")
  tmux select-pane -t "${CHILD_PANES[1]}" -T "worker-1"
fi

if [ "$WORKER_COUNT" -ge 3 ]; then
  CHILD_PANES[2]=$(tmux split-window -v -p 50 \
    -t "${CHILD_PANES[0]}" -c "$PROJECT_ROOT" \
    -P -F '#{pane_id}' \
    "bash '$SCRIPTS_DIR/pool-child.sh' '$STATUS_DIR' 'worker-2'")
  tmux select-pane -t "${CHILD_PANES[2]}" -T "worker-2"
fi

if [ "$WORKER_COUNT" -ge 4 ]; then
  CHILD_PANES[3]=$(tmux split-window -v -p 50 \
    -t "${CHILD_PANES[1]}" -c "$PROJECT_ROOT" \
    -P -F '#{pane_id}' \
    "bash '$SCRIPTS_DIR/pool-child.sh' '$STATUS_DIR' 'worker-3'")
  tmux select-pane -t "${CHILD_PANES[3]}" -T "worker-3"
fi

# 親ペインにフォーカスを戻す
tmux select-pane -t "$PARENT_PANE"

# session.json を保存（プールモード）
PANE_IDS_JSON=$(printf '%s\n' "${CHILD_PANES[@]}" | jq -R . | jq -s .)

# workers マップを構築
WORKERS_JSON="{}"
for i in $(seq 0 $((WORKER_COUNT - 1))); do
  PANE_ID="${CHILD_PANES[$i]}"
  WORKERS_JSON=$(echo "$WORKERS_JSON" | jq \
    --arg pane "$PANE_ID" \
    --arg wid "worker-$i" \
    '. + {($pane): {id: $wid, current_task: null, status: "idle"}}')
done

jq -n \
  --arg session_id "$SESSION_ID" \
  --arg project_root "$PROJECT_ROOT" \
  --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg parent_pane "$PARENT_PANE" \
  --argjson worker_count "$WORKER_COUNT" \
  --argjson task_count "$TASK_COUNT" \
  --argjson child_panes "$PANE_IDS_JSON" \
  --argjson workers "$WORKERS_JSON" \
  '{session_id: $session_id, project_root: $project_root, created_at: $created_at, mode: "pool", task_count: $task_count, worker_count: $worker_count, parent_pane: $parent_pane, child_panes: $child_panes, workers: $workers}' \
  > "$STATUS_DIR/session.json"

echo "Launched $WORKER_COUNT workers for $TASK_COUNT tasks (pool mode)"
echo "Session ID: $SESSION_ID"
echo "Status dir: $STATUS_DIR"
