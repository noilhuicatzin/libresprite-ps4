# DS4 touchpad mouse — sketch for milestone 2

## Why this exists

LibreSprite lives on mouse events. SDL on PS4 delivers none: the PS4
video driver leaves `PS4_InitMouse()` commented out and there is no
`SDL_ps4mouse.c`. The first mouse that can work without new hardware is
the DS4 touchpad, read directly with `scePadReadState()` — the same call
SDL's own PS4 joystick driver already uses.

## Design (what the sketch proves)

- `scePadInit()` + `scePadOpen(0, STANDARD, 0, NULL)` give a pad handle.
- `scePadReadState()` fills `OrbisPadData`; `data.touch.fingers` (0..2)
  says whether a finger is down, `data.touch.touch[0].x/.y` is the
  absolute position.
- `scePadGetControllerInformation()` gives `touchResolutionX/Y`
  (1920x943 on DS4); the sketch scales that to the 1280x720 window.
- A touchpad click (`ORBIS_PAD_BUTTON_TOUCH_PAD`, 0x100000) draws a dot
  — one run proves movement *and* clicking.

All field names were verified against the OpenOrbis toolchain headers
(`include/orbis/_types/pad.h`, master, 2026-11-10). See the header
comment in `main.c`.

## Open questions (first console run)

1. **Double open**: SDL's joystick driver opens the pad itself. Does a
   second `scePadOpen()` for the same user work, or does it fail / steal
   the pad? If it fails, the mouse driver must read the touch data from
   SDL's joystick layer instead (SDL does not expose it today — that
   would mean patching the SDL driver to surface touch as mouse motion).
2. **Density**: `OrbisPadInformation.touchpadDensity` — are the
   coordinates already absolute, or do they need the density factor?
   The sketch logs the resolution and assumes absolute; the log + the
   on-screen cursor will show whether the mapping is 1:1.
3. **Second finger**: two-finger touch (right-click? scroll?) is out of
   scope for the smoke test; `touch[1]` is there when needed.

## Next step after this smoke test passes

Wire it into the app as a real mouse source: the `she` SDL backend
reads `scePadReadState()` per frame and pushes `SDL_MOUSEMOTION` /
`SDL_MOUSEBUTTONDOWN` events (or the app-side equivalent), with the
sticks as a fallback virtual mouse. That is Phase 3 of the port (see
`BUILD.md`); this sketch is only the proof that the hardware path works.
