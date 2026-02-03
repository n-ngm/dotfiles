#!/bin/bash
# VOICEVOX notification script (Desktop notification + Voice synthesis)
# Usage: echo '{"hook_event_name":"Stop",...}' | voicevox-notify.sh
# Dependencies: jq, terminal-notifier, curl, afplay
#
# Supported hooks:
#   - Stop: Task completion notification (reads last assistant message from transcript)
#   - Notification (idle_prompt): User input waiting notification

# Load speaker config from JSON file based on current_speaker.conf
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT_SPEAKER_CONF="${SCRIPT_DIR}/current_speaker.conf"

# Read speaker ID from conf file (default: 1)
if [ -f "$CURRENT_SPEAKER_CONF" ]; then
  SPEAKER_ID=$(cat "$CURRENT_SPEAKER_CONF" | tr -d '[:space:]')
fi
SPEAKER_ID="${SPEAKER_ID:-1}"

# Load speaker config JSON
SPEAKER_CONFIG="${SCRIPT_DIR}/speaker_$(printf '%03d' "$SPEAKER_ID").json"

if [ -f "$SPEAKER_CONFIG" ]; then
  SPEAKER=$(jq -r '.speaker_id // 1' "$SPEAKER_CONFIG")
  SPEED=$(jq -r '.speed // 1.3' "$SPEAKER_CONFIG")
else
  SPEAKER=1
  SPEED=1.3
fi

HOST="http://localhost:50021"

# Read JSON from stdin
INPUT=$(cat)

# Extract hook_event_name, message, and transcript_path
HOOK_EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# Extract session slug (custom name via /rename) for notification title
TITLE="Claude Code"
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
  SESSION_SLUG=$(tail -20 "$TRANSCRIPT_PATH" | jq -r '.slug // empty' 2>/dev/null | grep -v '^$' | tail -1)
  if [ -n "$SESSION_SLUG" ]; then
    TITLE="$SESSION_SLUG"
  else
    # Fallback: extract project name from path
    # e.g., ~/.claude/projects/-Users-myproject/xxx.jsonl -> myproject
    PROJECT_DIR=$(dirname "$TRANSCRIPT_PATH" | xargs basename | sed 's/^-Users-[^-]*-//' | sed 's/-/\//g')
    if [ -n "$PROJECT_DIR" ] && [ "$PROJECT_DIR" != "." ]; then
      TITLE="$PROJECT_DIR"
    fi
  fi
fi

# Handle different hook events
case "$HOOK_EVENT" in
  "Stop")
    # Task completion: extract first text from the last assistant message
    if [ -z "$MESSAGE" ] && [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
      MESSAGE=$(tac "$TRANSCRIPT_PATH" | \
        jq -r 'select(.type == "assistant") | .message.content[0] | select(.type == "text") | .text' 2>/dev/null | \
        head -1 | \
        cut -c1-100)
      MESSAGE="${MESSAGE:-タスク完了なのだ}"
    fi
    ;;
  "Notification")
    # Permission prompt notification: convert English system messages to Zundamon style
    if [ -n "$MESSAGE" ]; then
      case "$MESSAGE" in
        "Claude needs your permission to use"*)
          # Extract tool name
          TOOL=$(echo "$MESSAGE" | sed 's/Claude needs your permission to use //' | sed 's/\.$//')
          MESSAGE="${TOOL}の許可がほしいのだ"
          ;;
        "Claude is waiting"*)
          # Skip notification
          exit 0
          ;;
        "Claude has a question"*)
          MESSAGE="質問があるのだ"
          ;;
        "Claude wants to"*)
          MESSAGE="許可が必要なのだ"
          ;;
        "Claude Code needs your attention"*)
          # AskUserQuestion: extract question from transcript
          if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
            QUESTION=$(tac "$TRANSCRIPT_PATH" | \
              jq -r 'select(.type == "assistant") | .message.content[0] | select(.type == "text") | .text' 2>/dev/null | \
              head -1 | \
              cut -c1-100)
            MESSAGE="${QUESTION:-質問があるのだ}"
          else
            MESSAGE="質問があるのだ"
          fi
          ;;
        *)
          # Keep original or use default for unknown messages
          MESSAGE="${MESSAGE:-許可が必要なのだ}"
          ;;
      esac
    else
      MESSAGE="許可が必要なのだ"
    fi
    ;;
  *)
    # Other notifications
    MESSAGE="${MESSAGE:-${1:-通知なのだ}}"
    ;;
esac

TEXT="${MESSAGE:-通知なのだ}"

# Temp file for audio
TMPFILE=$(mktemp -p /tmp voicevox.XXXXXX.wav)
trap "rm -f $TMPFILE" EXIT

# URL encode the text
ENCODED=$(echo -n "$TEXT" | jq -sRr '@uri')

# Create audio query
QUERY=$(curl -s -X POST "${HOST}/audio_query?text=${ENCODED}&speaker=${SPEAKER}")

if [ -z "$QUERY" ]; then
  echo "Error: Cannot connect to VOICEVOX" >&2
  exit 1
fi

# Adjust speech speed
QUERY=$(echo "$QUERY" | jq ".speedScale = ${SPEED}")

# Synthesize audio and save to temp file
curl -s -X POST "${HOST}/synthesis?speaker=${SPEAKER}" \
  -H "Content-Type: application/json" \
  -d "$QUERY" -o "$TMPFILE"

# Desktop notification with session name as title
terminal-notifier -title "$TITLE" -message "$TEXT" -ignoreDnD

# Play audio
afplay "$TMPFILE"
