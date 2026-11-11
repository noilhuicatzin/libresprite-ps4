#!/usr/bin/env bash
# Turns an .elf into an installable PS4 package (libresprite-ps4/out/*.pkg).
#
# Parameterized with environment variables so the same script packages both
# the app and the SDL renderer smoke test:
#   TITLE, TITLE_ID, CONTENT_ID, VERSION, ELF  (defaults: LibreSprite app)
#
# The package contains the app binary AND the app data/ tree (24 MB, mostly
# fonts) under /app0/data/: the PS4 paths patch makes the app look for data
# in /data/libresprite/data/ first (user data, uploaded by FTP) and fall
# back to /app0/data/ (bundled here), so the package works the moment it
# is installed, with no separate data upload. See docs/INSTALL.md.
#
# License note (GPLv2): this repo carries only patches, scripts and the
# workflow — never the .pkg and never the app data. The .pkg is a CI
# artifact for personal use on the owner's own console, not a release.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/env.sh"

TITLE="${TITLE:-LibreSprite}"
# LibreSprite app: Title ID LBSP00001, so installing this package updates it
# instead of creating a second entry.
VERSION="${VERSION:-01.00}"
TITLE_ID="${TITLE_ID:-LBSP00001}"
CONTENT_ID="${CONTENT_ID:-IV0000-LBSP00001_00-LIBRESPRITE00000}"
ELF="${ELF:-$HERE/build/bin/libresprite.elf}"
# System auth info + program id used by the OpenOrbis Piglet sample: needed to load Piglet.
AUTHINFO="000000000000000000000000001C004000FF000000000080000000000000000000000000000000000000008000400040000000000000008000000000000000080040FFFF000000F000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
PAID="0x3800000000000035"

OO="$OO_PS4_TOOLCHAIN"
BIN="$OO/bin/windows"
STAGE="$HERE/pkg"
OUT="${OUT_DIR:-$HERE/out}"

[ -f "$ELF" ] || { echo "missing $ELF, build first"; exit 1; }
# Resolve ELF to an absolute path now: create-fself runs after `cd "$STAGE"`,
# so a relative ELF would no longer resolve (Solarus run #17 smoke-test failure).
ELF="$(cd "$(dirname "$ELF")" && pwd)/$(basename "$ELF")"
# Same for OUT: pkg build runs after `cd "$STAGE"`, so a relative OUT_DIR
# (out-smoke) would resolve under pkg/ and the .pkg write would fail
# with DirectoryNotFoundException (Solarus run #19 smoke-test failure).
case "$OUT" in
  /*) ;;
  *) OUT="$HERE/$OUT" ;;
esac

# Data payload: only the app package bundles data/ (the smoke test passes
# ELF + OUT_DIR + TITLE_ID/CONTENT_ID and skips it via SKIP_DATA=1).
DATA_SRC="$HERE/../libresprite/data"
if [ "${SKIP_DATA:-0}" != "1" ]; then
    [ -d "$DATA_SRC" ] || { echo "missing $DATA_SRC — run scripts/prepare-sources.sh first"; exit 1; }
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/sce_sys/about" "$STAGE/sce_module" "$OUT"
cp "$HERE/pkg-static/sce_sys/icon0.png" "$STAGE/sce_sys/icon0.png"
cp "$OO/samples/piglet/sce_sys/about/right.sprx" "$STAGE/sce_sys/about/right.sprx"
cp "$OO/samples/piglet/sce_module/libc.prx" "$OO/samples/piglet/sce_module/libSceFios2.prx" "$STAGE/sce_module/"
if [ "${SKIP_DATA:-0}" != "1" ]; then
    cp -r "$DATA_SRC" "$STAGE/data"
fi

cd "$STAGE"

"$BIN/create-fself.exe" -in="$(cygpath -m "$ELF")" -out="$(cygpath -m "$HERE/build/eboot.oelf")" \
    --eboot "eboot.bin" --paid "$PAID" --authinfo "$AUTHINFO"

SFO=sce_sys/param.sfo
P="$BIN/PkgTool.Core.exe"
"$P" sfo_new $SFO
"$P" sfo_setentry $SFO APP_TYPE --type Integer --maxsize 4 --value 1
"$P" sfo_setentry $SFO APP_VER --type Utf8 --maxsize 8 --value "$VERSION"
"$P" sfo_setentry $SFO ATTRIBUTE --type Integer --maxsize 4 --value 0
"$P" sfo_setentry $SFO CATEGORY --type Utf8 --maxsize 4 --value "gde"
"$P" sfo_setentry $SFO FORMAT --type Utf8 --maxsize 4 --value "obs"
"$P" sfo_setentry $SFO CONTENT_ID --type Utf8 --maxsize 48 --value "$CONTENT_ID"
"$P" sfo_setentry $SFO DOWNLOAD_DATA_SIZE --type Integer --maxsize 4 --value 0
"$P" sfo_setentry $SFO SYSTEM_VER --type Integer --maxsize 4 --value 1020
"$P" sfo_setentry $SFO TITLE --type Utf8 --maxsize 128 --value "$TITLE"
"$P" sfo_setentry $SFO TITLE_ID --type Utf8 --maxsize 12 --value "$TITLE_ID"
"$P" sfo_setentry $SFO VERSION --type Utf8 --maxsize 8 --value "$VERSION"

# gp4 file list: the fixed files plus every bundled data/ file (data/
# filenames have no spaces upstream; if one ever appears, this list
# breaks and the pkg build fails loudly instead of silently dropping it).
FILES="eboot.bin sce_sys/about/right.sprx sce_sys/param.sfo sce_sys/icon0.png sce_module/libc.prx sce_module/libSceFios2.prx"
if [ "${SKIP_DATA:-0}" != "1" ]; then
    FILES="$FILES $(find data -type f | sort | tr '\n' ' ')"
fi
"$BIN/create-gp4.exe" -out pkg.gp4 --content-id="$CONTENT_ID" --files "$FILES"

# create-gp4.exe hardcodes <rootdir> to its template (sce_sys/about,
# sce_module, assets/{audio,fonts,images,misc,videos}) and never derives
# directories from --files. PkgTool's BuildFSTree looks up every file's
# parent dir in <rootdir>, so any file under data/ (or any other dir
# outside the template) crashes pkg_build with "Sequence contains no
# elements" (run #13). Fix <rootdir> up from the file list first.
python3 "$HERE/scripts/fix-gp4-rootdir.py" pkg.gp4

"$P" pkg_build pkg.gp4 "$(cygpath -m "$OUT")"
ls -la "$OUT"
