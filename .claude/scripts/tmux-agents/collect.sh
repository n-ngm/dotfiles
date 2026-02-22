#!/usr/bin/env bash
set -euo pipefail

# collect.sh - 全サマリをまとめて出力
# Usage: collect.sh <session-id>

SESSION_ID="${1:?Usage: collect.sh <session-id>}"

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STATUS_DIR="$PROJECT_ROOT/tmp/parallel/$SESSION_ID"

if [ ! -d "$STATUS_DIR" ]; then
  echo "Error: Status directory not found: $STATUS_DIR" >&2
  exit 1
fi

if [ ! -f "$STATUS_DIR/tasks.json" ]; then
  echo "Error: tasks.json not found in $STATUS_DIR" >&2
  exit 1
fi

TASK_COUNT=$(jq 'length' "$STATUS_DIR/tasks.json")

echo "# Parallel Agents Report"
echo ""
echo "Session: \`$SESSION_ID\`"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for i in $(seq 0 $((TASK_COUNT - 1))); do
  TASK_ID=$(jq -r ".[$i].id" "$STATUS_DIR/tasks.json")
  TASK_DIR=$(jq -r ".[$i].dir" "$STATUS_DIR/tasks.json")
  STATUS_FILE="$STATUS_DIR/$TASK_ID.status"
  SUMMARY_FILE="$STATUS_DIR/$TASK_ID.summary.md"
  PROMPT_FILE="$STATUS_DIR/$TASK_ID.prompt.md"
  STARTED_FILE="$STATUS_DIR/$TASK_ID.started_at"
  FINISHED_FILE="$STATUS_DIR/$TASK_ID.finished_at"

  echo "---"
  echo ""
  echo "## Task: $TASK_ID"
  echo ""
  echo "- **Directory**: \`$TASK_DIR\`"

  # ステータス
  if [ -f "$STATUS_FILE" ]; then
    echo "- **Status**: $(cat "$STATUS_FILE")"
  else
    echo "- **Status**: unknown"
  fi

  # 所要時間
  if [ -f "$STARTED_FILE" ] && [ -f "$FINISHED_FILE" ]; then
    START_TS=$(cat "$STARTED_FILE")
    END_TS=$(cat "$FINISHED_FILE")
    ELAPSED=$((END_TS - START_TS))
    MINUTES=$((ELAPSED / 60))
    SECS=$((ELAPSED % 60))
    echo "- **Duration**: ${MINUTES}m ${SECS}s"
  fi

  # 元プロンプト（冒頭5行）
  if [ -f "$PROMPT_FILE" ]; then
    echo ""
    echo "### Prompt (first 5 lines)"
    echo ""
    echo '```'
    head -5 "$PROMPT_FILE"
    echo '```'
  fi

  echo ""

  # サマリまたはペイン内容フォールバック
  if [ -f "$SUMMARY_FILE" ]; then
    echo "### Summary"
    echo ""
    cat "$SUMMARY_FILE"
  else
    # サマリがない場合、ペインのスクロールバックを取得
    SESSION_FILE="$STATUS_DIR/session.json"
    WORKER_FILE="$STATUS_DIR/$TASK_ID.worker"
    PANE_ID=""
    if [ -f "$WORKER_FILE" ]; then
      # プールモード: .workerファイルからペインIDを取得
      PANE_ID=$(cat "$WORKER_FILE")
    elif [ -f "$SESSION_FILE" ]; then
      PANE_ID=$(jq -r ".child_panes[$i] // empty" "$SESSION_FILE")
    fi
    if [ -n "$PANE_ID" ] && tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${PANE_ID}$"; then
      echo "### Pane output (no summary available)"
      echo ""
      echo '```'
      tmux capture-pane -t "$PANE_ID" -p -S - 2>/dev/null | grep -v '^$' | tail -20
      echo '```'
    else
      echo "*No summary available.*"
    fi
  fi

  echo ""
done

echo "---"
echo ""
echo "*End of report*"
