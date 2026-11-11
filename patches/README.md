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
- **quickjs-ps4-malloc-np.patch** — `third_party/quickjs-amalgam/
  quickjs-amalgam.c` (run #8, found while building the patched tree):
  clang predefines `__FreeBSD__` for the `x86_64-pc-freebsd12-elf`
  target, so the file takes the FreeBSD branch and includes
  `<malloc_np.h>`, which does not exist in the OpenOrbis sysroot
  (`fatal error: 'malloc_np.h' file not found`, line 106). The patch
  adds a `__PS4__` arm before it that includes newlib's `<malloc.h>`
  instead (which declares the same `malloc_usable_size()` — verified
  present in both `libc.a` and `libSceLibcInternal.so`) and adds
  `__PS4__` to the `js__malloc_usable_size()` arm that calls it (without
  that second hunk the code would compile but silently report every
  allocation as size 0, so QuickJS's GC would never trigger on memory
  pressure). Same compile also surfaced a second missing FreeBSD-ism:
  `js_os_ttyGetWinSize()` calls `ioctl(fd, TIOCGWINSZ, &ws)`, but the
  sysroot declares `struct winsize` and `ioctl()` with no `TIOCGWINSZ`
  request code — the patch defines it from `_IOR('t', 104, struct
  winsize)` (the FreeBSD spelling; `_IOR` is in the sysroot's
  `bits/ioctl.h`). There is no terminal on PS4, so the call can only
  fail and the function returns null, as intended. The other two
  `__FreeBSD__` sites in the file need nothing: line 75472 only
  typedefs `sig_t` / declares `environ`, and line 79484 only sets the
  `OS_PLATFORM` string to `"freebsd"`.
- **delta-ps4-typeindex.patch** — `third_party/delta/JSON.hpp` (run #9):
  `Value::operator std::shared_ptr<T>` and `Value::asNative<T>` compare
  `typeid(T)` (a `const std::type_info`) with `ptr->second` (a
  `std::type_index`, the second half of `NativeRef`) with `!=`, and this
  libc++ has no viable `operator!=` for that pair: the only candidates
  are the member `operator!=` of `type_info` (the right-hand side cannot
  convert to `type_info`) and the member `operator!=` of `type_index`
  (only usable when the `type_index` is the left operand). The mixed
  comparison is not valid pre-C++20 at all (verified: g++ rejects it in
  C++17 mode); in C++20 it only compiles where operator rewriting finds
  a path, and libstdc++ provides one because its `type_index` declares
  `operator<=>`, while this libc++'s `type_index` declares only the six
  classic relational member operators and no `<=>`. The patch wraps the
  left side in both places (lines 409, 421): `std::type_index(typeid(T))
  != ptr->second` — same semantics (`type_index::operator!=` compares
  the underlying `type_info`s), both operands now the same type. The
  other `typeid` uses in the vendored delta code need nothing:
  `QuickJSInterpreter.cpp:666` already has the `type_index` on the left
  (`base != typeid(void)`), and the rest compare two `type_info`s or
  only use `.name()` / `.hash_code()`.
- **libresprite-ps4-whole-archive.patch** — `src/CMakeLists.txt` (run
  #10): the `KEEP_INJECTIONS_BEGIN/END` pair wraps the app libraries
  with `-Wl,--whole-archive` / `-Wl,--no-whole-archive` on UNIX, but
  our toolchain invokes `ld.lld` directly, not via the compiler driver,
  and `ld.lld` rejects the `-Wl,` prefix (`ld.lld: error: unknown
  argument '-Wl,--whole-archive'`, at the final link [785/785] — after
  all 785 targets compiled). Same class of bug as the libarchive
  `-Wl,--gc-sections` fix in run #3. The patch adds a `PS4` arm before
  the UNIX arm that sets the bare linker options `--whole-archive` /
  `--no-whole-archive` instead (verified: the bare options link a real
  PS4 .elf with the toolchain's `link.x` script and `crt1.o`; the
  `-Wl,` forms reproduce the exact CI errors). The `PS4` variable is
  set by the toolchain file, same convention as the other patches.
- **libresprite-ps4-thread-atexit.patch** — `src/CMakeLists.txt` + new
  file `src/main/ps4_thread_atexit.cpp` (run #12): OpenOrbis libc does
  not provide `__cxa_thread_atexit_impl`, the platform hook that
  libc++'s `__cxa_thread_atexit()` calls to register the destructor of
  a `thread_local` object, so the final link [785/785] dies on this one
  undefined symbol (after all 785 targets compiled). The only TU with a
  `thread_local` with a non-trivial destructor is
  `third_party/httplib/httplib.cpp` (`thread_local std::regex` /
  `unordered_set` / `std::set` / mt19937 engine); it is pulled in via
  `libhttp-lib.a`. The patch adds the implementation to the
  `libresprite` executable target under `if(PS4)` (the `PS4` variable is
  set by the toolchain file, same convention as the other patches). The
  implementation is a real one, not a stub: a per-thread list of
  (destructor, object) pairs kept in one pthread key (key functions are
  in `-lkernel`, already in the base libs), run LIFO at thread exit —
  a stub returning 0 would leak the compiled regexes/sets on every
  httplib connection thread exit. Verified: the exact CI error was
  reproduced with the real toolchain (minimal TU with a `thread_local
  std::string`, CI-faithful `ld.lld` command, exit 1); with the new
  object the same link exits 0 with a valid PS4 .elf; the destructor
  order (LIFO, including a destructor that registers another
  `thread_local`) was verified with a host-side run of the same file.
  `dso_handle` is ignored: the binary is statically linked, nothing is
  ever `dlclose()`d. This patch does NOT touch `build-deps.sh`, so the
  deps cache is preserved for the run that tests it.

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
