#!/usr/bin/env bash
# Run any command inside the Godot build container, as the current user, with the repo mounted.
# Usage: tools/godot.sh godot --headless --path game --import
set -euo pipefail
cd "$(dirname "$0")/.."
exec docker run --rm -u "$(id -u):$(id -g)" -v "$PWD":/project crash-friend-godot "$@"
