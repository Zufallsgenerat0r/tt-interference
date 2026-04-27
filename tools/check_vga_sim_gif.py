#!/usr/bin/env python3
"""Build the repo-owned VGA simulator and verify it renders non-black frames."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = ROOT / "sim"
GIF_PATH = SIM_DIR / "output.gif"
WIDTH = 640
HEIGHT = 480
FRAMES = 12


def run(command: list[str], **kwargs) -> None:
    subprocess.run(command, check=True, **kwargs)


def frame_nonblack_counts(gif_path: Path) -> list[int]:
    raw = subprocess.check_output(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(gif_path),
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
    run(["make", "-C", str(SIM_DIR), f"GIF_FRAMES={FRAMES}", "gif"], env=env)

    counts = frame_nonblack_counts(GIF_PATH)
    if len(counts) != FRAMES:
        raise SystemExit(f"expected {FRAMES} frames, decoded {len(counts)}")
    if max(counts) < 1000:
        raise SystemExit(f"expected visible VGA output, got non-black counts {counts}")

    print(
        "vga_sim gif ok: "
        f"frames={len(counts)} nonblack_min={min(counts)} nonblack_max={max(counts)}"
    )


if __name__ == "__main__":
    main()
