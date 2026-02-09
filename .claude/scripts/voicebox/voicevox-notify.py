#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["requests", "pyyaml"]
# ///
"""
VOICEVOX notification script (Desktop notification + Voice synthesis)
Usage: echo '{"hook_event_name":"Stop",...}' | voicevox-notify.py
Dependencies: uv, terminal-notifier, afplay

Supported hooks:
  - Stop: Task completion notification
  - Notification: User input waiting notification
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import requests
import yaml

SCRIPT_DIR = Path(__file__).parent
SPEAKERS_DIR = SCRIPT_DIR / "speakers"
CURRENT_SPEAKER_YAML = SPEAKERS_DIR / "current.yaml"
VOICEVOX_HOST = "http://localhost:50021"
DEFAULT_SPEED = 1.3


def load_current_speaker_config() -> dict:
    """Load current speaker configuration from speakers/current.yaml symlink."""
    if CURRENT_SPEAKER_YAML.exists():
        with open(CURRENT_SPEAKER_YAML, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)
            if config:
                return config
    # Default config
    return {
        "styles": [{"id": 1, "name": "ノーマル", "default": True}],
        "notifications": {
            "default": "通知",
            "task_complete": "タスク完了",
            "permission_needed": "許可が必要",
            "question": "質問がある",
            "tool_permission": "{tool}の許可が必要",
        },
    }


def get_default_speaker_id(config: dict) -> int:
    """Get the default style speaker_id from config."""
    styles = config.get("styles", [])
    for style in styles:
        if style.get("default"):
            return style.get("id", 1)
    # Fallback to first style
    if styles:
        return styles[0].get("id", 1)
    return 1


def extract_session_title(transcript_path: str) -> str:
    """Extract session title from transcript."""
    title = "Claude Code"
    if not transcript_path or not os.path.exists(transcript_path):
        return title

    try:
        # Read last 20 lines to find slug
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()[-20:]

        for line in reversed(lines):
            try:
                data = json.loads(line)
                if slug := data.get("slug"):
                    return slug
            except json.JSONDecodeError:
                continue

        # Fallback: extract project name from path
        parent_dir = os.path.basename(os.path.dirname(transcript_path))
        if parent_dir.startswith("-Users-"):
            # e.g., -Users-myproject -> myproject
            parts = parent_dir.split("-")[2:]
            if parts:
                return "/".join(parts)
    except Exception:
        pass

    return title


def extract_last_assistant_message(transcript_path: str) -> str | None:
    """Extract first line of text from the last assistant message in transcript."""
    if not transcript_path or not os.path.exists(transcript_path):
        return None

    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        for line in reversed(lines):
            try:
                data = json.loads(line)
                if data.get("type") == "assistant":
                    content = data.get("message", {}).get("content", [])
                    if content and content[0].get("type") == "text":
                        # Get first line only (matches shell's head -1)
                        text = content[0].get("text", "")
                        return text.split("\n")[0]
            except json.JSONDecodeError:
                continue
    except Exception:
        pass

    return None


def process_hook_message(
    hook_event: str,
    message: str | None,
    transcript_path: str | None,
    notifications: dict,
) -> str:
    """Process hook event and return appropriate message."""
    if hook_event == "Stop":
        if not message:
            message = extract_last_assistant_message(transcript_path)
        return message or notifications.get("task_complete", "タスク完了")

    elif hook_event == "Notification":
        if message:
            if message.startswith("Claude needs your permission to use"):
                tool = re.sub(r"^Claude needs your permission to use\s*", "", message)
                tool = tool.rstrip(".")
                template = notifications.get("tool_permission", "{tool}の許可が必要")
                return template.format(tool=tool)
            elif message.startswith("Claude is waiting"):
                # Skip notification
                sys.exit(0)
            elif message.startswith("Claude has a question"):
                return notifications.get("question", "質問がある")
            elif message.startswith("Claude wants to"):
                return notifications.get("permission_needed", "許可が必要")
            elif message.startswith("Claude Code needs your attention"):
                question = extract_last_assistant_message(transcript_path)
                return question or notifications.get("question", "質問がある")
            else:
                return message or notifications.get("permission_needed", "許可が必要")
        return notifications.get("permission_needed", "許可が必要")

    return message or notifications.get("default", "通知")


def synthesize_and_play(text: str, speaker_id: int, speed: float) -> None:
    """Synthesize speech using VOICEVOX and play it."""
    # Create temp file with retry
    tmpfile = None
    for _ in range(3):
        try:
            fd, tmpfile = tempfile.mkstemp(
                suffix=".wav", prefix=f"voicevox.{os.getpid()}."
            )
            os.close(fd)
            break
        except OSError:
            time.sleep(0.1)

    if not tmpfile:
        # Fallback
        tmpfile = f"/tmp/voicevox.{os.getpid()}.{int(time.time() * 1000)}.wav"

    try:
        # Create audio query
        response = requests.post(
            f"{VOICEVOX_HOST}/audio_query",
            params={"text": text, "speaker": speaker_id},
            timeout=10,
        )
        if not response.ok:
            print(f"Error: VOICEVOX audio_query failed: {response.status_code}", file=sys.stderr)
            return

        query = response.json()
        query["speedScale"] = speed

        # Synthesize audio
        response = requests.post(
            f"{VOICEVOX_HOST}/synthesis",
            params={"speaker": speaker_id},
            headers={"Content-Type": "application/json"},
            data=json.dumps(query),
            timeout=30,
        )
        if not response.ok:
            print(f"Error: VOICEVOX synthesis failed: {response.status_code}", file=sys.stderr)
            return

        # Save audio
        with open(tmpfile, "wb") as f:
            f.write(response.content)

        # Play audio
        subprocess.run(["afplay", tmpfile], check=False)

    except requests.exceptions.ConnectionError:
        print("Error: Cannot connect to VOICEVOX", file=sys.stderr)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
    finally:
        # Cleanup
        if tmpfile and os.path.exists(tmpfile):
            os.remove(tmpfile)


def show_notification(title: str, message: str) -> None:
    """Show desktop notification using terminal-notifier."""
    subprocess.run(
        ["terminal-notifier", "-title", title, "-message", message, "-ignoreDnD"],
        check=False,
    )


def main():
    # Read JSON from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        input_data = {}

    hook_event = input_data.get("hook_event_name", "")
    message = input_data.get("message")
    transcript_path = input_data.get("transcript_path")

    # Load speaker config
    config = load_current_speaker_config()
    voicevox_speaker_id = get_default_speaker_id(config)
    speed = DEFAULT_SPEED
    notifications = config.get("notifications", {})

    # Process message
    text = process_hook_message(hook_event, message, transcript_path, notifications)

    # Get session title
    title = extract_session_title(transcript_path)

    # Show notification and play voice
    show_notification(title, text)
    synthesize_and_play(text, voicevox_speaker_id, speed)


if __name__ == "__main__":
    main()
