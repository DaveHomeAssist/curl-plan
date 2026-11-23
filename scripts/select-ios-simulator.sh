#!/usr/bin/env bash
# Pick or create an iOS 18 simulator under the active Xcode.
# Usage: select-ios-simulator.sh "Name A|Name B" "Create label"
# stdout: <udid><tab><matched device name>
# Diagnostics go to stderr. iOS 18 is required so Xcode 16.4 can boot the device.
set -euo pipefail

names=${1:?device names, separated by |}
label=${2:-CurlPlan Simulator}

runtime_line=$(xcrun simctl list runtimes available | grep -E 'iOS 18\.' | tail -1 || true)
if [ -z "$runtime_line" ]; then
  echo "No available iOS 18 runtime. Installed runtimes:" >&2
  xcrun simctl list runtimes >&2
  exit 1
fi

python3 - "$names" "$label" "$runtime_line" << 'PY'
import subprocess, sys, re

names = [part.strip() for part in sys.argv[1].split("|") if part.strip()]
label, runtime_line = sys.argv[2], sys.argv[3]
runtime_id = re.search(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9-]+", runtime_line)
header = re.match(r"iOS [0-9.]+", runtime_line.strip())
if not runtime_id or not header:
    sys.stderr.write(f"Could not parse runtime line: {runtime_line}\n")
    sys.exit(1)
runtime_id = runtime_id.group(0)
header = header.group(0)

raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available"], text=True)
section = None
found = {}
for line in raw.splitlines():
    marker = re.match(r"-- (.+) --", line.strip())
    if marker:
        section = marker.group(1)
        continue
    if section != header:
        continue
    device = re.match(r"\s+(.*?) \(([A-F0-9-]{36})\)", line)
    if device:
        found.setdefault(device.group(1), device.group(2))

for name in names:
    if name in found:
        sys.stderr.write(f"selected existing {name} {found[name]} on {header}\n")
        print(f"{found[name]}\t{name}")
        sys.exit(0)

types = subprocess.check_output(["xcrun", "simctl", "list", "devicetypes"], text=True)
identifiers = {}
for line in types.splitlines():
    match = re.match(r"(.+?) \((com\.apple\.CoreSimulator\.SimDeviceType\.[A-Za-z0-9-]+)\)\s*$", line.strip())
    if match:
        identifiers.setdefault(match.group(1), match.group(2))

for name in names:
    ident = identifiers.get(name)
    if not ident:
        continue
    created = subprocess.check_output(
        ["xcrun", "simctl", "create", label, ident, runtime_id], text=True
    ).strip()
    sys.stderr.write(f"created {name} {created} on {header}\n")
    print(f"{created}\t{name}")
    sys.exit(0)

sys.stderr.write("None of these device types are installed: " + ", ".join(names) + "\n")
sys.stderr.write(types + "\n")
sys.exit(1)
PY
