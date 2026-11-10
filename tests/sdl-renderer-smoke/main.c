/* SDL_Renderer smoke test for PS4 (Piglet) — FIRST MILESTONE of the
 * LibreSprite port.
 *
 * The Solarus GL smoke test proved raw OpenGL ES 2.0 works on this PS4
 * (SDL_Init + SDL_CreateWindow + SDL_GL_CreateContext + glClear). What
 * NOBODY has proven is SDL_Renderer on top of the PS4 video driver — and
 * LibreSprite's `she` SDL2 backend draws through SDL_Renderer
 * (SDL_CreateRenderer(SDL_RENDERER_ACCELERATED) + streaming textures),
 * not raw GL. If this test fails, the port needs a different render path
 * (raw GL backend in `she`, or the SDLTexture plan B from the study)
 * before a single line of app code matters.
 *
 * Writes a step-by-step log to /data/sdl-renderer-smoke.log (flushed
 * after every line) so an instant crash on console can be pinpointed from
 * the last line in the file — the same approach as the SoH ps4_boot.log.
 * Packaged as its own .pkg ("LibreSprite SDL Test", LBSP00002).
 */
#include <SDL.h>
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

    diag_log = fopen("/data/sdl-renderer-smoke.log", "w");
    dlog("[diag] sdl-renderer-smoke start");

    /* Load the Piglet + Shacc modules from the known-good location
     * instead of SDL's default sandbox path. */
    SDL_SetHint(SDL_HINT_PS4_PIGLET_MODULES_PATH, "/data/self/system/common/lib");
    dlog("[diag] piglet hint set to /data/self/system/common/lib");

    {
        char buf[512];
        int n = SDL_GetNumVideoDrivers();
        snprintf(buf, sizeof(buf), "[diag] video drivers in build: %d", n);
        dlog(buf);
        for (int i = 0; i < n; i++) {
            snprintf(buf, sizeof(buf), "[diag] video driver[%d] = %s", i, SDL_GetVideoDriver(i));
            dlog(buf);
        }
    }

    dlog("[diag] SDL_Init(VIDEO)...");
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] SDL_Init(VIDEO) failed: %s", SDL_GetError());
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 1;
    }
    dlog("[diag] SDL_Init(VIDEO) ok");

    dlog("[diag] SDL_CreateWindow...");
    SDL_Window *win = SDL_CreateWindow("LibreSprite SDL renderer smoke test",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        1280, 720, SDL_WINDOW_OPENGL);
    if (!win) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] SDL_CreateWindow failed: %s", SDL_GetError());
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 2;
    }
    dlog("[diag] SDL_CreateWindow ok");

    /* THE test: an accelerated renderer on the PS4 driver. */
    dlog("[diag] SDL_CreateRenderer(ACCELERATED)...");
    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!ren) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] ACCELERATED renderer failed: %s", SDL_GetError());
        dlog(buf);
        /* Diagnostic only: does ANY renderer work here? */
        dlog("[diag] retry SDL_CreateRenderer(SOFTWARE) for diagnosis...");
        ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE);
        if (!ren) {
            snprintf(buf, sizeof(buf), "[diag] SOFTWARE renderer also failed: %s", SDL_GetError());
            dlog(buf);
            if (diag_log) fclose(diag_log);
            return 3;
        }
        dlog("[diag] SOFTWARE renderer ok (accelerated is broken — see BUILD.md plan B)");
    } else {
        SDL_RendererInfo info;
        char buf[512];
        if (SDL_GetRendererInfo(ren, &info) == 0) {
            snprintf(buf, sizeof(buf), "[diag] renderer name=%s flags=0x%x max_texture=%dx%d",
                info.name, (unsigned)info.flags,
                info.max_texture_width, info.max_texture_height);
            dlog(buf);
        }
        dlog("[diag] ACCELERATED renderer ok");
    }

    /* Streaming texture, the way `she` draws: fill a checker pattern,
     * upload it, and present it scaled for ~3 seconds. */
    dlog("[diag] SDL_CreateTexture(STREAMING)...");
    SDL_Texture *tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING, 256, 256);
    if (!tex) {
        char buf[512];
        snprintf(buf, sizeof(buf), "[diag] SDL_CreateTexture failed: %s", SDL_GetError());
        dlog(buf);
        if (diag_log) fclose(diag_log);
        return 4;
    }
    dlog("[diag] SDL_CreateTexture ok");

    {
        void *pixels = NULL;
        int pitch = 0;
        if (SDL_LockTexture(tex, NULL, &pixels, &pitch) != 0) {
            char buf[512];
            snprintf(buf, sizeof(buf), "[diag] SDL_LockTexture failed: %s", SDL_GetError());
            dlog(buf);
            if (diag_log) fclose(diag_log);
            return 5;
        }
        for (int y = 0; y < 256; y++) {
            uint32_t *row = (uint32_t *)((uint8_t *)pixels + y * pitch);
            for (int x = 0; x < 256; x++) {
                int checker = ((x / 32) + (y / 32)) & 1;
                row[x] = checker ? 0xFFFF8000u : 0xFF202020u; /* orange / dark grey */
            }
        }
        SDL_UnlockTexture(tex);
    }
    dlog("[diag] texture filled (checker)");

    for (int i = 0; i < 180; i++) {
        SDL_SetRenderDrawColor(ren, 16, 16, 32, 255);
        SDL_RenderClear(ren);
        SDL_RenderCopy(ren, tex, NULL, NULL);
        SDL_RenderPresent(ren);
        SDL_Delay(16);
    }
    dlog("[diag] RENDERER_OK");

    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    if (diag_log) fclose(diag_log);
    return 0;
}
