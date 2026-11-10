#!/usr/bin/env bash
# Prepares the LibreSprite sources for the PS4 build.
#
# What it does (run from the libresprite-ps4 directory, i.e. this repo's root):
#   1. Clones LibreSprite at the pinned commit (GitHub) into
#      <workspace>/libresprite (sibling of libresprite-ps4).
#   2. Initializes the two submodules (third_party/simpleini, src/flic):
#      the checkout is useless without them and a plain clone leaves both
#      directories empty.
#   3. Verifies the PS4-relevant pieces exist in that commit (the X11 block
#      condition in CMakeLists.txt, src/app/resource_finder.cpp,
#      src/base/fs_unix.h, src/gen, cmake/FindSDL2.cmake and the vendored
#      third_party/pixman/CMakeLists.txt). If a future commit moves one of
#      them, this script fails loudly instead of silently building the
#      wrong thing.
#   4. Applies the four LibreSprite PS4 patches (idempotent): X11 block,
#      PS4 paths, FindSDL2 pkg-config, vendored pixman flags + install
#      rules. See patches/README.md for what each patch does and why.
#
# It is idempotent: if <workspace>/libresprite already exists it reuses it
# (deletes it first only if --clean is passed). It never downloads game or
# user data and never touches Piglet modules.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$HERE/.." && pwd)"
LIBRESPRITE_COMMIT="98f74431f5f523c747d278e3486625ccc7fc52cc"  # 2026-10-30

CLEAN=0
[ "${1:-}" = "--clean" ] && CLEAN=1

if [ "$CLEAN" = "1" ] && [ -d "$WORKSPACE/libresprite" ]; then
    echo "== removing existing $WORKSPACE/libresprite (--clean)"
    rm -rf "$WORKSPACE/libresprite"
fi

if [ ! -d "$WORKSPACE/libresprite" ]; then
    echo "== cloning LibreSprite at $LIBRESPRITE_COMMIT (GitHub)"
    git clone https://github.com/LibreSprite/LibreSprite.git "$WORKSPACE/libresprite"
    git -C "$WORKSPACE/libresprite" checkout -q "$LIBRESPRITE_COMMIT"
else
    echo "== reusing existing $WORKSPACE/libresprite"
    git -C "$WORKSPACE/libresprite" rev-parse --verify "$LIBRESPRITE_COMMIT^{commit}" >/dev/null 2>&1 \
        || { echo "ERROR: existing libresprite is not commit $LIBRESPRITE_COMMIT (use --clean)"; exit 1; }
fi

echo "== libresprite HEAD: $(git -C "$WORKSPACE/libresprite" rev-parse HEAD)"
echo "   (expected $LIBRESPRITE_COMMIT)"

echo "== initializing submodules (simpleini, flic)"
git -C "$WORKSPACE/libresprite" submodule update --init --recursive

echo "== checking PS4-relevant pieces exist in this commit"
grep -q "if(UNIX AND NOT APPLE AND NOT BEOS AND NOT GEN_ONLY)" "$WORKSPACE/libresprite/CMakeLists.txt" \
    || { echo "ERROR: X11 block condition not found in CMakeLists.txt"; exit 1; }
grep -q "pkg_search_module(SDL2 REQUIRED sdl2)" "$WORKSPACE/libresprite/cmake/FindSDL2.cmake" \
    || { echo "ERROR: pkg_search_module(SDL2 REQUIRED ...) not found in cmake/FindSDL2.cmake"; exit 1; }
for f in src/app/resource_finder.cpp src/base/fs_unix.h src/gen/CMakeLists.txt third_party/pixman/CMakeLists.txt data/icons/ase64.png; do
    [ -f "$WORKSPACE/libresprite/$f" ] \
        || { echo "ERROR: $f not found in libresprite $LIBRESPRITE_COMMIT"; exit 1; }
    echo "   OK: $f"
done

echo "== applying PS4 source patches (idempotent)"
for PATCH in "$HERE/patches/libresprite-ps4-x11.patch" "$HERE/patches/libresprite-ps4-paths.patch" "$HERE/patches/libresprite-ps4-find-sdl2-nopkgconfig.patch" "$HERE/patches/libresprite-ps4-pixman.patch"; do
    NAME="$(basename "$PATCH")"
    if git -C "$WORKSPACE/libresprite" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
        echo "   already applied: $NAME"
    else
        git -C "$WORKSPACE/libresprite" apply "$PATCH"
        echo "   applied: $NAME"
    fi
done

echo "== sources ready: $WORKSPACE/libresprite (4 PS4 patches applied)"
