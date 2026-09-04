#!/usr/bin/env bash
# Build win-64 (x64) launchers with the ucrt64 GCC toolchain.
# Adapted from the gcc branch of conda/conda-launchers recipe/build.sh
#   https://github.com/conda/conda-launchers/blob/24.7.1-5/recipe/build.sh
# Original lineage:
#   https://github.com/conda/conda-build/blob/24.7.1/conda_build/launcher_sources/build.sh
#
# Manual usage on a dev instance (run under msys2-bash from the ucrt64 toolchain env):
#   conda create -y -n ucrt -c pkgs/main --override-channels ucrt64-gcc-toolchain_win-64 msys2-bash
#   BUILD_PREFIX="$(cygpath 'C:\path\to\ucrt-env')" target_platform=win-64 \
#     bash compile_launchers.sh
# Expects patched launcher.c and launcher.manifest in the current directory.

set -euxo pipefail

_ARCH=${target_platform:-win-64}
_ARCH=${_ARCH#*-}

# ucrt64-gcc-toolchain_win-64 from pkgs/main
UCRT64_BIN="${BUILD_PREFIX:?Set BUILD_PREFIX to the conda env with ucrt64-gcc-toolchain_win-64}/Library/ucrt64/bin"
export PATH="${UCRT64_BIN}:${PATH}"
CC="${CC:-${UCRT64_BIN}/gcc}"
WINDRES="${WINDRES:-${UCRT64_BIN}/windres}"

# From build.sh (windres resource compilation)
echo "#include \"winuser.h\"" > resources.rc
echo "1 RT_MANIFEST launcher.manifest" >> resources.rc
${WINDRES:-windres} --input resources.rc --output resources-${_ARCH}.res --output-format=coff -v

# From build.sh (gcc compile loop)
for _TYPE in cli gui; do
  if [[ ${_TYPE} == cli ]]; then
    CPPFLAGS=
    LDFLAGS=
  else
    CPPFLAGS="-D_WINDOWS -mwindows"
    LDFLAGS="-mwindows"
  fi

  ${CC} -O2 -DSCRIPT_WRAPPER -DUNICODE -D_UNICODE -DMINGW_HAS_SECURE_API -DMAXINT=INT_MAX ${CPPFLAGS} \
    launcher.c -c -o ${_TYPE}-${_ARCH}.o

  ${CC} -Wl,-s --static -static-libgcc -municode ${LDFLAGS} \
    ${_TYPE}-${_ARCH}.o resources-${_ARCH}.res -o ${_TYPE}-${_ARCH}.exe
done
