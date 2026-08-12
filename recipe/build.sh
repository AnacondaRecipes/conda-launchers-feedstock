set -ex

target_dir="${PREFIX}/share/conda-launchers"
mkdir -p "${target_dir}"

cp cli-32-*.exe "${target_dir}/cli-32.exe"
cp gui-32-*.exe "${target_dir}/gui-32.exe"
cp cli-64-*.exe "${target_dir}/cli-64.exe"
cp gui-64-*.exe "${target_dir}/gui-64.exe"
cp cli-arm64-*.exe "${target_dir}/cli-arm64.exe"
cp gui-arm64-*.exe "${target_dir}/gui-arm64.exe"