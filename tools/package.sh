#!/usr/bin/env bash
# Package the exported binaries into build/release/ (run tools/build.sh first):
#   AnAmazingWorld-<version>-windows-x86_64.zip
#   AnAmazingWorld-<version>-linux-x86_64.tar.gz   (keeps the executable bit)
#   SHA256SUMS.txt
# Usage: tools/package.sh <version>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: tools/package.sh <version>}"
WIN=build/windows/AnAmazingWorld.exe
LIN=build/linux/AnAmazingWorld.x86_64
for f in "$WIN" "$LIN"; do
	[[ -s "$f" ]] || { echo "error: $f is missing or empty - did the export fail?" >&2; exit 1; }
done

OUT=build/release
NAME="AnAmazingWorld-${VERSION}"
rm -rf "$OUT"
mkdir -p "$OUT"
(cd build/windows && zip -q -9 "../../$OUT/${NAME}-windows-x86_64.zip" AnAmazingWorld.exe)
tar -czf "$OUT/${NAME}-linux-x86_64.tar.gz" -C build/linux AnAmazingWorld.x86_64
(cd "$OUT" && sha256sum -- * > SHA256SUMS.txt)
ls -lh "$OUT"
