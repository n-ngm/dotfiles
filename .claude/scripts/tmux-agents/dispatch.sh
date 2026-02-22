#!/usr/bin/env bash
set -euo pipefail

# dispatch.sh - ワーカープールのタスクディスパッチャー
# Usage: dispatch.sh <session-id> [poll-interval]
# バックグラウンドで実行し、ワーカーにタスクを配信する

SESSION_ID="${1:?Usage: dispatch.sh <session-id> [poll-interval]}"
POLL_INTERVAL="${2:-3}"

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUS_DIR="$PROJECT_ROOT/tmp/parallel/$SESSION_ID"
QUEUE_FILE="$STATUS_DIR/queue.json"
SESSION_FILE="$STATUS_DIR/session.json"

if [ ! -f "$QUEUE_FILE" ]; then
  echo "Error: queue.json not found: $QUEUE_FILE" >&2
  exit 1
fi

if [ ! -f "$SESSION_FILE" ]; then
  echo "Error: session.json not found: $SESSION_FILE" >&2
  exit 1
fi

# --- ヘルパー関数 ---

# キューからpendingの先頭タスクを取得（空なら空文字）
next_pending_task() {
  jq -r '.pending[0] // empty' "$QUEUE_FILE"
}

# タスクをpendingからassignedに移動
assign_task() {
  local task_id="$1"
  local pane_id="$2"
  local tmp_file="$QUEUE_FILE.tmp"
  jq \
    --arg tid "$task_id" \
    --arg pid "$pane_id" \
    '.pending = (.pending | map(select(. != $tid))) | .assigned[$tid] = $pid' \
    "$QUEUE_FILE" > "$tmp_file" && mv "$tmp_file" "$QUEUE_FILE"
}

# タスクをassignedからcompletedに移動
mark_complete() {
  local task_id="$1"
  local tmp_file="$QUEUE_FILE.tmp"
  jq \
    --arg tid "$task_id" \
    '.assigned = (.assigned | to_entries | map(select(.key != $tid)) | from_entries) | .completed += [$tid]' \
    "$QUEUE_FILE" > "$tmp_file" && mv "$tmp_file" "$QUEUE_FILE"
}

# タスクをassignedからcompletedに移動（エラー扱い）
mark_error() {
  local task_id="$1"
  # エラーもcompletedとして扱う（ステータスファイルでエラー情報を保持）
  mark_complete "$task_id"
  echo "error:worker-died" > "$STATUS_DIR/$task_id.status"
}

# ワーカーのclaude TUI起動を待機（❯ プロンプトを検知）
wait_for_ready() {
  local pane_id="$1"
  local timeout=30
  local elapsed=0

  while [ "$elapsed" -lt "$timeout" ]; do
    local content
    content=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null || echo "")
    if echo "$content" | grep -q '❯'; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  echo "Warning: Timed out waiting for claude TUI in pane $pane_id" >&2
  return 1
}

# ペインが生きているかチェック
is_pane_alive() {
  local pane_id="$1"
  tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${pane_id}$"
}

# タスクをワーカーに配信
dispatch_task() {
  local task_id="$1"
  local pane_id="$2"

  local prompt_file="$STATUS_DIR/$task_id.prompt.md"
  if [ ! -f "$prompt_file" ]; then
    echo "Error: Prompt file not found: $prompt_file" >&2
    return 1
  fi

  # .worker ファイルに配信先ペインIDを記録
  echo "$pane_id" > "$STATUS_DIR/$task_id.worker"

  # 開始タイムスタンプ
  date +%s > "$STATUS_DIR/$task_id.started_at"

  # ステータスマーク
  echo "running" > "$STATUS_DIR/$task_id.status"

  # session.json のワーカー状態を更新
  local tmp_session="$SESSION_FILE.tmp"
  jq \
    --arg pane "$pane_id" \
    --arg tid "$task_id" \
    '.workers[$pane].current_task = $tid | .workers[$pane].status = "busy"' \
    "$SESSION_FILE" > "$tmp_session" && mv "$tmp_session" "$SESSION_FILE"

  # tmux paste-buffer でプロンプトを送信
  tmux load-buffer -b dispatch "$prompt_file"
  tmux paste-buffer -b dispatch -t "$pane_id"
  sleep 0.5
  tmux send-keys -t "$pane_id" Enter

  echo "[dispatch] Task $task_id -> pane $pane_id"
}

# ワーカーのタスク完了を処理し、次のタスクを配信
handle_completion() {
  local task_id="$1"
  local pane_id="$2"

  # 完了タイムスタンプ
  date +%s > "$STATUS_DIR/$task_id.finished_at"

  # ステータスファイル更新
  if [ -f "$STATUS_DIR/$task_id.summary.md" ]; then
    echo "done" > "$STATUS_DIR/$task_id.status"
  else
    echo "done-no-summary" > "$STATUS_DIR/$task_id.status"
  fi

  # キュー更新
  mark_complete "$task_id"

  echo "[dispatch] Task $task_id completed"

  # session.json のワーカー状態を更新
  local tmp_session="$SESSION_FILE.tmp"
  jq \
    --arg pane "$pane_id" \
    '.workers[$pane].current_task = null | .workers[$pane].status = "idle"' \
    "$SESSION_FILE" > "$tmp_session" && mv "$tmp_session" "$SESSION_FILE"

  # 次のタスクがあれば配信
  local next_task
  next_task=$(next_pending_task)
  if [ -n "$next_task" ]; then
    # claude TUI が ❯ に戻るのを待機
    local ready_timeout=60
    local ready_elapsed=0
    while [ "$ready_elapsed" -lt "$ready_timeout" ]; do
      local content
      content=$(tmux capture-pane -t "$pane_id" -p -S -5 2>/dev/null || echo "")
      # 最後の数行に ❯ があればプロンプト待機状態
      if echo "$content" | tail -5 | grep -q '❯'; then
        break
      fi
      sleep 1
      ready_elapsed=$((ready_elapsed + 1))
    done

    assign_task "$next_task" "$pane_id"
    dispatch_task "$next_task" "$pane_id"
  fi
}

# --- メイン処理 ---

echo "[dispatch] Starting dispatcher for session $SESSION_ID"
echo "[dispatch] Poll interval: ${POLL_INTERVAL}s"

# ワーカーペインIDを取得
WORKER_PANES=$(jq -r '.child_panes[]' "$SESSION_FILE")

# Step 1: 全ワーカーのclaude TUI起動を待機
echo "[dispatch] Waiting for workers to be ready..."
for pane_id in $WORKER_PANES; do
  if wait_for_ready "$pane_id"; then
    echo "[dispatch] Worker pane $pane_id is ready"
  else
    echo "[dispatch] Worker pane $pane_id may not be ready, continuing anyway"
  fi
done

# Step 2: 初回配信 - 各ワーカーに1タスクずつ
echo "[dispatch] Initial task dispatch..."
for pane_id in $WORKER_PANES; do
  local_task=$(next_pending_task)
  if [ -z "$local_task" ]; then
    break
  fi
  assign_task "$local_task" "$pane_id"
  dispatch_task "$local_task" "$pane_id"
  sleep 0.5
done

# Step 3: メインループ - 完了監視とタスク配信
echo "[dispatch] Entering main loop..."
while true; do
  # assigned タスクをチェック
  ASSIGNED_TASKS=$(jq -r '.assigned | to_entries[] | "\(.key)=\(.value)"' "$QUEUE_FILE" 2>/dev/null || echo "")
  PENDING_COUNT=$(jq '.pending | length' "$QUEUE_FILE")
  ASSIGNED_COUNT=$(jq '.assigned | length' "$QUEUE_FILE")

  # 全完了チェック
  if [ "$PENDING_COUNT" -eq 0 ] && [ "$ASSIGNED_COUNT" -eq 0 ]; then
    echo "[dispatch] All tasks completed!"
    break
  fi

  # 各assigned タスクの完了チェック
  for entry in $ASSIGNED_TASKS; do
    task_id="${entry%%=*}"
    pane_id="${entry#*=}"

    # summary.md 出現チェック
    if [ -f "$STATUS_DIR/$task_id.summary.md" ]; then
      handle_completion "$task_id" "$pane_id"
      continue
    fi

    # ワーカーペイン死亡チェック
    if ! is_pane_alive "$pane_id"; then
      echo "[dispatch] Worker pane $pane_id died while running task $task_id"
      date +%s > "$STATUS_DIR/$task_id.finished_at"
      mark_error "$task_id"
    fi
  done

  sleep "$POLL_INTERVAL"
done

# Step 4: 結果収集
echo "[dispatch] Collecting results..."
bash "$SCRIPTS_DIR/collect.sh" "$SESSION_ID"
