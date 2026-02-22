#!/usr/bin/env bash
set -euo pipefail

# cleanup.sh - tmuxウィンドウ削除+一時ファイル削除
# Usage: cleanup.sh <session-id>

SESSION_ID="${1:?Usage: cleanup.sh <session-id>}"

PROJECT_ROOT="$(pwd)"
STATUS_DIR="$PROJECT_ROOT/tmp/parallel/$SESSION_ID"

# 安全ガード: tmp/parallel 配下のみ削除可能
SAFE_PREFIX="$PROJECT_ROOT/tmp/parallel/"
if [[ "$STATUS_DIR" != "$SAFE_PREFIX"* ]]; then
  echo "Error: Refusing to delete outside of tmp/parallel/" >&2
  exit 1
fi

# 子ペインを削除（session.jsonからペインIDを読み取り）
SESSION_FILE="$STATUS_DIR/session.json"
if [ -f "$SESSION_FILE" ]; then
  PANE_COUNT=$(jq '.child_panes | length' "$SESSION_FILE" 2>/dev/null || echo "0")
  KILLED=0
  for i in $(seq 0 $((PANE_COUNT - 1))); do
    PANE_ID=$(jq -r ".child_panes[$i]" "$SESSION_FILE")
    if tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -q "^${PANE_ID}$"; then
      tmux kill-pane -t "$PANE_ID"
      KILLED=$((KILLED + 1))
    fi
  done
  echo "Killed $KILLED child pane(s)"
else
  echo "No session.json found, skipping pane cleanup"
fi

# ステータスディレクトリ削除
if [ -d "$STATUS_DIR" ]; then
  rm -rf "$STATUS_DIR"
  echo "Removed status directory: $STATUS_DIR"
else
  echo "Status directory not found (already cleaned?): $STATUS_DIR"
fi

# タスクJSONファイル削除（launch.sh起動前に親が作成したもの）
TASKS_FILE="$PROJECT_ROOT/tmp/parallel/${SESSION_ID}-tasks.json"
if [ -f "$TASKS_FILE" ]; then
  rm -f "$TASKS_FILE"
  echo "Removed tasks file: $TASKS_FILE"
fi

echo "Cleanup complete for session: $SESSION_ID"
