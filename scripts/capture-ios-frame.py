#!/usr/bin/env python3
"""Capture simulator frames requested by CurlPlanScreenshotUITests.

The UI test is compiled for the iOS simulator, so it cannot launch simctl.
It drops a JSON request in the watch directory; this host process takes the
framebuffer shot and writes the PNG the test is waiting on.
"""
import json
import re
import subprocess
import sys
import time
from pathlib import Path

UDID = sys.argv[1]
REQUESTS = Path(sys.argv[2])
REQUESTS.mkdir(parents=True, exist_ok=True)


def run(args):
    return subprocess.run(args, check=False, text=True, capture_output=True)


def booted():
    rows = []
    for line in run(["xcrun", "simctl", "list", "devices", "booted"]).stdout.splitlines():
        match = re.match(r"\s+(.*?) \(([A-F0-9-]{36})\)", line)
        if match:
            rows.append((match.group(1), match.group(2)))
    return rows


def capture_device():
    rows = booted()
    clones = [udid for name, udid in rows if "clone" in name.lower()]
    if clones:
        return clones[0]
    if any(udid == UDID for _, udid in rows):
        return UDID
    if len(rows) == 1:
        return rows[0][1]
    return UDID


def looks_like_ipad(device):
    listing = run(["xcrun", "simctl", "list", "devices"]).stdout
    return any(device in line and "iPad" in line for line in listing.splitlines())


def status_bar(device):
    # iPad draws the date beside the clock. Hiding it is the UIKit override;
    # an ISO time also replaces today's date when the hide preference is ignored.
    run([
        "xcrun", "simctl", "spawn", device, "defaults", "write",
        "com.apple.UIKit", "StatusBarHidesDate", "-bool", "YES",
    ])
    times = ["2007-01-09T09:41:00Z", "9:41"] if looks_like_ipad(device) else ["9:41"]
    tail = [
        "--dataNetwork", "wifi",
        "--wifiMode", "active",
        "--wifiBars", "3",
        "--cellularMode", "active",
        "--cellularBars", "4",
        "--batteryState", "charged",
        "--batteryLevel", "100",
    ]
    for time_value in times:
        base = ["xcrun", "simctl", "status_bar", device, "override", "--time", time_value, *tail]
        result = run(base + ["--operatorName", " "])
        if result.returncode != 0:
            result = run(base)
        if result.returncode == 0:
            print(f"status bar {time_value} on {device}", flush=True)
            return
        print(result.stderr, flush=True)
    print(f"status bar override failed for {device}", flush=True)


def handle(path: Path):
    try:
        request = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"skip {path.name}: {error}", flush=True)
        return
    device = capture_device()
    appearance = request.get("appearance")
    if appearance in ("light", "dark"):
        result = run(["xcrun", "simctl", "ui", device, "appearance", appearance])
        if result.returncode != 0:
            print(result.stderr, flush=True)
    status_bar(device)
    time.sleep(0.45)
    reply = Path(request["reply"])
    reply.parent.mkdir(parents=True, exist_ok=True)
    partial = reply.with_suffix(".partial")
    result = run(["xcrun", "simctl", "io", device, "screenshot", "--type=png", "--mask=black", str(partial)])
    print(f"shot {reply.name} via {device} -> {result.returncode}", flush=True)
    if result.returncode == 0:
        partial.replace(reply)
    else:
        reply.with_suffix(".err").write_text(result.stdout + result.stderr, encoding="utf-8")
        partial.unlink(missing_ok=True)
    path.unlink(missing_ok=True)


def main():
    deadline = time.time() + 800
    print(f"watching {REQUESTS} for {UDID}", flush=True)
    while time.time() < deadline:
        if (REQUESTS / "done").exists():
            break
        for path in sorted(REQUESTS.glob("*.json")):
            handle(path)
        time.sleep(0.15)
    print("capture watcher stopped", flush=True)


if __name__ == "__main__":
    main()
