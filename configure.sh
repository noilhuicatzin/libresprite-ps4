#!/usr/bin/env bash
# Configures the LibreSprite PS4 build in libresprite-ps4/build.
#
# PS4 adaptation:
#   GEN_ONLY=OFF             full app (gen itself is built for the host by
#                            build-gen-host.sh and copied into build/bin/
#                            below; the app's custom commands run it there)
#   USE_SDL2_BACKEND=ON      the she SDL2 backend (SDL_Renderer on the
#                            PS4 video driver) — the only backend on PS4
#   USE_SDL3_BACKEND=OFF     no SDL3 on PS4
#   ENABLE_TESTS=OFF         no unit tests on console
#   WITH_WEBP_SUPPORT=OFF    no libwebp on PS4 (the app works without it)
#   WITH_GTK_FILE_DIALOG_SUPPORT=OFF / WITH_DESKTOP_INTEGRATION=OFF /
#   WITH_QT_THUMBNAILER=OFF  desktop-only features, no meaning on PS4
#
# The find modules are pointed at prefix/ explicitly: the PS4 toolchain
# sets CMAKE_FIND_ROOT_PATH to prefix + toolchain, but the explicit cache
# values below make the result deterministic on the Windows runner.
# (FindSDL2/FindSDL2_IMAGE are the repo's own modules; the PS4 patch
# removes the REQUIRED pkg-config lookup that can never succeed here.)
#
# After configuring, the host-built gen.exe (staged by build-gen-host.sh
# at host-gen/gen.exe) is copied to build/bin/gen.exe, where the app's
# custom commands expect it. If it is missing, this script fails loudly
# instead of letting the PS4 build try to run a PS4 .elf as a generator.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"
W() { cygpath -m "$1"; }
P="$HERE/prefix"
cmake -G Ninja -S "$(W "$HERE/../libresprite")" -B "$(W "$HERE/build")" \
    -DCMAKE_TOOLCHAIN_FILE="$(W "$HERE/cmake/ps4-toolchain.cmake")" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_CXX_SCAN_FOR_MODULES=OFF \
    -DGEN_ONLY=OFF \
    -DUSE_SDL2_BACKEND=ON \
    -DUSE_SDL3_BACKEND=OFF \
    -DENABLE_TESTS=OFF \
    -DWITH_WEBP_SUPPORT=OFF \
    -DWITH_GTK_FILE_DIALOG_SUPPORT=OFF \
    -DWITH_DESKTOP_INTEGRATION=OFF \
    -DWITH_QT_THUMBNAILER=OFF \
    -DZLIB_INCLUDE_DIR="$(W "$P/include")" \
    -DZLIB_LIBRARY="$(W "$P/lib/libz.a")" \
    -DPNG_INCLUDE_DIR="$(W "$P/include")" \
    -DPNG_LIBRARY="$(W "$P/lib/libpng.a")" \
    -DJPEG_INCLUDE_DIR="$(W "$P/include")" \
    -DJPEG_LIBRARY="$(W "$P/lib/libjpeg.a")" \
    -DGIF_INCLUDE_DIR="$(W "$P/include")" \
    -DGIF_LIBRARY="$(W "$P/lib/libgif.a")" \
    -DFREETYPE_INCLUDE_DIR_ft2build="$(W "$P/include")" \
    -DFREETYPE_INCLUDE_DIR_freetype2="$(W "$P/include/freetype2")" \
    -DFREETYPE_LIBRARY="$(W "$P/lib/libfreetype.a")" \
    -DLibArchive_INCLUDE_DIR="$(W "$P/include")" \
    -DLibArchive_LIBRARY="$(W "$P/lib/libarchive.a")" \
    -DTINYXML2_INCLUDE_DIR="$(W "$P/include")" \
    -DTINYXML2_LIBRARY="$(W "$P/lib/libtinyxml2.a")" \
    -DPIXMAN_INCLUDE_DIR="$(W "$P/include/pixman-1")" \
    -DPIXMAN_LIBRARY="$(W "$P/lib/libpixman.a")" \
    -DSDL2_INCLUDE_DIR="$(W "$P/include/SDL2")" \
    -DSDL2_LIBRARY="$(W "$P/lib/libSDL2.a")" \
    -DSDL2_IMAGE_INCLUDE_DIR="$(W "$P/include/SDL2")" \
    -DSDL2_IMAGE_LIBRARY="$(W "$P/lib/libSDL2_image.a")" \
    "$@"

# Host gen.exe goes where the app's custom commands look for it.
if [ ! -f "$HERE/host-gen/gen.exe" ]; then
    echo "ERROR: host gen.exe not found at $HERE/host-gen/gen.exe — run build-gen-host.sh first"
    exit 1
fi
mkdir -p "$HERE/build/bin"
cp "$HERE/host-gen/gen.exe" "$HERE/build/bin/gen.exe"
echo "== host gen.exe staged at $HERE/build/bin/gen.exe"
