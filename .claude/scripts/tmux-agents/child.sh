#!/usr/bin/env bash
set -euo pipefail

# child.sh - 子ラッパー（cd→claude起動→完了検知）
# Usage: child.sh <status-dir> <task-id> <task-dir>

STATUS_DIR="${1:?Usage: child.sh <status-dir> <task-id> <task-dir>}"
TASK_ID="${2:?Usage: child.sh <status-dir> <task-id> <task-dir>}"
TASK_DIR="${3:?Usage: child.sh <status-dir> <task-id> <task-dir>}"

PROMPT_FILE="$STATUS_DIR/$TASK_ID.prompt.md"
STATUS_FILE="$STATUS_DIR/$TASK_ID.status"
SUMMARY_FILE="$STATUS_DIR/$TASK_ID.summary.md"

# ディレクトリ移動
cd "$TASK_DIR"

# 開始タイムスタンプ
date +%s > "$STATUS_DIR/$TASK_ID.started_at"

# ステータスマーク
echo "running" > "$STATUS_FILE"

# プロンプト読み込み
PROMPT=$(cat "$PROMPT_FILE")

echo "=== Task: $TASK_ID ==="
echo "=== Dir:  $TASK_DIR ==="
echo "=== Starting Claude Code... ==="
echo ""

# claude起動（TUIモードで直接実行）
EXIT_CODE=0
claude "$PROMPT" || EXIT_CODE=$?

# 完了タイムスタンプ
date +%s > "$STATUS_DIR/$TASK_ID.finished_at"

# 完了検知
if [ $EXIT_CODE -ne 0 ]; then
  echo "error:$EXIT_CODE" > "$STATUS_FILE"
  echo ""
  echo "=== Task $TASK_ID: ERROR (exit code: $EXIT_CODE) ==="
elif [ -f "$SUMMARY_FILE" ]; then
  echo "done" > "$STATUS_FILE"
  echo ""
  echo "=== Task $TASK_ID: DONE (summary written) ==="
else
  echo "done-no-summary" > "$STATUS_FILE"
  echo ""
  echo "=== Task $TASK_ID: DONE (no summary) ==="
fi

# ペインを閉じずに待機（ユーザーが確認できるように）
echo ""
echo "Press Enter to close this pane..."
read -r
