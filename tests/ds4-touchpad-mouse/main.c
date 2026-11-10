/* DS4 touchpad mouse smoke test for PS4 — SKETCH (second milestone).
 *
 * LibreSprite lives on mouse events. SDL on PS4 delivers none: the
 * PS4 video driver leaves PS4_InitMouse() commented out (see
 * SDL_ps4video.c, "TODO" block) and there is no SDL_ps4mouse.c. The
 * first mouse that can work without new hardware is the DS4 touchpad,
 * read directly with scePadReadState() — the same call SDL's own PS4
 * joystick driver already uses, so the data is there.
 *
 * What this test does: opens the pad, reads the touchpad in a loop and
 * moves an SDL-drawn cursor (a small square) with finger 0. A touchpad
 * click (or Cross) draws a dot where the cursor is, so a single run
 * proves both movement and clicking. Logs to
 * /data/ds4-touchpad-mouse.log (flushed per line).
 *
 * Field names verified against the OpenOrbis toolchain headers
 * (include/orbis/_types/pad.h, master, 2026-11-10):
 *   OrbisPadData.touch.fingers            (uint8_t, 0..2)
 *   OrbisPadData.touch.touch[0].x/.y      (uint16_t, absolute)
 *   OrbisPadInformation.touchResolutionX/Y (uint16_t, 1920x943 on DS4)
 *   ORBIS_PAD_BUTTON_TOUCH_PAD            (0x100000, touchpad click)
 *   scePadInit / scePadOpen / scePadReadState /
 *   scePadGetControllerInformation
 *
 * Open questions for the first console run (see README.md): whether a
 * second scePadOpen() alongside SDL's own joystick driver works, and
 * whether the touch coordinates need the density factor
 * (OrbisPadInformation.touchpadDensity) or are already absolute.
 */
#include <SDL.h>
#include <orbis/Pad.h>
#include <stdio.h>

static FILE *diag_log;

static void dlog(const char *msg)
{
    if (diag_log) {
        fprintf(diag_log, "%s\n", msg);
        fflush(diag_log);
    }
    SDL_Log("%s", msg);
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;

    diag_log = fopen("/data/ds4-touchpad-mouse.log", "w");
    dlog("[diag] ds4-touchpad-mouse start");

    SDL_SetHint(SDL_HINT_PS4_PIGLET_MODULES_PATH, "/data/self/system/common/lib");

    dlog("[diag] SDL_Init(VIDEO)...");
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK) != 0) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] SDL_Init failed: %s", SDL_GetError());
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 1;
    }
    dlog("[diag] SDL_Init ok");

    dlog("[diag] scePadInit...");
    if (scePadInit() != 0) {
        dlog("[diag] scePadInit failed");
        if (diag_log) fclose(diag_log);
        return 2;
    }
    dlog("[diag] scePadInit ok");

    dlog("[diag] scePadOpen(user 0)...");
    int pad = scePadOpen(0, ORBIS_PAD_PORT_TYPE_STANDARD, 0, NULL);
    if (pad < 0) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] scePadOpen failed: %d", pad);
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 3;
    }
    {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] scePadOpen ok, handle=%d", pad);
        dlog(buf);
    }

    int resX = 1920, resY = 943; /* DS4 defaults; overwritten below if known */
    OrbisPadInformation info;
    if (scePadGetControllerInformation(pad, &info) == 0 && info.touchResolutionX > 0) {
        resX = info.touchResolutionX;
        resY = info.touchResolutionY;
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] touch resolution %dx%d density=%f",
            resX, resY, (double)info.touchpadDensity);
        dlog(buf);
    } else {
        dlog("[diag] touch resolution unknown, using 1920x943 defaults");
    }

    SDL_Window *win = SDL_CreateWindow("DS4 touchpad mouse smoke test",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        1280, 720, SDL_WINDOW_OPENGL);
    if (!win) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] SDL_CreateWindow failed: %s", SDL_GetError());
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 4;
    }
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!ren) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] SDL_CreateRenderer failed: %s", SDL_GetError());
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 5;
    }
    dlog("[diag] window + renderer ok — touch the pad to move the cursor");

    int cursorX = 640, cursorY = 360;
    int prevTouching = 0;
    for (int frame = 0; frame < 60 * 30; frame++) { /* 30 s */
        OrbisPadData data;
        if (scePadReadState(pad, &data) == 0 && data.touch.fingers > 0) {
            int tx = data.touch.touch[0].x;
            int ty = data.touch.touch[0].y;
            cursorX = tx * 1280 / resX;
            cursorY = ty * 720 / resY;
            if (!prevTouching) {
                char buf[512];
                snprintf(buf, sizeof(buf), "[diag] touch start: pad %d,%d -> screen %d,%d",
                    tx, ty, cursorX, cursorY);
                dlog(buf);
            }
            prevTouching = 1;
            if (data.buttons & ORBIS_PAD_BUTTON_TOUCH_PAD) {
                SDL_SetRenderDrawColor(ren, 255, 128, 0, 255);
                SDL_Rect dot = { cursorX - 6, cursorY - 6, 12, 12 };
                SDL_RenderFillRect(ren, &dot);
            }
        } else {
            prevTouching = 0;
        }

        SDL_SetRenderDrawColor(ren, 16, 16, 32, 255);
        SDL_RenderClear(ren);
        SDL_SetRenderDrawColor(ren, 255, 255, 255, 255);
        SDL_Rect cursor = { cursorX - 8, cursorY - 8, 16, 16 };
        SDL_RenderFillRect(ren, &cursor);
        SDL_RenderPresent(ren);
        SDL_Delay(16);

        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_QUIT)
                frame = 60 * 30;
        }
    }
    dlog("[diag] TOUCHPAD_OK");

    scePadClose(pad);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    if (diag_log) fclose(diag_log);
    return 0;
}
