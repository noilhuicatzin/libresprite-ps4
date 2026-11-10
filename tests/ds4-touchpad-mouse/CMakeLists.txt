# DS4 touchpad mouse smoke test for PS4 — SKETCH, not built by CI yet.
#
# Built with the same PS4 toolchain as the app; links the cross-built
# SDL2 from prefix/ plus libScePad (already in the toolchain link line).
cmake_minimum_required(VERSION 3.5)
project(ds4-touchpad-mouse C)

find_package(SDL2 2.0.18 REQUIRED)

add_executable(ds4-touchpad-mouse main.c)
target_link_libraries(ds4-touchpad-mouse PRIVATE SDL2::SDL2)
