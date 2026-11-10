# Source this file: puts the portable build tools on PATH.
# Expected layout (this repository cloned as "libresprite-ps4" inside a workspace directory):
#   <workspace>/libresprite-ps4  this repository
#   <workspace>/libresprite      LibreSprite sources (cloned by scripts/prepare-sources.sh)
#   <workspace>/tools            llvm/, cmake-*/, ninja/, OpenOrbis/OpenOrbis/PS4Toolchain/
_LIBRESPRITEPS4_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PS4_ROOT="$(cd "$_LIBRESPRITEPS4_DIR/.." && pwd)"
_CMAKE_BIN="$(ls -d "$PS4_ROOT"/tools/cmake-*/bin 2>/dev/null | head -1)"
export PATH="$_CMAKE_BIN:$PS4_ROOT/tools/ninja:$PS4_ROOT/tools/llvm/bin:$PATH"
if command -v cygpath >/dev/null 2>&1; then
    export OO_PS4_TOOLCHAIN="$(cygpath -m "$PS4_ROOT/tools/OpenOrbis/OpenOrbis/PS4Toolchain")"
else
    export OO_PS4_TOOLCHAIN="$PS4_ROOT/tools/OpenOrbis/OpenOrbis/PS4Toolchain"
fi
# PkgTool.Core targets .NET Core 3.0; let it run on whatever newer runtime is installed.
export DOTNET_ROLL_FORWARD=LatestMajor
