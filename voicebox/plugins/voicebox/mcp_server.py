#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp[cli]", "requests"]
# ///
"""
VOICEVOX MCP Server — text-to-speech via local VOICEVOX Engine.
"""

import json
import os
import platform
import shutil
import subprocess
import tempfile
import time

import requests
from mcp.server.fastmcp import FastMCP

VOICEVOX_HOST = "http://localhost:50021"

mcp = FastMCP("voicebox")


@mcp.tool()
def get_voices() -> str:
    """Get available voices from VOICEVOX."""
    try:
        resp = requests.get(f"{VOICEVOX_HOST}/speakers", timeout=10)
        resp.raise_for_status()
        return json.dumps(resp.json(), ensure_ascii=False)
    except requests.exceptions.ConnectionError:
        return "Error: Cannot connect to VOICEVOX Engine"
    except Exception as e:
        return f"Error: {e}"


@mcp.tool()
def text_to_speech(
    text: str,
    speaker_id: int = 1,
    speed: float = 1.3,
    auto_play: bool = True,
) -> str:
    """Convert text to speech using VOICEVOX and save to a file.

    Args:
        text: Text to convert to speech
        speaker_id: Speaker ID (voice). Default is 1.
        speed: Playback speed. Default is 1.3.
        auto_play: Whether to automatically play the generated audio. Default is True.
    """
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
        tmpfile = f"/tmp/voicevox.{os.getpid()}.{int(time.time() * 1000)}.wav"

    try:
        # Create audio query
        resp = requests.post(
            f"{VOICEVOX_HOST}/audio_query",
            params={"text": text, "speaker": speaker_id},
            timeout=10,
        )
        if not resp.ok:
            return f"Error: VOICEVOX audio_query failed: {resp.status_code}"

        query = resp.json()
        query["speedScale"] = speed

        # Synthesize audio
        resp = requests.post(
            f"{VOICEVOX_HOST}/synthesis",
            params={"speaker": speaker_id},
            headers={"Content-Type": "application/json"},
            data=json.dumps(query),
            timeout=30,
        )
        if not resp.ok:
            return f"Error: VOICEVOX synthesis failed: {resp.status_code}"

        # Save audio
        with open(tmpfile, "wb") as f:
            f.write(resp.content)

        # Play audio
        if auto_play:
            if platform.system() == "Darwin":
                subprocess.run(["afplay", tmpfile], check=False)
            else:
                for player in [
                    ["paplay", tmpfile],
                    ["aplay", tmpfile],
                    ["mpv", "--no-video", tmpfile],
                ]:
                    if shutil.which(player[0]):
                        subprocess.run(player, check=False)
                        break

        return json.dumps(
            {"status": "ok", "file": tmpfile, "played": auto_play},
            ensure_ascii=False,
        )

    except requests.exceptions.ConnectionError:
        return "Error: Cannot connect to VOICEVOX Engine"
    except Exception as e:
        return f"Error: {e}"
    finally:
        if tmpfile and os.path.exists(tmpfile):
            os.remove(tmpfile)


if __name__ == "__main__":
    mcp.run()
