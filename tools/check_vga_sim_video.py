#!/usr/bin/env python3
"""Build the VGA simulator and verify it renders a non-black MP4."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = ROOT / "sim"
VIDEO_PATH = SIM_DIR / "output.mp4"
WIDTH = 640
HEIGHT = 480
SECONDS = 2
FPS = 50


def run(command: list[str], **kwargs) -> None:
    subprocess.run(command, check=True, **kwargs)


def ffprobe_duration(video_path: Path) -> float:
    output = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(video_path),
        ],
        text=True,
    )
    return float(output.strip())


def video_nonblack_counts(video_path: Path) -> list[int]:
    raw = subprocess.check_output(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(video_path),
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "-",
        ]
    )
    frame_size = WIDTH * HEIGHT * 3
    counts: list[int] = []
    for offset in range(0, len(raw), frame_size):
        frame = raw[offset : offset + frame_size]
        if len(frame) != frame_size:
            break
        nonblack = sum(
            1
            for index in range(0, len(frame), 3)
            if frame[index : index + 3] != b"\x00\x00\x00"
        )
        counts.append(nonblack)
    return counts


def main() -> None:
    env = os.environ.copy()
    env["SDL_VIDEODRIVER"] = "dummy"

    run(["make", "-C", str(SIM_DIR), "clean"], env=env)
    run(
        [
            "make",
            "-C",
            str(SIM_DIR),
            f"VIDEO_SECONDS={SECONDS}",
            f"VIDEO_FPS={FPS}",
            "video",
        ],
        env=env,
    )

    duration = ffprobe_duration(VIDEO_PATH)
    if not (SECONDS - 0.1 <= duration <= SECONDS + 0.1):
        raise SystemExit(f"expected about {SECONDS}s video, got {duration:.3f}s")

    counts = video_nonblack_counts(VIDEO_PATH)
    if len(counts) < SECONDS * FPS * 0.9:
        raise SystemExit(f"expected roughly {SECONDS * FPS} frames, decoded {len(counts)}")
    if max(counts) < 1000:
        raise SystemExit(f"expected visible VGA output, got non-black counts {counts}")

    print(
        "vga_sim video ok: "
        f"duration={duration:.3f}s frames={len(counts)} "
        f"nonblack_min={min(counts)} nonblack_max={max(counts)}"
    )


if __name__ == "__main__":
    main()
