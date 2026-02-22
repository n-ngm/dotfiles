#!/usr/bin/env bash
set -euo pipefail

# monitor.sh - ポーリングで完了監視（ダッシュボード表示）
# Usage: monitor.sh <session-id> [poll-interval-seconds]

SESSION_ID="${1:?Usage: monitor.sh <session-id> [poll-interval-seconds]}"
POLL_INTERVAL="${2:-5}"

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

# カラーコード
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

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

get_status_display() {
  local status="$1"
  case "$status" in
    running)       echo -e "${BLUE}RUNNING${NC}" ;;
    done)          echo -e "${GREEN}DONE${NC}" ;;
    done-no-summary) echo -e "${YELLOW}DONE (no summary)${NC}" ;;
    error:*)       echo -e "${RED}ERROR ${status#error:}${NC}" ;;
    pending)       echo -e "${YELLOW}PENDING${NC}" ;;
    *)             echo -e "${YELLOW}UNKNOWN${NC}" ;;
  esac
}

while true; do
  clear

  echo -e "${BOLD}=== Claude Agents Dashboard ===${NC}"
  echo -e "Session: ${BLUE}$SESSION_ID${NC}"
  echo -e "Updated: $(date '+%H:%M:%S')"
  echo ""
  printf "${BOLD}%-20s %-25s %-10s${NC}\n" "TASK" "STATUS" "ELAPSED"
  printf "%-20s %-25s %-10s\n" "----" "------" "-------"

  DONE_COUNT=0
  ERROR_COUNT=0

  for i in $(seq 0 $((TASK_COUNT - 1))); do
    TASK_ID=$(jq -r ".[$i].id" "$STATUS_DIR/tasks.json")
    STATUS_FILE="$STATUS_DIR/$TASK_ID.status"

    if [ -f "$STATUS_FILE" ]; then
      STATUS=$(cat "$STATUS_FILE")
    else
      STATUS="pending"
    fi

    ELAPSED=$(get_elapsed "$TASK_ID")
    STATUS_DISPLAY=$(get_status_display "$STATUS")

    printf "%-20s %-25b %-10s\n" "$TASK_ID" "$STATUS_DISPLAY" "$ELAPSED"

    case "$STATUS" in
      done|done-no-summary) DONE_COUNT=$((DONE_COUNT + 1)) ;;
      error:*)              ERROR_COUNT=$((ERROR_COUNT + 1)) ;;
    esac
  done

  echo ""

  COMPLETED=$((DONE_COUNT + ERROR_COUNT))
  echo -e "Progress: ${BOLD}$COMPLETED / $TASK_COUNT${NC}"

  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${RED}Warning: $ERROR_COUNT task(s) had errors${NC}"
  fi

  if [ "$COMPLETED" -eq "$TASK_COUNT" ]; then
    echo ""
    echo -e "${GREEN}${BOLD}ALL COMPLETE${NC}"
    echo ""
    echo "Run collect.sh to gather results:"
    echo "  bash .claude/scripts/tmux-agents/collect.sh $SESSION_ID"
    exit 0
  fi

  sleep "$POLL_INTERVAL"
done
