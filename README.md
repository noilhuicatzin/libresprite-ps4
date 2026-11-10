# LibreSprite for PS4

Build scripts, patches and workflow to cross-compile
[LibreSprite](https://github.com/LibreSprite/LibreSprite) (GPLv2 pixel-art
editor) for a jailbroken PS4 (firmware 12.50, GoldHEN), using the
OpenOrbis toolchain + stock LLVM on a GitHub Actions Windows runner.

This repo carries **only patches, scripts and the workflow** — never the
`.pkg`, never the app data, never Sony's Piglet modules. The `.pkg` is a
CI artifact for personal use on the owner's own console.

## Status

Phase 0 (project framework) — see `BUILD.md` for the full picture, the
pinned versions, the milestones and the first-build checklist.

- **Milestone 1**: SDL_Renderer smoke test (`tests/sdl-renderer-smoke/`)
  — nobody has proven `SDL_CreateRenderer(SDL_RENDERER_ACCELERATED)` on
  the PS4 video driver yet, and LibreSprite's `she` backend draws through
  it. This is the first thing the CI builds and the first thing to test
  on console.
- **Milestone 2**: DS4 touchpad mouse (`tests/ds4-touchpad-mouse/`,
  sketch) — SDL on PS4 delivers no mouse events; the touchpad read via
  `scePadReadState()` is the first mouse that can work without new
  hardware.

## Layout

- `scripts/prepare-sources.sh` — clones LibreSprite at the pinned commit,
  inits submodules, applies the PS4 patches.
- `build-deps.sh` — cross-builds all third-party deps into `prefix/`.
- `build-gen-host.sh` — builds the host `gen` code generator (the app's
  build runs it on the build machine; a PS4 `.elf` cannot run there).
- `configure.sh` — configures the PS4 app build (+ stages host `gen.exe`).
- `package.sh` — turns an `.elf` into an installable `.pkg`
  (app + bundled `data/`, or a smoke test with `SKIP_DATA=1`).
- `cmake/` — PS4 toolchain + platform file (copied from the Solarus port).
- `patches/` — LibreSprite PS4 patches + the three SDL PS4 patches.
- `compat/`, `zlib-cmake/`, `giflib-cmake/` — compat headers and the two
  CMake wrappers for deps that ship no CMakeLists.
- `tests/` — the smoke tests. `docs/INSTALL.md` — console install steps.

## Build

Runs are manual (`workflow_dispatch` in `.github/workflows/build-ps4.yml`).
On console, install the `.pkg` from the `libresprite-ps4` artifact and
follow `docs/INSTALL.md`.

## License

LibreSprite is GPLv2 (`LICENSE`). The build scripts and patches in this
repo are likewise GPLv2. Do not distribute the `.pkg`.
