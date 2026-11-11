# LibreSprite PS4 — build notes

## Pinned versions (verified 2026-11-10)

| Piece | Version | Source |
|---|---|---|
| LibreSprite | commit `98f7443` (2026-10-30) | github.com/LibreSprite/LibreSprite |
| SDL | 2.0.18, branch `ps4` | github.com/PacBrew/SDL (commit `bf797a5`, same as Solarus) |
| SDL_image | release-2.8.8 | libsdl-org/SDL_image |
| zlib | 1.3.1 | madler/zlib |
| libpng | 1.6.44 | glennrp/libpng |
| freetype | VER-2-13-3 | freetype/freetype |
| libjpeg-turbo | 3.1.4 | libjpeg-turbo/libjpeg-turbo |
| giflib | 5.2.2 (tarball) | deb.debian.org (primary) / sourceforge.net (fallback) |
| tinyxml2 | 9.0.0 | leethomason/tinyxml2 |
| libarchive | 3.8.9 | libarchive/libarchive |
| pixman | 0.42.2 (vendored) | LibreSprite tree, `third_party/pixman` |
| Toolchain | OpenOrbis 0.5.4 + LLVM 18.1.8 + CMake 4.1.0 + Ninja 1.12.1 | GitHub releases (see workflow) |

CMake 4.1+ is required: LibreSprite sets `cmake_minimum_required(VERSION 4.1)`
and the toolchain pins 3.28.6, so the workflow installs 4.1.0 (GitHub primary,
cmake.org mirror fallback — both return 200).

## What was verified locally (no builds launched)

- **Patches**: all 4 LibreSprite patches apply forward AND reverse cleanly
  on a pristine copy of the pinned tree (`git apply --check` + apply +
  reverse). Generated with `git diff` from a scratch copy, never
  transcribed by hand.
- **Dep options**: every `-D` flag in `build-deps.sh` was checked against
  the real `CMakeLists.txt` of the pinned dep version (libarchive
  `OPTION(ENABLE_*)`, libjpeg-turbo options, tinyxml2
  `tinyxml2_BUILD_TESTING`, giflib file list from the 5.2.2 tarball).
- **Find modules**: stock CMake ships `FindGIF` and `FindLibArchive`
  (verified on the VM's CMake). The repo's own `FindSDL2`/`FindSDL2_IMAGE`
  modules try `pkg_search_module(... REQUIRED ...)` first — and the
  cross-built SDL installs no `.pc` files (verified: no `pkgconfig/` dir
  in the Solarus prefix), so the patch drops `REQUIRED` and the
  `find_library` fallback runs.
- **gen flow**: `src/gen` is built unconditionally; the app's custom
  commands run `${CMAKE_BINARY_DIR}/bin/gen`. The PS4 build cannot run
  its own gen (a PS4 `.elf`), so `build-gen-host.sh` builds it with the
  host compiler (`GEN_ONLY=ON`) and `configure.sh` stages the exe into
  `build/bin/gen.exe`. The PS4 `gen` target still builds (as `gen.elf`,
  never run) because the custom commands `DEPENDS gen`. **Caveat found
  by testing**: `GEN_ONLY` does NOT skip the SDL2/SDL2_image finds
  (they live in the "Platform specific stuff" section, guarded only by
  `USE_SDL2_BACKEND`, not by `GEN_ONLY`) — so the host build passes
  `-DUSE_SDL2_BACKEND=OFF -DUSE_SDL3_BACKEND=OFF`; gen never touches
  SDL. Proven locally: GEN_ONLY configure + `gen` build + a functional
  run (`gen --input data/widgets/advanced_mode.xml` produced a valid
  31-line generated header) with CMake 4.1.0 + gcc 13.3 on this VM.
- **giflib + pixman wrappers**: both built and installed on the host
  with the real sources (libgif.a + gif_lib.h; libpixman.a 1.1M +
  pixman.h / pixman-version.h / pixman-config.h under
  `include/pixman-1/`). The pixman test used the *patched* vendored
  CMakeLists (PIXMAN_NO_TLS, no OpenMP) — the 30-source list compiles
  clean.
- **Pixman threading**: `pixman-compiler.h` has a documented
  `PIXMAN_NO_TLS` branch (plain static, no pthreads) — used instead of
  `-DHAVE_PTHREADS=1`. `pixman-x86.c` guards its SIMD includes behind
  `USE_SSE2`/`USE_SSSE3`, so no `<immintrin.h>` is pulled in.
- **Touchpad fields**: verified against the OpenOrbis headers
  (`include/orbis/_types/pad.h`, master, 2026-11-10) — see
  `tests/ds4-touchpad-mouse/README.md`.
- **Icon**: `pkg-static/sce_sys/icon0.png` is the app's own `ase64.png`
  upscaled 64→512 with nearest-neighbour (crisp pixel-art look).
- **Content IDs**: app `IV0000-LBSP00001_00-LIBRESPRITE00000` (36 chars),
  smoke test `IV0000-LBSP00002_00-LIBRESPSDLTEST00` (36 chars);
  Title IDs `LBSP00001` / `LBSP00002`.

## Corrections to the Phase-0 study (found while building this)

- `gen` is at `src/gen/`, not `laf/` — there is no `laf` directory in
  this tree at all (old Aseprite layout). The `GEN_ONLY` flow is real
  and is how the host generator is built.
- `includeUserDir`/`includeDataDir` live in `src/app/resource_finder.cpp`,
  not in `src/base/fs_unix.h` (which holds `get_app_path`,
  `get_temp_path`, `get_font_paths`, ...). Both files needed patching.
- LibreSprite has **two submodules** (`third_party/simpleini`,
  `src/flic`) that a plain clone leaves empty — `prepare-sources.sh`
  inits them.
- The vendored `third_party/pixman` (0.42.2) ships its own complete
  `CMakeLists.txt`, so pixman is built from the vendored copy, not
  fetched from freedesktop (no 0.44.2 fetch needed).

## First-build checklist (things only the runner can prove)

1. **Host gen build**: MinGW gcc from Git Bash + CMake 4.1.0 + Ninja.
   If CMake cannot find a host compiler, the fix is `setup-msbuild` /
   a VS dev prompt or an explicit `-DCMAKE_C_COMPILER=gcc`.
   `clip` on Windows uses `windowscodecs` — a system lib, no extra dep.
   The host build itself was proven locally (configure + build + a
   functional `gen` run); the only runner-specific unknown is the
   MinGW compiler detection under Git Bash.
2. **libarchive**: first CMake configure on the PS4 toolchain. Its
   `OPTION(ENABLE_*)` set was verified, but its `CheckIncludeFile`
   probes run against the OpenOrbis sysroot — a missing header fails
   loudly in the configure log, not silently.
3. **giflib wrapper**: no `config.h` is generated (headers guard behind
   `HAVE_CONFIG_H`). If a giflib source needs a config define, the fix
   is a small generated `config.h` in the wrapper — not a source patch.
4. **pixman**: the vendored CMakeLists builds 30 sources with the PS4
   flags. `pixman-region.c` is NOT in upstream's list (the region API
   lives in `region16`/`region32` in 0.42.2) — do not "fix" the list.
5. **SDL_Renderer smoke test**: the real milestone. If
   `SDL_RENDERER_ACCELERATED` fails on console, the app cannot use the
   `she` SDL backend as-is — plan B from the study: an SDLTexture-only
   renderer path, or a raw-GL backend in `she` (the Solarus GL smoke
   test proved raw GL works).
6. **DS4 touchpad double-open**: the sketch opens a second pad handle
   next to SDL's joystick driver. If `scePadOpen` fails there, the mouse
   driver must read touch data from SDL's joystick layer instead.
7. **`data/` filenames**: `package.sh` builds the gp4 file list with
   `find data -type f`. Upstream `data/` has no spaces in filenames; if
   one ever appears, the pkg build fails loudly instead of dropping it.
8. **`sys/param.h`**: `fs_unix.h` does not include it (`MAXPATHLEN` is
   `#define`d locally), so no dependency on the toolchain having it.
9. **create-gp4 hardcodes `<rootdir>`**: the tool always writes the
   template rootdir (sce_sys/about, sce_module,
   assets/{audio,fonts,images,misc,videos}) and never derives
   directories from `--files`. PkgTool's `BuildFSTree` looks up every
   file's parent dir in `<rootdir>`, so any file under `data/` crashed
   `pkg_build` with "Sequence contains no elements" (run #13).
   `package.sh` now runs `scripts/fix-gp4-rootdir.py` after
   `create-gp4` to insert the missing dirs from the file list.

## Cache rules

- The deps cache key hashes `build-deps.sh`, `cmake/ps4-toolchain.cmake`,
  `cmake/Platform/PS4.cmake`, `zlib-cmake/CMakeLists.txt`,
  `giflib-cmake/CMakeLists.txt` and `patches/libresprite-ps4-pixman.patch`.
  A change to any other patch or to `prepare-sources.sh` does NOT
  invalidate the deps cache: bump `build-deps.sh` (even a comment) when
  a patch must rebuild deps from scratch.
- The tools cache key is
  `libresprite-ps4-tools-oo0.5.4-llvm18.1.8-cmake4.1.0-ninja1.12.1-net8-v1`.

## Phases (from the study, 6–10 weeks at Lux's pace)

- **0** — this framework + SDL_Renderer smoke test (1 wk).
- **1** — five new deps (libarchive, giflib, libjpeg-turbo, tinyxml2,
  pixman) — built in this same first run (1–2 wks).
- **2** — compile the app (1–2 wks).
- **3** — SDL mouse/keyboard drivers (2–4 wks, the long uncertain part).
  Mouse first via DS4 touchpad (sketch in `tests/`); keyboard via HID
  with a tiny proof-of-concept that just prints pressed keys; system
  keyboard dialog (Swkb/IME) for text entry in parallel.
- **4** — DualShock fallback in the app (1 wk): touchpad/sticks as
  pointer, buttons for tools/shortcuts. Input is hybrid and adaptive:
  mouse+keyboard = full desktop mode, DualShock only = pad mode, both =
  hybrid.
- **5** — console testing (2–3 wks).

First boot plausible week 3–4; a truly usable editor only after the
input phases. If HID keyboard stalls, the fallback is Swkb + DS4, not
abandoning the port.
