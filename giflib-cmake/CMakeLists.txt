# CMake wrapper to build giflib 5.2.2 (which ships no CMakeLists.txt) as a
# static library for PS4.
#
#   cmake -DGIFLIB_SRC=<path to extracted giflib-5.2.2> ...
#
# Only the library sources are compiled (the gif* tools — gif2rgb, gifbg,
# giffilter, ... — are separate programs and are excluded). No config.h is
# generated: giflib's headers guard everything behind HAVE_CONFIG_H, so a
# plain build uses the defaults, which is how other bare-Makefile builds
# of giflib work too.
cmake_minimum_required(VERSION 3.5)
project(giflib C)

set(GIFLIB_SRC "" CACHE PATH "giflib 5.2.2 source directory (extracted tarball)")
if(NOT GIFLIB_SRC)
    message(FATAL_ERROR "GIFLIB_SRC is required")
endif()

add_library(gif STATIC
    "${GIFLIB_SRC}/dgif_lib.c"
    "${GIFLIB_SRC}/egif_lib.c"
    "${GIFLIB_SRC}/gif_err.c"
    "${GIFLIB_SRC}/gif_hash.c"
    "${GIFLIB_SRC}/gifalloc.c"
    "${GIFLIB_SRC}/openbsd-reallocarray.c"
    "${GIFLIB_SRC}/quantize.c")
target_include_directories(gif PUBLIC "${GIFLIB_SRC}")

install(TARGETS gif ARCHIVE DESTINATION lib)
install(FILES "${GIFLIB_SRC}/gif_lib.h" DESTINATION include)
