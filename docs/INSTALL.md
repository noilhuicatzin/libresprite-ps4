# Installing LibreSprite on PS4

## What you need on the console first

- The two Sony Piglet modules in `/data/self/system/common/lib/` (the
  same two the Ship of Harkinian and Solarus ports use — once they are
  there, they serve all three ports; do not upload them twice).
- The `.pkg` from the `libresprite-ps4` CI artifact (the app package,
  `LBSP00001`). Install it with GoldHEN's Package Installer, as usual.

## First run

Just launch it. The package already contains the app's `data/` tree
(fonts, skins, widgets) under `/app0/data/`, so nothing else has to be
uploaded for the first test.

On first run the app creates `/data/libresprite/` itself (config,
`libresprite.ini`, scripts, brushes, keys) and `/data/libresprite/tmp`
(temp files). You do not have to create anything by hand. If you want
your own skins, fonts or scripts, upload them to
`/data/libresprite/data/` — the app looks there first, before the
bundled `/app0/data/`.

## The SDL renderer smoke test

The `libresprite-ps4-sdl-renderer-smoke` artifact is a separate, tiny
package (`LBSP00002`, "LibreSprite SDL Test"). Install it and run it
first if you want to check the graphics path before the full app: it
writes `/data/sdl-renderer-smoke.log`. The last line should be
`[diag] RENDERER_OK`. If it ends at `ACCELERATED renderer failed`, send
the log back — that decides whether the app can use its SDL backend
at all (see `BUILD.md`, plan B).

## If the app crashes on launch

The app writes its own log only when it gets far enough to open one.
Check, in this order:

1. `/data/libresprite/` — was it created? If not, the app died before
   the first path lookup (send a note with exactly what the screen did).
2. Whether the Piglet modules are the known-good ones (same check as
   SoH/Solarus: a bad module gives `0x8002000D`).

## Console testing needs

For the later input phases you will need a USB keyboard and mouse
plugged into the PS4 (the console accepts them natively; the app has to
read them itself, which is Phase 3 of the port). The DualShock 4
touchpad works as a pointer in the meantime — that is what the touchpad
smoke test proves.
