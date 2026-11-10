# Minimal SDL_Renderer smoke test for PS4. Built with the same PS4
# toolchain as the app; links the cross-built SDL2 from prefix/.
cmake_minimum_required(VERSION 3.5)
project(sdl-renderer-smoke C)

find_package(SDL2 2.0.18 REQUIRED)

add_executable(sdl-renderer-smoke main.c)
target_link_libraries(sdl-renderer-smoke PRIVATE SDL2::SDL2)
