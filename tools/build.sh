#!/usr/bin/env bash
# Build everything inside Docker (nothing is installed on the host):
#   tools/build.sh          -> Docker image, self-test, Windows + Linux exports
#   tools/build.sh quick    -> skip the self-test
set -euo pipefail
cd "$(dirname "$0")/.."

docker build -t crash-friend-godot .

# import resources (creates game/.godot)
tools/godot.sh godot --headless --path game --import >/dev/null 2>&1 || true

if [[ "${1:-}" != "quick" ]]; then
	echo "== self-test (a bot plays both levels)"
	tools/godot.sh godot --headless --fixed-fps 60 --path game -- --selftest 2>&1 | grep -E "PASS|FAIL|finished|result"
fi

mkdir -p build/windows build/linux
echo "== exporting Windows"
tools/godot.sh godot --headless --path game --export-release "Windows Desktop" ../build/windows/AnAmazingWorld.exe >/dev/null 2>&1
echo "== exporting Linux"
tools/godot.sh godot --headless --path game --export-release "Linux" ../build/linux/AnAmazingWorld.x86_64 >/dev/null 2>&1

# a single zip to send to the friend
rm -f build/AnAmazingWorld-windows.zip
(cd build/windows && zip -q ../AnAmazingWorld-windows.zip AnAmazingWorld.exe)
ls -lh build/windows build/linux build/AnAmazingWorld-windows.zip
