#!/usr/bin/env bash
# Cross-builds every third-party dependency of LibreSprite for PS4 into libresprite-ps4/prefix.
#
# Dependency map (see ESTUDIO.md in ~/workspace/libresprite-estudio/):
#   - zlib, libpng, freetype: already proven for PS4 by the Solarus port
#     (same pins, same flags).
#   - libjpeg-turbo: LibreSprite links libjpeg directly (find_package(JPEG)
#     for JPG load/save). Built static, no SIMD (no nasm on the runner,
#     and the PS4 target is x86_64 with no SSE assumptions in this build).
#   - giflib: GIF load/save (find_package(GIF)). Ships no CMakeLists, so it
#     is built with the giflib-cmake wrapper below (same pattern as
#     lua-cmake/zlib-cmake in the Solarus port). Tarball, not git: the
#     upstream git lives on SourceForge/GitLab and is awkward to clone from
#     the runner; the Debian pool carries the same pristine 5.2.2 tarball.
#   - tinyxml2: XML used by gen and the app (find_library tinyxml2).
#   - libarchive: .aseprite file bundles / zip handling (find_package
#     (LibArchive)). Built with every optional backend OFF except zlib.
#   - SDL 2.0.18 from PacBrew/SDL branch ps4 (NOT upstream SDL): the fork
#     with the PS4 video driver (Piglet GLES 2.0), the PS4 audio driver and
#     the PS4 joystick driver. Same pins, patches and flags as Solarus.
#   - SDL2_image: from upstream libsdl-org (STB backend for JPG/PNG, so
#     no libjpeg is needed by SDL_image itself).
#   - pixman: software rasterizer used by the app's render code
#     (find_library pixman). Built from the copy VENDORED in the
#     LibreSprite tree (third_party/pixman, 0.42.2, upstream's own
#     CMakeLists.txt) with the PS4 patch applied by prepare-sources.sh
#     (PIXMAN_NO_TLS instead of pthreads, no OpenMP, plus install rules).
#     No separate download, and the version is exactly the one the app
#     was developed against.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"
SRC="$HERE/deps/src"; BLD="$HERE/deps/build"; PREFIX="$HERE/prefix"
TC="$HERE/cmake/ps4-toolchain.cmake"
mkdir -p "$SRC" "$BLD" "$PREFIX"
W() { cygpath -m "$1"; }

# LF checkouts (run #1 root cause): the Windows runner's git converts text
# files to CRLF by default, but the patches in patches/ are pinned LF (see
# .gitattributes) — a CRLF checkout would make git apply fail. SDL gets
# three patches applied below, so its checkout must be LF.
fetch() { # name url tag
    if [ ! -d "$SRC/$1" ]; then
        git -c advice.detachedHead=false -c core.autocrlf=false clone -q --depth 1 --branch "$3" "$2" "$SRC/$1"
    fi
}
build() { # name srcdir [cmake args...]
    local name="$1" src="$2"; shift 2
    if [ -f "$BLD/$name/.done" ]; then echo "== $name (cached)"; return; fi
    echo "== $name"
    cmake -G Ninja -S "$(W "$src")" -B "$(W "$BLD/$name")" -DCMAKE_TOOLCHAIN_FILE="$(W "$TC")" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(W "$PREFIX")" -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG" -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG" \
        "$@" > "$BLD/$name.configure.log" 2>&1 || { tail -40 "$BLD/$name.configure.log"; exit 1; }
    cmake --build "$(W "$BLD/$name")" > "$BLD/$name.build.log" 2>&1 || { tail -60 "$BLD/$name.build.log"; exit 1; }
    cmake --install "$(W "$BLD/$name")" > "$BLD/$name.install.log" 2>&1 || { tail -40 "$BLD/$name.install.log"; exit 1; }
    touch "$BLD/$name/.done"
}

fetch zlib https://github.com/madler/zlib.git v1.3.1
build zlib "$HERE/zlib-cmake" -DZLIB_SRC="$(W "$SRC/zlib")"

fetch libpng https://github.com/glennrp/libpng.git v1.6.44
build libpng "$SRC/libpng" -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_TOOLS=OFF

# libjpeg-turbo 3.1.4: static only, no SIMD, no Java, no tests. WITH_JPEG8
# keeps the libjpeg v8 API the app expects; WITH_TURBOJPEG keeps the
# TurboJPEG API available (the app only uses the plain jpeg API).
# WITH_TOOLS=OFF (run #2 root cause): with tools on, upstream's install
# rules do install(PROGRAMS ${DIR}/tjbench-static${EXE} ...) where EXE comes
# from the generic CMAKE_EXECUTABLE_SUFFIX — which CMake resets to "" for
# the PS4 system — while the per-language suffix from our toolchain makes
# the built binary tjbench-static.elf, so install fails with "file INSTALL
# cannot find .../tjbench-static". The CLI tools (cjpeg/djpeg/jpegtran/
# tjbench) are not needed on PS4; only the libraries matter.
fetch libjpeg-turbo https://github.com/libjpeg-turbo/libjpeg-turbo.git 3.1.4
build libjpeg-turbo "$SRC/libjpeg-turbo" -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
    -DWITH_SIMD=OFF -DWITH_JAVA=OFF -DWITH_TURBOJPEG=ON -DWITH_JPEG8=ON -DWITH_TESTS=OFF \
    -DWITH_TOOLS=OFF

# giflib 5.2.2 (tarball, no git repo): built with the giflib-cmake wrapper.
# Debian pool first (verified: same pristine tarball, fast mirror);
# SourceForge fallback (the upstream download URL).
if [ ! -f "$SRC/giflib-5.2.2.tar.gz" ]; then
    curl -fL --retry 8 --retry-delay 15 --retry-all-errors -o "$SRC/giflib-5.2.2.tar.gz" https://deb.debian.org/debian/pool/main/g/giflib/giflib_5.2.2.orig.tar.gz \
    || curl -fL --retry 8 --retry-delay 15 --retry-all-errors -o "$SRC/giflib-5.2.2.tar.gz" "https://sourceforge.net/projects/giflib/files/giflib-5.2.2.tar.gz/download"
fi
if [ ! -d "$SRC/giflib-5.2.2" ]; then
    tar -xzf "$SRC/giflib-5.2.2.tar.gz" -C "$SRC"
fi
build giflib "$HERE/giflib-cmake" -DGIFLIB_SRC="$(W "$SRC/giflib-5.2.2")"

fetch freetype https://github.com/freetype/freetype.git VER-2-13-3
build freetype "$SRC/freetype" -DFT_WITH_ZLIB=ON -DFT_WITH_PNG=ON -DFT_WITH_BZIP2=OFF \
    -DFT_WITH_HARFBUZZ=OFF -DFT_WITH_BROTLI=OFF

fetch tinyxml2 https://github.com/leethomason/tinyxml2.git 9.0.0
build tinyxml2 "$SRC/tinyxml2" -Dtinyxml2_BUILD_TESTING=OFF

# libarchive 3.8.9: only zlib stays on (it is already built above); every
# other optional backend is OFF so no extra dependency is pulled in.
# The tar/cpio/cat/unzip tools are OFF too (library only).
fetch libarchive https://github.com/libarchive/libarchive.git v3.8.9

# PS4 patch: skip -Wl,--gc-sections (run #3 root cause). libarchive appends
# it to CMAKE_EXE_LINKER_FLAGS for Clang, but our toolchain invokes ld.lld
# directly (not via the compiler driver) and ld.lld rejects the -Wl,
# prefix, so every try_compile link fails, every check_type_size fails
# (HAVE_SYS_TYPES_H/HAVE_STDINT_H/HAVE_STDDEF_H stay empty, so the test
# programs include no headers at all), and configure aborts at
# "pid_t doesn't exist on this platform?". Idempotent like the SDL patches.
PATCH="$HERE/patches/libarchive-ps4-no-gc-sections.patch"
if ! git -C "$SRC/libarchive" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    git -C "$SRC/libarchive" apply "$PATCH"
fi

# PS4 patch: <sys/disk.h> does not exist in the OpenOrbis sysroot, but
# clang predefines __FreeBSD__ for the freebsd12 target, so
# archive_read_open_filename.c includes it and the build fails. The
# disk-probing ioctl is meaningless on PS4 (no raw disk devices), so the
# FreeBSD branch is skipped there. Idempotent like the SDL patches.
PATCH="$HERE/patches/libarchive-ps4-no-disk-h.patch"
if ! git -C "$SRC/libarchive" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    git -C "$SRC/libarchive" apply "$PATCH"
fi

build libarchive "$SRC/libarchive" -DENABLE_LIBXML2=OFF -DENABLE_EXPAT=OFF \
    -DENABLE_LZMA=OFF -DENABLE_ZSTD=OFF -DENABLE_BZip2=OFF -DENABLE_LZ4=OFF \
    -DENABLE_LIBB2=OFF -DENABLE_NETTLE=OFF -DENABLE_MBEDTLS=OFF -DENABLE_OPENSSL=OFF \
    -DENABLE_LZO=OFF -DENABLE_PCREPOSIX=OFF -DENABLE_PCRE2POSIX=OFF \
    -DENABLE_ZLIB=ON -DENABLE_TAR=OFF -DENABLE_CPIO=OFF -DENABLE_CAT=OFF \
    -DENABLE_UNZIP=OFF -DENABLE_TEST=OFF

# SDL 2.0.18, PacBrew fork, ps4 branch: the PS4 video/audio/joystick drivers
# live here. -DPS4=ON activates them (SDL's own openorbis.cmake toolchain
# sets the same variable; our ps4-toolchain.cmake sets CMAKE_SYSTEM_NAME PS4
# and Platform/PS4.cmake sets PS4=1 as well).
# SDL2main is disabled on purpose (like the SoH build): LibreSprite links
# SDL2 via its FindSDL2 module, which tolerates a missing SDL2main, and
# SDL's dummy main would clash with the app's own main on PS4.
fetch SDL https://github.com/PacBrew/SDL.git ps4

# PS4 patch: skip the FreeBSD sysctl code in SDL_sysfilesystem.c — the
# OpenOrbis sysroot has no <sys/sysctl.h> (Solarus run #4 failed here).
# Idempotent: safe whether SDL was freshly cloned or restored from cache.
PATCH="$HERE/patches/sdl-ps4-sysctl.patch"
if ! git -C "$SRC/SDL" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    git -C "$SRC/SDL" apply "$PATCH"
fi

# PS4 patch: force the PS4 drivers (Solarus run #23 root cause). Our
# toolchain sets CMAKE_SYSTEM_NAME PS4 and the PS4 platform file sets
# UNIX=1, so SDL's platform chain takes the UNIX branch and skips the
# elseif (PS4) block — the build ends up with ONLY the dummy video driver
# ("No available video device" on console). This patch adds a guarded
# if (PS4 AND NOT SDL_VIDEO_DRIVER_PS4) block after the chain that
# replicates the elseif (PS4) setup. Idempotent like the one above.
PATCH="$HERE/patches/sdl-ps4-force-drivers.patch"
if ! git -C "$SRC/SDL" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    git -C "$SRC/SDL" apply "$PATCH"
fi

# PS4 patch: C89 declarations (Solarus run #24 root cause, extended in
# run #26). SDL's own CMakeLists adds -Werror=declaration-after-statement
# unconditionally, and the PacBrew PS4 drivers declare variables after
# statements in 12 places. This patch moves those declarations to the top
# of their blocks, changing no logic. Idempotent like the ones above.
PATCH="$HERE/patches/sdl-ps4-c89-declarations.patch"
if ! git -C "$SRC/SDL" apply --reverse --check "$PATCH" >/dev/null 2>&1; then
    git -C "$SRC/SDL" apply "$PATCH"
fi

build SDL "$SRC/SDL" -DPS4=ON -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF -DSDL2_DISABLE_SDL2MAIN=ON -DSDL2_DISABLE_INSTALL=OFF -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_OPENGL=OFF -DSDL_OPENGLES=OFF -DSDL_VULKAN=OFF -DSDL_KMSDRM=OFF -DSDL_RPI=OFF -DSDL_ALSA=OFF -DSDL_PULSEAUDIO=OFF -DSDL_PIPEWIRE=OFF -DSDL_JACK=OFF -DSDL_SNDIO=OFF -DSDL_OSS=OFF -DSDL_ESD=OFF -DSDL_ARTS=OFF -DSDL_NAS=OFF -DSDL_FUSIONSOUND=OFF -DSDL_DBUS=OFF -DSDL_IBUS=OFF -DSDL_FCITX=OFF -DSDL_LIBUDEV=OFF -DSDL_HIDAPI_LIBUSB=OFF -DSDL_RPATH=OFF -DSDL_DUMMYVIDEO=ON -DSDL_DUMMYAUDIO=ON -DSDL_DISKAUDIO=OFF -DSDL_OFFSCREEN=OFF -DSDL_LOADSO=OFF -DSDL_DIRECTFB=OFF -DSDL_SYSTEM_ICONV=OFF -DSDL_LIBICONV=OFF -DSDL_CCACHE=OFF -DSDL_FILESYSTEM=ON -DSDL_VIRTUAL_JOYSTICK=ON -DSDL_HIDAPI=ON -DSDL_HIDAPI_JOYSTICK=OFF -DSDL_WERROR=OFF

# SDL_image AFTER SDL (run #4 root cause): SDL2_image 2.8.8's configure
# runs sdl_find_sdl2(), which falls back to its private FindSDL2 module
# (find_library SDL2_LIBRARY + find_path SDL2_INCLUDE_DIR) when no
# SDL2Config.cmake is found. Both look in the prefix, so SDL must already
# be built and installed there — building SDL_image first fails with
# "Could NOT find PrivateSDL2 (missing: SDL2_LIBRARY SDL2_INCLUDE_DIR)".
# Same order as the Solarus port.
fetch SDL_image https://github.com/libsdl-org/SDL_image.git release-2.8.8
build SDL_image "$SRC/SDL_image" -DSDL2IMAGE_VENDORED=OFF -DSDL2IMAGE_SAMPLES=OFF \
    -DSDL2IMAGE_PNG=ON -DSDL2IMAGE_JPG=ON -DSDL2IMAGE_TIF=OFF -DSDL2IMAGE_WEBP=OFF \
    -DSDL2IMAGE_AVIF=OFF -DSDL2IMAGE_JXL=OFF

# pixman 0.42.2, VENDORED in the LibreSprite tree (third_party/pixman):
# no fetch — prepare-sources.sh already cloned the tree and applied the
# PS4 patch (PIXMAN_NO_TLS, no OpenMP, install rules). Its own
# CMakeLists.txt is upstream's; the build() helper configures it with the
# PS4 toolchain like any other dep.
build pixman "$SRC/libresprite/third_party/pixman"

echo "ALL DEPS OK"
