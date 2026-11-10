#!/usr/bin/env bash
# Builds the host `gen` code generator for LibreSprite.
#
# Why this exists: the app's build runs ${CMAKE_BINARY_DIR}/bin/gen as a
# custom command (src/app/CMakeLists.txt) to generate widget/pref/skin
# headers from XML. That binary must RUN on the build machine, so it
# cannot be the PS4 cross-built one. The GEN_ONLY mode builds exactly
# that: gen + base-lib (+ clip/undo), with the host compiler, skipping
# every PS4 dependency (zlib, libarchive, SDL2, X11, ...). The only host
# dependency is tinyxml2 (find_library at the top of CMakeLists.txt is
# NOT guarded by GEN_ONLY), built here for the host into host-prefix/.
#
# Run AFTER scripts/prepare-sources.sh (it needs the LibreSprite tree)
# and AFTER build-deps.sh (it reuses deps/src/tinyxml2, cloning it if the
# deps step never ran). The resulting gen.exe is staged at
# libresprite-ps4/host-gen/gen.exe; configure.sh copies it into the PS4
# build dir (build/bin/gen.exe) before the PS4 build runs.
#
# Host compiler: the MinGW gcc that ships with Git Bash on windows-latest.
# No MSVC setup is needed; CMake + Ninja pick it up from PATH.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"
SRC="$HERE/deps/src"
HOST_PREFIX="$HERE/host-prefix"
W() { cygpath -m "$1"; }

if [ ! -d "$HERE/../libresprite" ]; then
    echo "ERROR: $HERE/../libresprite not found — run scripts/prepare-sources.sh first"
    exit 1
fi

# Host tinyxml2 (9.0.0, same pin as build-deps.sh).
if [ ! -d "$SRC/tinyxml2" ]; then
    echo "== cloning tinyxml2 9.0.0 for the host build"
    mkdir -p "$SRC"
    git -c advice.detachedHead=false clone -q --depth 1 --branch 9.0.0 \
        https://github.com/leethomason/tinyxml2.git "$SRC/tinyxml2"
fi
if [ ! -f "$HOST_PREFIX/lib/tinyxml2.a" ] && [ ! -f "$HOST_PREFIX/lib/tinyxml2.lib" ]; then
    echo "== building host tinyxml2"
    cmake -G Ninja -S "$(W "$SRC/tinyxml2")" -B "$(W "$HERE/host-build-tinyxml2")" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(W "$HOST_PREFIX")" \
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -Dtinyxml2_BUILD_TESTING=OFF > "$HERE/host-tinyxml2.configure.log" 2>&1 \
        || { tail -40 "$HERE/host-tinyxml2.configure.log"; exit 1; }
    cmake --build "$(W "$HERE/host-build-tinyxml2")" > "$HERE/host-tinyxml2.build.log" 2>&1 \
        || { tail -60 "$HERE/host-tinyxml2.build.log"; exit 1; }
    cmake --install "$(W "$HERE/host-build-tinyxml2")" > "$HERE/host-tinyxml2.install.log" 2>&1 \
        || { tail -40 "$HERE/host-tinyxml2.install.log"; exit 1; }
else
    echo "== host tinyxml2 (cached)"
fi

TINYXML2_LIB="$(ls "$HOST_PREFIX"/lib/libtinyxml2.a "$HOST_PREFIX"/lib/tinyxml2.lib 2>/dev/null | head -1)"
[ -n "$TINYXML2_LIB" ] || { echo "ERROR: host tinyxml2 library not found under $HOST_PREFIX/lib"; exit 1; }

echo "== configuring GEN_ONLY host build"
# NOTE: GEN_ONLY does NOT skip the SDL2/SDL2_image finds (they live in
# the "Platform specific stuff" section, guarded only by USE_SDL2_BACKEND,
# not by GEN_ONLY). gen itself never touches SDL, so both backends are
# OFF here — otherwise the host configure would demand an installed SDL2.
cmake -G Ninja -S "$(W "$HERE/../libresprite")" -B "$(W "$HERE/build-host")" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DGEN_ONLY=ON \
    -DUSE_SDL2_BACKEND=OFF \
    -DUSE_SDL3_BACKEND=OFF \
    -DTINYXML2_LIBRARY="$(W "$TINYXML2_LIB")" \
    -DTINYXML2_INCLUDE_DIR="$(W "$HOST_PREFIX/include")" \
    > "$HERE/host-gen.configure.log" 2>&1 \
    || { tail -40 "$HERE/host-gen.configure.log"; exit 1; }

echo "== building gen (host)"
cmake --build "$(W "$HERE/build-host")" --target gen > "$HERE/host-gen.build.log" 2>&1 \
    || { tail -60 "$HERE/host-gen.build.log"; exit 1; }

GEN_EXE="$HERE/build-host/bin/gen.exe"
[ -f "$GEN_EXE" ] || { echo "ERROR: host gen not produced at $GEN_EXE"; exit 1; }
mkdir -p "$HERE/host-gen"
cp "$GEN_EXE" "$HERE/host-gen/gen.exe"
ls -lh "$HERE/host-gen/gen.exe"
echo "HOST GEN OK: $HERE/host-gen/gen.exe"
