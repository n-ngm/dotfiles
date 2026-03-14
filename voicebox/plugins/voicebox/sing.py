#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["requests"]
# ///
"""
VOICEVOX Singing Synthesis — sing via local VOICEVOX Engine.

Usage:
    # Sing "ド レ ミ" (C4 D4 E4)
    ./sing.py --notes "60:ド 62:レ 64:ミ"

    # With custom frame length and speaker
    ./sing.py --notes "60:ド:90 62:レ:90 64:ミ:90" --speaker 6000

    # From JSON score file
    ./sing.py --score score.json

Note format: KEY:LYRIC[:FRAME_LENGTH]
    KEY = MIDI note number (e.g. 60 = C4)
    LYRIC = Japanese lyric for the note
    FRAME_LENGTH = duration in frames (default: 45, ~0.48s at 93.75Hz)
"""

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile

import requests

VOICEVOX_HOST = "http://localhost:50021"
DEFAULT_FRAME_LENGTH = 45
SILENCE_FRAME_LENGTH = 15


def build_score(note_str: str) -> dict:
    """Parse 'KEY:LYRIC[:FRAME_LENGTH] ...' into a VOICEVOX score dict."""
    notes = [{"key": None, "frame_length": SILENCE_FRAME_LENGTH, "lyric": ""}]
    for token in note_str.split():
        parts = token.split(":")
        if len(parts) < 2:
            print(f"Warning: skipping invalid token '{token}' (expected KEY:LYRIC)", file=sys.stderr)
            continue
        key = int(parts[0])
        lyric = parts[1]
        frame_length = int(parts[2]) if len(parts) >= 3 else DEFAULT_FRAME_LENGTH
        notes.append({"key": key, "frame_length": frame_length, "lyric": lyric})
    notes.append({"key": None, "frame_length": SILENCE_FRAME_LENGTH, "lyric": ""})
    return {"notes": notes}


def synthesize_singing(score: dict, speaker: int) -> bytes | str:
    """Synthesize singing audio from a score. Returns WAV bytes or error string.

    sing_frame_audio_query and frame_synthesis may require different speaker IDs.
    This function uses the same speaker for both, but if sing_frame_audio_query fails,
    it falls back to using speaker 6000 (波音リツ) for the query step.
    """
    try:
        query_speaker = speaker
        resp = requests.post(
            f"{VOICEVOX_HOST}/sing_frame_audio_query",
            params={"speaker": query_speaker},
            headers={"Content-Type": "application/json"},
            data=json.dumps(score),
            timeout=30,
        )
        if not resp.ok:
            # Fallback: use speaker 6000 for query, target speaker for synthesis
            query_speaker = 6000
            resp = requests.post(
                f"{VOICEVOX_HOST}/sing_frame_audio_query",
                params={"speaker": query_speaker},
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
        return "Cannot connect to VOICEVOX Engine at " + VOICEVOX_HOST
    except Exception as e:
        return str(e)


def play(filepath: str) -> None:
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


def main():
    parser = argparse.ArgumentParser(description="VOICEVOX Singing Synthesis")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--notes", type=str, help="Notes in KEY:LYRIC[:FRAME_LENGTH] format")
    group.add_argument("--score", type=str, help="Path to JSON score file")
    parser.add_argument("--speaker", type=int, default=6000, help="Speaker ID (default: 6000)")
    parser.add_argument("--output", "-o", type=str, help="Save WAV to file instead of playing")
    parser.add_argument("--no-play", action="store_true", help="Don't play audio")
    args = parser.parse_args()

    if args.notes:
        score = build_score(args.notes)
    else:
        with open(args.score) as f:
            score = json.load(f)

    print(f"Synthesizing {len(score['notes'])} notes (speaker={args.speaker})...", file=sys.stderr)
    wav_data = synthesize_singing(score, args.speaker)

    if isinstance(wav_data, str):
        print(f"Error: {wav_data}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        with open(args.output, "wb") as f:
            f.write(wav_data)
        print(f"Saved to {args.output}", file=sys.stderr)
        if not args.no_play:
            play(args.output)
    else:
        tmpfile = None
        try:
            fd, tmpfile = tempfile.mkstemp(suffix=".wav", prefix=f"voicevox_sing.{os.getpid()}.")
            os.close(fd)
            with open(tmpfile, "wb") as f:
                f.write(wav_data)
            if not args.no_play:
                play(tmpfile)
            else:
                print(f"Generated: {tmpfile}", file=sys.stderr)
        finally:
            if tmpfile and os.path.exists(tmpfile) and not args.no_play:
                os.remove(tmpfile)


if __name__ == "__main__":
    main()
