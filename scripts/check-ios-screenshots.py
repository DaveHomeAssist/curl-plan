#!/usr/bin/env python3
"""Check CurlPlan simulator PNGs for the required names and exact pixel size."""
import struct
import sys
from pathlib import Path

REVIEW = [
    "01-demo-gate.png",
    "02-passport.png",
    "03-locker-room.png",
    "04-spiels.png",
    "05-roster.png",
    "06-stop-detail.png",
    "07-curler-profile.png",
    "08-message-thread.png",
    "09-compose.png",
    "10-settings.png",
]
STORE = [
    "01-passport.png",
    "02-locker-room.png",
    "03-stop-detail.png",
    "04-curler-profile.png",
    "05-spiels.png",
    "06-roster.png",
    "07-compose.png",
]


def png_info(path: Path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"not a PNG: {path}")
    width, height = struct.unpack(">II", data[16:24])
    color = data[25]
    return width, height, color, len(data)


def main() -> None:
    root = Path(sys.argv[1])
    width, height = int(sys.argv[2]), int(sys.argv[3])
    store_dir = sys.argv[4]
    capture_review = sys.argv[5] == "true"

    expected = [f"{store_dir}/{name}" for name in STORE]
    if capture_review:
        for theme in ("light-ice", "dark-arena"):
            expected.extend(f"review/{theme}/{name}" for name in REVIEW)

    missing = []
    bad = []
    rows = []
    for relative in expected:
        path = root / relative
        if not path.is_file():
            missing.append(relative)
            continue
        got_w, got_h, color, size = png_info(path)
        rows.append(f"{got_w}x{got_h}\tcolor={color}\t{size}B\t{relative}")
        if (got_w, got_h) != (width, height) or size < 50000:
            bad.append(f"{relative}: {got_w}x{got_h} {size}B, expected {width}x{height}")

    print("\n".join(rows))
    if missing or bad:
        for item in missing:
            print(f"MISSING {item}", file=sys.stderr)
        for item in bad:
            print(f"BAD {item}", file=sys.stderr)
        sys.exit(1)
    print(f"OK {len(expected)} screenshots at {width}x{height}")


if __name__ == "__main__":
    main()
