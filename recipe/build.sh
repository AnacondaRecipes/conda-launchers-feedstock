#!/usr/bin/env bash
set -euxo pipefail

target_dir="${PREFIX}/share/conda-launchers"
mkdir -p "${target_dir}"

for f in cli-64.exe gui-64.exe cli-arm64.exe gui-arm64.exe; do
  cp "${SRC_DIR}/${f}" "${target_dir}/${f}"
done
