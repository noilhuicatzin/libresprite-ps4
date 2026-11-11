# Patches

PS4 adaptations for LibreSprite (pinned commit `98f7443`, 2026-10-30).
Applied by `scripts/prepare-sources.sh`, idempotently (reverse-check first),
in the order listed. All patches are local to this private fork; nothing
here is submitted upstream.

## LibreSprite patches

- **libresprite-ps4-x11.patch** — `CMakeLists.txt`: the `if(UNIX ...)`
  block requires X11 (`find_package(X11 REQUIRED)`) and pthreads. The PS4
  toolchain sets `UNIX=1` (Platform/PS4.cmake), so without this the
  configure fails on a system with no X11. Adds `AND NOT PS4` to the
  condition and an `elseif(PS4)` branch that only appends `m` to
  `PLATFORM_LIBS` (libm lives in the OpenOrbis sysroot; the toolchain's
  fake Threads package makes `find_package(Threads)` unnecessary).
- **libresprite-ps4-paths.patch** — `src/app/resource_finder.cpp` +
  `src/base/fs_unix.h`: every writable/readable path moves to
  `/data/libresprite/` (config, scripts, brushes, keys, temp) and data
  lookups try `/data/libresprite/data/` first, then `/app0/data/` (the
  data bundled in the .pkg). Also fixes three real PS4 hazards in
  `fs_unix.h`: `get_app_path()` took the FreeBSD `sysctl` branch, but the
  OpenOrbis sysroot has no `<sys/sysctl.h>` (same failure as SDL run #4) —
  it now returns `/app0/eboot.bin`; `get_temp_path()` returned `/tmp`,
  which does not exist on PS4; `get_font_paths()` built a `std::string`
  from `getenv("HOME") == nullptr` (HOME is unset on PS4) — undefined
  behaviour that would crash the font popup / skin theme.
- **libresprite-ps4-find-sdl2-nopkgconfig.patch** —
  `cmake/FindSDL2.cmake` + `cmake/FindSDL2_IMAGE.cmake`: both modules try
  `pkg_search_module(... REQUIRED ...)` first. The Windows runner has
  pkg-config (Git Bash) but our cross-built SDL installs no `.pc` files
  (verified: no `pkgconfig/` dir in the Solarus prefix), so the REQUIRED
  lookup fails hard and the `find_library` fallback never runs. Dropping
  `REQUIRED` lets the fallback find `prefix/lib/libSDL2.a` and
  `prefix/include/SDL2/SDL.h` via `CMAKE_FIND_ROOT_PATH`.
- **libresprite-ps4-pixman.patch** — `third_party/pixman/CMakeLists.txt`
  (vendored pixman 0.42.2, upstream's own build file): swaps
  `-DHAVE_PTHREADS=1` for `-DPIXMAN_NO_TLS` (no pthreads on PS4;
  `pixman-compiler.h` has a documented `PIXMAN_NO_TLS` branch that makes
  thread-local storage a plain static — the app renders on one thread)
  and drops `-DUSE_OPENMP=1` (no OpenMP on PS4). Adds `install()` rules
  (libpixman.a + headers under `include/pixman-1/`) so the app's
  `find_library(PIXMAN_LIBRARY NAMES pixman pixman-1)` /
  `find_path(PIXMAN_INCLUDE_DIR NAMES pixman.h PATH_SUFFIXES pixman-1)`
  find it. The vendored CMakeLists generates an empty `pixman-config.h`
  and a `pixman-version.h` (0.42.2); the defines come from the command
  line, as upstream does.

## SDL patches (copied verbatim from the Solarus port)

- **sdl-ps4-sysctl.patch** — skip the FreeBSD `sysctl` code in
  `SDL_sysfilesystem.c`: the OpenOrbis sysroot has no `<sys/sysctl.h>`.
- **sdl-ps4-force-drivers.patch** — force the PS4 drivers. The toolchain
  sets `CMAKE_SYSTEM_NAME PS4` and the platform file sets `UNIX=1`, so
  SDL's platform chain takes the UNIX branch and skips the `elseif (PS4)`
  block, leaving only the dummy video driver. Adds a guarded
  `if (PS4 AND NOT SDL_VIDEO_DRIVER_PS4)` block after the chain.
- **sdl-ps4-c89-declarations.patch** — SDL's CMakeLists adds
  `-Werror=declaration-after-statement` unconditionally; the PacBrew PS4
  drivers declare variables after statements in 12 places. Moves those
  declarations to the top of their blocks, changing no logic.

## libarchive patches (v3.8.9, applied by `build-deps.sh`)

- **libarchive-ps4-no-gc-sections.patch** — `CMakeLists.txt` (run #3):
  libarchive appends `-Wl,--gc-sections` to `CMAKE_EXE_LINKER_FLAGS`
  (and `CMAKE_SHARED_LINKER_FLAGS`) for Clang, but our toolchain invokes
  `ld.lld` directly, not via the compiler driver, and `ld.lld` rejects
  the `-Wl,` prefix (`ld.lld: error: unknown argument
  '-Wl,--gc-sections'`). Every `try_compile` link therefore fails, so
  the header checks stay empty and CMake's `check_type_size` test
  programs include no headers at all — every type check fails and
  configure aborts at `pid_t doesn't exist on this platform?`
  (CMakeLists.txt:1786). The patch wraps the two lines in `IF(NOT PS4)`
  (PS4 is set by the toolchain file, same convention as the SDL
  force-drivers patch) and keeps the harmless `-ffunction-sections
  -fdata-sections` compile flags.
- **libarchive-ps4-no-disk-h.patch** — `libarchive/archive_read_open_
  filename.c` (run #3, found while building the patched tree): clang
  predefines `__FreeBSD__` for the `x86_64-pc-freebsd12-elf` target, so
  the file includes `<sys/disk.h>`, which does not exist in the OpenOrbis
  sysroot (`fatal error: 'sys/disk.h' file not found`). The
  `DIOCGMEDIASIZE` probe is meaningless on PS4 (no raw disk devices;
  LibreSprite only reads regular files, which take the `S_ISREG` branch
  above it), so the three FreeBSD guards (include, `mediasize` variable,
  ioctl branch) gain `&& !defined(__PS4__)`. No-op off PS4.

## Rules (from the Solarus port)

- The deps cache key hashes `build-deps.sh`, `cmake/ps4-toolchain.cmake`,
  `cmake/Platform/PS4.cmake`, `zlib-cmake/CMakeLists.txt`,
  `giflib-cmake/CMakeLists.txt` and `patches/libresprite-ps4-pixman.patch`
  — NOT the other patches or `prepare-sources.sh`. A patch-only change
  does NOT invalidate the deps cache: bump `build-deps.sh` (even a
  comment) when a patch must rebuild deps from scratch.
- Never transcribe a patch by hand: generate it with `git diff` from a
  scratch copy of the pinned tree, then verify it applies forward and
  reverse on a pristine copy before committing it here.
