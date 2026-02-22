#!/usr/bin/env bash
set -euo pipefail

# pool-child.sh - ワーカープール用の子ラッパー
# Usage: pool-child.sh <status-dir> <worker-id>
# claude をインタラクティブ起動し、dispatch.sh からのタスク配信を待つ

STATUS_DIR="${1:?Usage: pool-child.sh <status-dir> <worker-id>}"
WORKER_ID="${2:?Usage: pool-child.sh <status-dir> <worker-id>}"

echo "=== Worker: $WORKER_ID ==="
echo "=== Waiting for tasks... ==="
echo ""

# claude をインタラクティブ起動（引数なし）
# dispatch.sh が tmux paste-buffer でプロンプトを送信する
claude

echo ""
echo "=== Worker $WORKER_ID: Claude exited ==="
echo ""
echo "Press Enter to close this pane..."
read -r
