@echo on
REM Adapted from conda/conda-launchers recipe/build-sh.bat
REM   https://github.com/conda/conda-launchers/blob/24.7.1-5/recipe/build-sh.bat
REM Original build.sh lineage:
REM   https://github.com/conda/conda-launchers/blob/24.7.1-5/recipe/build.sh
REM   https://github.com/conda/conda-build/blob/24.7.1/conda_build/launcher_sources/build.sh
setlocal EnableDelayedExpansion

set "BUILD_PREFIX_WIN=%BUILD_PREFIX%"
set "PREFIX_WIN=%PREFIX%"

REM win-64 has no separate _build_env (BUILD_PREFIX == PREFIX), so compile outside
REM the host prefix to avoid shipping build artifacts in the package.
if "%target_platform%"=="win-arm64" (
  set "LAUNCHER_BUILD_DIR=!BUILD_PREFIX_WIN!"
) else (
  set "LAUNCHER_BUILD_DIR=!SRC_DIR!\launcher-build"
  if not exist "!LAUNCHER_BUILD_DIR!" mkdir "!LAUNCHER_BUILD_DIR!"
)

REM Feedstock-specific: stage multi-source inputs into LAUNCHER_BUILD_DIR
copy /Y "%SRC_DIR%\cpython-launcher-c-mods-for-setuptools.3.7.patch" "!LAUNCHER_BUILD_DIR!\"
if !ERRORLEVEL! neq 0 exit /b 1
copy /Y "%SRC_DIR%\launcher.manifest" "!LAUNCHER_BUILD_DIR!\"
if !ERRORLEVEL! neq 0 exit /b 1
copy /Y "%SRC_DIR%\launcher.c.orig" "!LAUNCHER_BUILD_DIR!\"
if !ERRORLEVEL! neq 0 exit /b 1
cd /d "!LAUNCHER_BUILD_DIR!"

REM From build-sh.bat (patch step); patch is provided on PBP workers
patch.exe -Np0 -i cpython-launcher-c-mods-for-setuptools.3.7.patch --binary
if !ERRORLEVEL! neq 0 exit /b 1

move /Y launcher.c.orig launcher.c
if !ERRORLEVEL! neq 0 exit /b 1

REM Feedstock-specific: per-platform compiler dispatch
if "%target_platform%"=="win-arm64" (
  call "%RECIPE_DIR%\build_msvc.bat"
  if !ERRORLEVEL! neq 0 exit /b 1
  goto :install
)

REM From build-sh.bat (bash build.sh); win-64 gcc via compile_launchers.sh
set "MSYS2_BIN=%BUILD_PREFIX_WIN%\Library\usr\bin"
copy /Y "%RECIPE_DIR%\compile_launchers.sh" "!LAUNCHER_BUILD_DIR!\"
if !ERRORLEVEL! neq 0 exit /b 1

REM Already cd'd into LAUNCHER_BUILD_DIR; run the script from cwd (no cygpath needed)
"!MSYS2_BIN!\bash.exe" ./compile_launchers.sh
if !ERRORLEVEL! neq 0 exit /b 1

:install
REM Feedstock-specific: install to share/conda-launchers (upstream uses PREFIX\Scripts)
set "ARCH_SUFFIX=64"
if "%target_platform%"=="win-arm64" set "ARCH_SUFFIX=arm64"

set "target_dir=%PREFIX_WIN%\share\conda-launchers"
mkdir "%target_dir%"
if !ERRORLEVEL! neq 0 exit /b 1

copy /Y "!LAUNCHER_BUILD_DIR!\cli-%ARCH_SUFFIX%.exe" "%target_dir%\"
if !ERRORLEVEL! neq 0 exit /b 1
copy /Y "!LAUNCHER_BUILD_DIR!\gui-%ARCH_SUFFIX%.exe" "%target_dir%\"
if !ERRORLEVEL! neq 0 exit /b 1
