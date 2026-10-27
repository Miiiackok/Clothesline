#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build="$(mktemp -d "${TMPDIR:-/tmp}/ClotheslineRenderer.XXXXXX")"
trap 'rm -rf "$build"' EXIT
swiftc -emit-library -emit-module -module-name ClotheslineCore Sources/ClotheslineCore/*.swift \
    -o "$build/libClotheslineCore.dylib" -emit-module-path "$build/ClotheslineCore.swiftmodule"
swiftc -I "$build" -L "$build" -lClotheslineCore -Xlinker -rpath -Xlinker "$build" \
    Sources/Clothesline/Layout.swift Sources/Clothesline/Motion.swift \
    Sources/Clothesline/CardLayer.swift Sources/Clothesline/CardArt.swift \
    Sources/Clothesline/RopeLayer.swift tools/preview/main.swift -o "$build/preview"
"$build/preview" "${1:-docs/images}"
