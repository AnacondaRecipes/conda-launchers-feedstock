@echo on
REM Standalone build of all four conda-launchers executables on a win-64 host.
REM   cli-64.exe / gui-64.exe       - ucrt64 GCC (native x64)
REM   cli-arm64.exe / gui-arm64.exe - MSVC x64 -> arm64 cross (cl.exe -MACHINE:ARM64)
REM
REM One-time prerequisites:
REM   C:\miniconda3\Scripts\conda.exe install -y -n base -c pkgs/main --override-channels git conda-build m2-patch
REM   C:\miniconda3\Scripts\conda.exe create -y -n ucrt -c pkgs/main --override-channels ucrt64-gcc-toolchain_win-64 msys2-bash msys2-coreutils
REM   VS 2022 BuildTools with Microsoft.VisualStudio.Component.VC.Tools.ARM64
REM   (fresh bootstrapper: curl -L -O https://aka.ms/vs/17/release/vs_buildtools.exe, then
REM    vs_buildtools.exe modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --quiet --wait)
REM
REM Usage:  bld.bat [work-dir]     (default: src-build\launcher-build)
REM Override ucrt env location with:  set UCRT_ENV=C:\path\to\env
setlocal EnableDelayedExpansion

set "UPSTREAM_TAG=24.7.1-5"
set "ROOT=%~dp0"
set "WORK=%~1"
if "%WORK%"=="" set "WORK=%ROOT%launcher-build"
if "%UCRT_ENV%"=="" set "UCRT_ENV=C:\miniconda3\envs\ucrt"

set "PATCH_EXE=patch.exe"
where patch.exe >nul 2>nul
if errorlevel 1 set "PATCH_EXE=C:\miniconda3\Library\usr\bin\patch.exe"

if not exist "%WORK%" mkdir "%WORK%"
cd /d "%WORK%"

REM --- 1. Fetch upstream sources (idempotent) -------------------------------
if not exist cpython-launcher-c-mods-for-setuptools.3.7.patch (
  curl -L -O https://raw.githubusercontent.com/conda/conda-launchers/%UPSTREAM_TAG%/src/cpython-launcher-c-mods-for-setuptools.3.7.patch
  if errorlevel 1 exit /b 1
)
if not exist launcher.manifest (
  curl -L -O https://raw.githubusercontent.com/conda/conda-launchers/%UPSTREAM_TAG%/src/launcher.manifest
  if errorlevel 1 exit /b 1
)
if not exist launcher.c.orig (
  curl -L -o launcher.c.orig https://raw.githubusercontent.com/python/cpython/3.7/PC/launcher.c
  if errorlevel 1 exit /b 1
)

REM --- 2. Apply the upstream patch ------------------------------------------
if not exist launcher.c (
  "%PATCH_EXE%" -Np0 -i cpython-launcher-c-mods-for-setuptools.3.7.patch --binary
  if errorlevel 1 exit /b 1
  move /Y launcher.c.orig launcher.c
  if errorlevel 1 exit /b 1
)

REM --- 3. x64 exes via ucrt64 GCC -------------------------------------------
copy /Y "%ROOT%compile_launchers.sh" .
if errorlevel 1 exit /b 1
REM No login shell (-l): the msys2 profile needs coreutils and adds nothing here.
REM Invoke the script via explicit bash so the /usr/bin/env shebang is not relied on.
"%UCRT_ENV%\Library\usr\bin\bash.exe" -c "cd $(cygpath '%WORK%') && BUILD_PREFIX=$(cygpath '%UCRT_ENV%') target_platform=win-64 bash ./compile_launchers.sh"
if errorlevel 1 exit /b 1

REM --- 4. arm64 exes via MSVC cross (self-enters vcvarsall x64_arm64) -------
call "%ROOT%build_msvc.bat"
if errorlevel 1 exit /b 1

REM --- 5. Summary -------------------------------------------------------------
echo Built launchers in %WORK%:
dir /b *.exe
echo.
echo NOTE: arm64 exes cannot be executed on this x64 host. Smoke-test the x64
echo ones with:  %ROOT%run_test.bat %WORK%\cli-64.exe
endlocal
