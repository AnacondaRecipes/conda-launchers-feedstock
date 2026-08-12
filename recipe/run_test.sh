set -ex
test -f "${PREFIX}/share/conda-launchers/cli-32.exe"
test -f "${PREFIX}/share/conda-launchers/gui-32.exe"
test -f "${PREFIX}/share/conda-launchers/cli-64.exe"
test -f "${PREFIX}/share/conda-launchers/gui-64.exe"
test -f "${PREFIX}/share/conda-launchers/cli-arm64.exe"
test -f "${PREFIX}/share/conda-launchers/gui-arm64.exe"
