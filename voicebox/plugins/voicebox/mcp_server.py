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
import threading
import time
from typing import List

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
    wav_data = _synthesize(text, speaker_id, speed)
    if isinstance(wav_data, str):
        return f"Error: {wav_data}"

    tmpfile = None
    try:
        fd, tmpfile = tempfile.mkstemp(
            suffix=".wav", prefix=f"voicevox.{os.getpid()}."
        )
        os.close(fd)
        with open(tmpfile, "wb") as f:
            f.write(wav_data)

        if auto_play:
            _play(tmpfile)

        return "ok"
    except Exception as e:
        return f"Error: {e}"
    finally:
        if tmpfile and os.path.exists(tmpfile):
            os.remove(tmpfile)


def _synthesize(text: str, speaker_id: int, speed: float) -> bytes | str:
    """Synthesize a single text and return WAV bytes, or an error string."""
    try:
        resp = requests.post(
            f"{VOICEVOX_HOST}/audio_query",
            params={"text": text, "speaker": speaker_id},
            timeout=10,
        )
        if not resp.ok:
            return f"audio_query failed: {resp.status_code}"
        query = resp.json()
        query["speedScale"] = speed
        resp = requests.post(
            f"{VOICEVOX_HOST}/synthesis",
            params={"speaker": speaker_id},
            headers={"Content-Type": "application/json"},
            data=json.dumps(query),
            timeout=30,
        )
        if not resp.ok:
            return f"synthesis failed: {resp.status_code}"
        return resp.content
    except requests.exceptions.ConnectionError:
        return "Cannot connect to VOICEVOX Engine"
    except Exception as e:
        return str(e)


def _play(filepath: str) -> None:
    """Play a WAV file using the platform's player."""
    if platform.system() == "Darwin":
        subprocess.run(["afplay", filepath], check=False)
    else:
        for player in [
            ["paplay", filepath],
            ["aplay", filepath],
            ["mpv", "--no-video", filepath],
        ]:
            if shutil.which(player[0]):
                subprocess.run(player, check=False)
                break


@mcp.tool()
def sing(
    score: dict,
    speaker_id: int = 6000,
    auto_play: bool = True,
) -> str:
    """Synthesize singing voice from a musical score using VOICEVOX.

    Args:
        score: Musical score dict with "notes" list.
               Each note: {"key": MIDI_NUMBER|null, "frame_length": int, "lyric": str}
               - key: MIDI note number (60=C4). null for silence.
               - frame_length: Duration in frames (93.75Hz). 45≈0.48s.
               - lyric: Single kana character per note. Empty string for silence.
               First and last notes should be silence (key=null).
        speaker_id: Singer ID for synthesis. Default is 6000.
        auto_play: Whether to automatically play the generated audio. Default is True.
    """
    wav_data = _synthesize_singing(score, speaker_id)
    if isinstance(wav_data, str):
        return f"Error: {wav_data}"

    tmpfile = None
    try:
        fd, tmpfile = tempfile.mkstemp(
            suffix=".wav", prefix=f"voicevox_sing.{os.getpid()}."
        )
        os.close(fd)
        with open(tmpfile, "wb") as f:
            f.write(wav_data)

        if auto_play:
            _play(tmpfile)

        return "ok"
    except Exception as e:
        return f"Error: {e}"
    finally:
        if tmpfile and os.path.exists(tmpfile):
            os.remove(tmpfile)


def _synthesize_singing(score: dict, speaker: int) -> bytes | str:
    """Synthesize singing audio from a score. Returns WAV bytes or error string."""
    try:
        resp = requests.post(
            f"{VOICEVOX_HOST}/sing_frame_audio_query",
            params={"speaker": speaker},
            headers={"Content-Type": "application/json"},
            data=json.dumps(score),
            timeout=30,
        )
        if not resp.ok:
            # Fallback: use speaker 6000 for query, target speaker for synthesis
            resp = requests.post(
                f"{VOICEVOX_HOST}/sing_frame_audio_query",
                params={"speaker": 6000},
                headers={"Content-Type": "application/json"},
                data=json.dumps(score),
                timeout=30,
            )
            if not resp.ok:
                return f"sing_frame_audio_query failed: {resp.status_code} {resp.text[:200]}"
        query = resp.json()

        resp = requests.post(
            f"{VOICEVOX_HOST}/frame_synthesis",
            params={"speaker": speaker},
            headers={"Content-Type": "application/json"},
            data=json.dumps(query),
            timeout=60,
        )
        if not resp.ok:
            return f"frame_synthesis failed: {resp.status_code} {resp.text[:200]}"
        return resp.content
    except requests.exceptions.ConnectionError:
        return "Cannot connect to VOICEVOX Engine"
    except Exception as e:
        return str(e)


@mcp.tool()
def text_to_speech_batch(
    texts: List[str],
    speaker_id: int = 1,
    speed: float = 1.3,
    auto_play: bool = True,
) -> str:
    """Convert multiple texts to speech and play them seamlessly.

    Synthesizes the next audio while the current one is playing (pipeline),
    so there is almost no gap between sentences.

    Args:
        texts: List of texts to convert to speech.
        speaker_id: Speaker ID (voice). Default is 1.
        speed: Playback speed. Default is 1.3.
        auto_play: Whether to automatically play the generated audio. Default is True.
    """
    if not texts:
        return "ok"

    errors = []
    tmpfiles = []

    try:
        wav_data = _synthesize(texts[0], speaker_id, speed)

        for i in range(len(texts)):
            if isinstance(wav_data, str):
                errors.append(f"[{i}] Error: {wav_data}")
                wav_data = None
            else:
                # Save current audio to temp file
                fd, tmpfile = tempfile.mkstemp(
                    suffix=".wav", prefix=f"voicevox.{os.getpid()}."
                )
                os.close(fd)
                tmpfiles.append(tmpfile)
                with open(tmpfile, "wb") as f:
                    f.write(wav_data)

            # Pipeline: start synthesizing next while playing current
            next_result = [None]
            if i + 1 < len(texts):
                def synth_next(text=texts[i + 1]):
                    next_result[0] = _synthesize(text, speaker_id, speed)
                synth_thread = threading.Thread(target=synth_next)
                synth_thread.start()

            # Play current
            if auto_play and not isinstance(wav_data, (str, type(None))):
                _play(tmpfile)

            # Wait for next synthesis to finish
            if i + 1 < len(texts):
                synth_thread.join()
                wav_data = next_result[0]

        if errors:
            return "partial errors: " + "; ".join(errors)
        return "ok"

    except Exception as e:
        return f"Error: {e}"
    finally:
        for f in tmpfiles:
            if os.path.exists(f):
                os.remove(f)


if __name__ == "__main__":
    mcp.run()
