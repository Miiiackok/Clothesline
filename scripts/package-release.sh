#!/bin/bash
# Build terminal executables for both Mac architectures. No third-party build dependencies.
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:-0.1.0}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: scripts/package-release.sh 0.1.0" >&2
    exit 1
fi
mkdir -p dist
for arch in arm64 x86_64; do
    triple="${arch}-apple-macosx13.0"
    swift build -c release --triple "$triple" --product Clothesline
    bin_dir="$(swift build -c release --triple "$triple" --show-bin-path)"
    name="Clothesline-${version}-macOS-${arch}"
    stage="dist/$name"
    mkdir -p "$stage"
    cp "$bin_dir/Clothesline" "$stage/Clothesline"
    chmod 755 "$stage/Clothesline"
    # Ad-hoc signing preserves code integrity; this is NOT Developer ID signing or notarization.
    codesign --force --sign - "$stage/Clothesline"
    cp LICENSE "$stage/LICENSE"
    cp docs/QUICKSTART.txt "$stage/READ-ME.txt"
    ditto -c -k --keepParent "$stage" "dist/$name.zip"
done
(cd dist && shasum -a 256 ./*.zip > SHA256SUMS.txt)
echo "Packages and SHA256SUMS.txt are in dist/"
