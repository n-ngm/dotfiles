#!/usr/bin/env python3
"""VoiceBox setup script - Add hooks to Claude Code settings.json."""

import json
from pathlib import Path

SETTINGS_PATH = Path.home() / ".claude" / "settings.json"
NOTIFY_COMMAND = "~/.claude/scripts/voicebox/voicevox-notify.py"

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


def main():
    # Load existing settings
    if SETTINGS_PATH.exists():
        settings = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    else:
        settings = {}

    existing_hooks = settings.get("hooks", {})

    # Check if already installed
    for event, hook_list in HOOKS.items():
        entries = existing_hooks.get(event, [])
        already = any(
            NOTIFY_COMMAND in h.get("command", "")
            for entry in entries
            for h in entry.get("hooks", [])
        )
        if already:
            print(f"  {event}: already installed")
        else:
            entries.extend(hook_list)
            existing_hooks[event] = entries
            print(f"  {event}: added")

    settings["hooks"] = existing_hooks
    SETTINGS_PATH.write_text(
        json.dumps(settings, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"\nDone: {SETTINGS_PATH}")


if __name__ == "__main__":
    main()
