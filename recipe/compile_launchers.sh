#!/usr/bin/env bash
# Adapted from the gcc branch of conda/conda-launchers recipe/build.sh
#   https://github.com/conda/conda-launchers/blob/24.7.1-5/recipe/build.sh
# Original lineage:
#   https://github.com/conda/conda-build/blob/24.7.1/conda_build/launcher_sources/build.sh
# win-64 only; see build_msvc.bat for the win-arm64 MSVC path.

set -euxo pipefail

_ARCH=${target_platform#*-}

# ucrt64-gcc-toolchain_win-64 from pkgs/main
UCRT64_BIN="${BUILD_PREFIX}/Library/ucrt64/bin"
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
