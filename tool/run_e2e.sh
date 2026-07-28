#!/usr/bin/env bash
# Runs the end-to-end suite against a real device or simulator.
#
# These tests drive the assembled app: the real DI graph, the real Drift
# database on the device's filesystem, the real scheduler. They clear the
# database first, so pointing this at a device you use by hand will wipe the
# words on it.
#
# Usage:
#   tool/run_e2e.sh                 # first available device
#   tool/run_e2e.sh <device-id>     # a specific one (flutter devices)
set -euo pipefail

cd "$(dirname "$0")/.."

fvm_prefix=""
command -v fvm >/dev/null 2>&1 && fvm_prefix="fvm "

device="${1:-}"
if [[ -z "$device" ]]; then
  device=$(${fvm_prefix}flutter devices --machine \
    | grep -o '"id": *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//')
fi

if [[ -z "$device" ]]; then
  echo "✖ No device found. Boot a simulator or plug in a phone." >&2
  exit 1
fi

echo "▶ e2e on $device"
${fvm_prefix}flutter test integration_test/app_test.dart -d "$device"
