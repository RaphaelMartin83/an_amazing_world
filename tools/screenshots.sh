#!/usr/bin/env bash
# Render preview screenshots (software Vulkan inside Docker, ~2 min) into build/shots/.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/shots
tools/godot.sh bash -c 'Xvfb :99 -screen 0 1280x720x24 -nolisten tcp >/dev/null 2>&1 & sleep 2; DISPLAY=:99 godot --path game --rendering-driver vulkan --resolution 1280x720 --fixed-fps 60 -- --shots 2>&1 | grep -E "saved|SCRIPT|belt:|FAIL"'
