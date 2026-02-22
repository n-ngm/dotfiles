#!/usr/bin/env bash
set -euo pipefail

# status.sh - ワンショットのステータス確認
# Usage: status.sh <session-id> [--logs]
# Exit 0: 全完了 / Exit 1: 進行中またはエラー

SESSION_ID="${1:?Usage: status.sh <session-id> [--logs]}"
SHOW_LOGS="${2:-}"

PROJECT_ROOT="$(pwd)"
STATUS_DIR="$PROJECT_ROOT/tmp/parallel/$SESSION_ID"

if [ ! -d "$STATUS_DIR" ]; then
  echo "Error: Status directory not found: $STATUS_DIR" >&2
  exit 2
fi

if [ ! -f "$STATUS_DIR/tasks.json" ]; then
  echo "Error: tasks.json not found in $STATUS_DIR" >&2
  exit 2
fi

TASK_COUNT=$(jq 'length' "$STATUS_DIR/tasks.json")
SESSION_FILE="$STATUS_DIR/session.json"

get_pane_id() {
  local index="$1"
  if [ -f "$SESSION_FILE" ]; then
    jq -r ".child_panes[$index] // empty" "$SESSION_FILE"
  fi
}

get_pane_tail() {
  local pane_id="$1"
  local lines="${2:-5}"
  if [ -n "$pane_id" ] && tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${pane_id}$"; then
    tmux capture-pane -t "$pane_id" -p -S -"$lines" 2>/dev/null | grep -v '^$' | tail -"$lines" | sed 's/^/  > /'
  fi
}

get_elapsed() {
  local task_id="$1"
  local started_file="$STATUS_DIR/$task_id.started_at"
  local finished_file="$STATUS_DIR/$task_id.finished_at"

  if [ ! -f "$started_file" ]; then
    echo "--:--"
    return
  fi

  local start_ts
  start_ts=$(cat "$started_file")

  local end_ts
  if [ -f "$finished_file" ]; then
    end_ts=$(cat "$finished_file")
  else
    end_ts=$(date +%s)
  fi

  local elapsed=$((end_ts - start_ts))
  printf "%02d:%02d" $((elapsed / 60)) $((elapsed % 60))
}

DONE_COUNT=0
ERROR_COUNT=0
RUNNING_COUNT=0
PENDING_COUNT=0

echo "=== Parallel Agents Status ==="
echo "Session: $SESSION_ID"
echo ""
printf "%-20s %-20s %-10s\n" "TASK" "STATUS" "ELAPSED"
printf "%-20s %-20s %-10s\n" "----" "------" "-------"

for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_ID=$(jq -r ".[$i].id" "$STATUS_DIR/tasks.json")
  STATUS_FILE="$STATUS_DIR/$TASK_ID.status"

  if [ -f "$STATUS_FILE" ]; then
    STATUS=$(cat "$STATUS_FILE")
  else
    STATUS="pending"
  fi

  # summary.md が存在するのに status が running なら done として扱う
  if [ "$STATUS" = "running" ] && [ -f "$STATUS_DIR/$TASK_ID.summary.md" ]; then
    STATUS="done"
  fi

  ELAPSED=$(get_elapsed "$TASK_ID")
  printf "%-20s %-20s %-10s\n" "$TASK_ID" "$STATUS" "$ELAPSED"

  case "$STATUS" in
    done|done-no-summary) DONE_COUNT=$((DONE_COUNT + 1)) ;;
    error:*)              ERROR_COUNT=$((ERROR_COUNT + 1)) ;;
    running)              RUNNING_COUNT=$((RUNNING_COUNT + 1)) ;;
    *)                    PENDING_COUNT=$((PENDING_COUNT + 1)) ;;
  esac

  # ペイン内容表示（runningは常に、それ以外は--logsオプション時のみ）
  if [ "$STATUS" = "running" ] || [ "$SHOW_LOGS" = "--logs" ]; then
    # プールモード: .workerファイルからペインIDを取得
    WORKER_FILE="$STATUS_DIR/$TASK_ID.worker"
    if [ -f "$WORKER_FILE" ]; then
      PANE_ID=$(cat "$WORKER_FILE")
    else
      PANE_ID=$(get_pane_id "$i")
    fi
    get_pane_tail "$PANE_ID" 3
  fi
done

echo ""
COMPLETED=$((DONE_COUNT + ERROR_COUNT))
echo "Progress: $COMPLETED / $TASK_COUNT (running: $RUNNING_COUNT, pending: $PENDING_COUNT, errors: $ERROR_COUNT)"

if [ "$COMPLETED" -eq "$TASK_COUNT" ]; then
  echo "Status: ALL COMPLETE"
  exit 0
else
  echo "Status: IN PROGRESS"
  exit 1
fi
