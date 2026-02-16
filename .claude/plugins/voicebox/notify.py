#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["requests", "pyyaml"]
# ///
"""
VOICEVOX notification script (Desktop notification + Voice synthesis)
Usage: echo '{"hook_event_name":"Stop",...}' | notify.py
Dependencies:
  - Common: uv
  - macOS: terminal-notifier, afplay
  - Linux: notify-send, paplay/aplay/mpv

Supported hooks:
  - Stop: Task completion notification
  - Notification: User input waiting notification
"""

import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import requests
import yaml

VOICEVOX_HOST = "http://localhost:50021"
DEFAULT_SPEED = 1.3


SPEAKERS_DIR = Path(__file__).parent / "speakers"


def _read_settings_value(settings_path: Path, *keys: str):
    """Read a nested value from a settings JSON file."""
    if not settings_path.exists():
        return None
    try:
        with open(settings_path, "r", encoding="utf-8") as f:
            config = json.load(f)
        value = config
        for key in keys:
            if not isinstance(value, dict):
                return None
            value = value.get(key)
            if value is None:
                return None
        return value
    except (json.JSONDecodeError, KeyError):
        return None


def resolve_current_speaker(cwd: str | None) -> str:
    """Resolve current speaker name from settings.local.json files.

    Priority:
    1. {cwd}/.claude/settings.local.json
    2. ~/.claude/settings.local.json
    3. Default: "zundamon"
    """
    search_paths = []
    if cwd:
        search_paths.append(Path(cwd) / ".claude" / "settings.local.json")
    search_paths.append(Path.home() / ".claude" / "settings.local.json")

    for settings_path in search_paths:
        speaker = _read_settings_value(settings_path, "voicebox", "current_speaker")
        if speaker:
            return speaker
    return "zundamon"


def load_current_speaker_config(speaker_name: str) -> dict:
    """Load speaker configuration from speakers/{speaker_name}.yaml."""
    speaker_yaml = SPEAKERS_DIR / f"{speaker_name}.yaml"
    if speaker_yaml.exists():
        with open(speaker_yaml, "r", encoding="utf-8") as f:
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
        if parent_dir.startswith("-Users-") or parent_dir.startswith("-home-"):
            # e.g., -Users-myproject or -home-user-myproject -> myproject
            parts = parent_dir.split("-")[2:]
            if parts:
                return "/".join(parts)
    except Exception:
        pass

    return title


def extract_speaker_id_from_text(text: str) -> int | None:
    """Extract speaker_id from the last line if it matches 'speaker_id: <number>'."""
    lines = text.rstrip().split("\n")
    if lines:
        last_line = lines[-1].strip()
        match = re.match(r"^\(?speaker_id:\s*(\d+)\)?$", last_line)
        if match:
            return int(match.group(1))
    return None


def remove_speaker_id_line(text: str) -> str:
    """Remove the trailing speaker_id line from text."""
    lines = text.rstrip().split("\n")
    if lines:
        last_line = lines[-1].strip()
        if re.match(r"^\(?speaker_id:\s*\d+\)?$", last_line):
            return "\n".join(lines[:-1]).rstrip()
    return text


def extract_last_assistant_message(transcript_path: str) -> tuple[str | None, int | None]:
    """Extract first line of text and speaker_id from the last assistant message in transcript.

    Returns:
        tuple: (first_line_text, speaker_id_or_None)
    """
    if not transcript_path or not os.path.exists(transcript_path):
        return None, None

    try:
        with open(transcript_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        for line in reversed(lines):
            try:
                data = json.loads(line)
                if data.get("type") == "assistant":
                    content = data.get("message", {}).get("content", [])
                    # Find text block in content (may not be first element)
                    for block in content:
                        if block.get("type") == "text":
                            full_text = block.get("text", "").strip()
                            if not full_text:
                                continue
                            # Extract speaker_id from last line
                            speaker_id = extract_speaker_id_from_text(full_text)
                            # Remove speaker_id line before extracting message
                            clean_text = remove_speaker_id_line(full_text)
                            # Get first line only
                            first_line = clean_text.split("\n")[0]
                            if first_line:
                                return first_line, speaker_id
            except json.JSONDecodeError:
                continue
    except Exception:
        pass

    return None, None


def process_hook_message(
    hook_event: str,
    message: str | None,
    transcript_path: str | None,
    notifications: dict,
) -> str:
    """Process hook event and return appropriate message."""
    if hook_event == "Stop":
        if not message:
            message, _ = extract_last_assistant_message(transcript_path)
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
                question, _ = extract_last_assistant_message(transcript_path)
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
        if platform.system() == "Darwin":
            subprocess.run(["afplay", tmpfile], check=False)
        else:
            for player in [["paplay", tmpfile], ["aplay", tmpfile], ["mpv", "--no-video", tmpfile]]:
                if shutil.which(player[0]):
                    subprocess.run(player, check=False)
                    break

    except requests.exceptions.ConnectionError:
        print("Error: Cannot connect to VOICEVOX", file=sys.stderr)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
    finally:
        # Cleanup
        if tmpfile and os.path.exists(tmpfile):
            os.remove(tmpfile)


def show_notification(title: str, message: str) -> None:
    """Show desktop notification."""
    if platform.system() == "Darwin":
        subprocess.run(
            ["terminal-notifier", "-title", title, "-message", message, "-ignoreDnD"],
            check=False,
        )
    else:
        if shutil.which("notify-send"):
            subprocess.run(["notify-send", title, message], check=False)


def main():
    # Read JSON from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        input_data = {}

    # Debug log
    debug_log = Path("/tmp/voicebox-debug.log")
    with open(debug_log, "a", encoding="utf-8") as f:
        f.write(json.dumps(input_data, ensure_ascii=False, default=str) + "\n")

    hook_event = input_data.get("hook_event_name", "")
    message = input_data.get("message")
    transcript_path = input_data.get("transcript_path")
    cwd = input_data.get("cwd")

    # Load speaker config
    speaker_name = resolve_current_speaker(cwd)
    config = load_current_speaker_config(speaker_name)
    voicevox_speaker_id = get_default_speaker_id(config)
    speed = DEFAULT_SPEED
    notifications = config.get("notifications", {})

    # Extract speaker_id from transcript if available
    _, transcript_speaker_id = extract_last_assistant_message(transcript_path)
    if transcript_speaker_id is not None:
        voicevox_speaker_id = transcript_speaker_id

    # Process message
    text = process_hook_message(hook_event, message, transcript_path, notifications)

    # Get session title
    title = extract_session_title(transcript_path)

    # Show notification and play voice
    show_notification(title, text)
    synthesize_and_play(text, voicevox_speaker_id, speed)


if __name__ == "__main__":
    main()
