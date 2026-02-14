#!/usr/bin/env python3
"""VoiceBox setup script - Add hooks to settings.json and speakers_dir to settings.local.json."""

import json
from pathlib import Path

SETTINGS_PATH = Path.home() / ".claude" / "settings.json"
LOCAL_SETTINGS_PATH = Path.home() / ".claude" / "settings.local.json"
NOTIFY_COMMAND = "~/.claude/plugins/voicebox/voicevox-notify.py"
DEFAULT_SPEAKERS_DIR = "~/.claude/plugins/voicebox/speakers"

HOOKS = {
    "Notification": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": NOTIFY_COMMAND}
            ],
        }
    ],
    "Stop": [
        {
            "matcher": "",
            "hooks": [
                {"type": "command", "command": NOTIFY_COMMAND}
            ],
        }
    ],
}


def setup_hooks():
    """Add hooks to settings.json."""
    if SETTINGS_PATH.exists():
        settings = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    else:
        settings = {}

    existing_hooks = settings.get("hooks", {})

    for event, hook_list in HOOKS.items():
        entries = existing_hooks.get(event, [])
        already = any(
            NOTIFY_COMMAND in h.get("command", "")
            for entry in entries
            for h in entry.get("hooks", [])
        )
        if already:
            print(f"  hooks/{event}: already installed")
        else:
            entries.extend(hook_list)
            existing_hooks[event] = entries
            print(f"  hooks/{event}: added")

    settings["hooks"] = existing_hooks
    SETTINGS_PATH.write_text(
        json.dumps(settings, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def setup_speakers_dir():
    """Set voicebox.speakers_dir in settings.local.json."""
    if LOCAL_SETTINGS_PATH.exists():
        local_settings = json.loads(LOCAL_SETTINGS_PATH.read_text(encoding="utf-8"))
    else:
        local_settings = {}

    voicebox = local_settings.get("voicebox", {})
    if voicebox.get("speakers_dir"):
        print(f"  speakers_dir: already set ({voicebox['speakers_dir']})")
    else:
        voicebox["speakers_dir"] = DEFAULT_SPEAKERS_DIR
        local_settings["voicebox"] = voicebox
        print(f"  speakers_dir: {DEFAULT_SPEAKERS_DIR}")

    LOCAL_SETTINGS_PATH.write_text(
        json.dumps(local_settings, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def main():
    print("VoiceBox setup")
    print()
    setup_hooks()
    setup_speakers_dir()
    print(f"\nDone: {SETTINGS_PATH}, {LOCAL_SETTINGS_PATH}")


if __name__ == "__main__":
    main()
