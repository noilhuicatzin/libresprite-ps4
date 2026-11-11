/* Force-included into every translation unit of the PS4 build (see cmake/ps4-toolchain.cmake).
 *
 * OpenOrbis v0.5.4 declares mode_t as `unsigned int` in <bits/alltypes.h>. The PS4 kernel (a
 * FreeBSD 9 derivative) uses a 16-bit mode_t, and the C library's stat()/fstat()/lstat() hand
 * the kernel's `struct stat` straight to the caller without converting it. With a 32-bit
 * mode_t every member after st_mode sits 8 bytes too far: st_size reads st_blocks, the
 * timestamps are garbage, and anything that trusts them breaks. That is why libzip could not
 * open a single archive by path ("not a zip archive": it looked for the central directory at
 * the wrong offset).
 *
 * <bits/alltypes.h> only defines a type when its __DEFINED_ guard is not set, so claiming
 * mode_t here, before any system header, gives every header the kernel's layout.
 *
 * Passing a 16-bit mode_t to the prebuilt C library (mkdir, chmod, open...) is fine: the value
 * travels zero-extended in a 32-bit register either way.
 */
#ifndef PS4_FIXUPS_H
#define PS4_FIXUPS_H

#if !defined(__ASSEMBLER__) && !defined(__DEFINED_mode_t)
typedef unsigned short mode_t;
#define __DEFINED_mode_t
#endif

/* The OpenOrbis headers do not declare the BSD file-flags functions, even
 * though libkernel.so exports chflags/fchflags (lchflags does not exist).
 * Without a declaration, Clang 18 errors on the implicit function
 * declaration whenever code calls them under HAVE_CHFLAGS/HAVE_FCHFLAGS
 * (configure sets those when it links against libkernel). Note: with these
 * declarations present, CMake's own check_function_exists test fails on
 * conflicting types (it declares `char chflags();`), so a fresh configure
 * reports the functions absent and callers take their fallback path — also
 * fine. Declare them here so either outcome builds; u_long is unsigned long
 * on PS4. */
#if !defined(__ASSEMBLER__)
#ifdef __cplusplus
extern "C" {
#endif
int chflags(const char *, unsigned long);
int fchflags(int, unsigned long);
int lchflags(const char *, unsigned long);
#ifdef __cplusplus
}
#endif
#endif

#endif /* PS4_FIXUPS_H */
