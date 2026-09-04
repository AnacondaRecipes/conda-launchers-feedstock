@echo on
REM Cross-compile win-arm64 launchers on an x64 host (PBP dev instance).
REM Adapted from the MSVC (vs*) branch of conda/conda-launchers recipe/build.sh
REM   https://github.com/conda/conda-launchers/blob/24.7.1-5/recipe/build.sh
REM
REM Prerequisites:
REM   - VS 2022 BuildTools with Microsoft.VisualStudio.Component.VC.Tools.ARM64
REM     (install with a fresh bootstrapper from https://aka.ms/vs/17/release/vs_buildtools.exe)
REM   - A Windows SDK with arm64 libs (e.g. Microsoft.VisualStudio.Component.Windows11SDK.22621)
REM   - Patched launcher.c and launcher.manifest in the CURRENT directory
REM     (see bld.bat for the patch step).
REM
REM Note: the produced arm64 exes cannot be executed on the x64 host;
REM verify by existence + signature only.
REM
REM NOTE for editors: never echo a path containing "(x86)" inside a
REM parenthesized if()-block - the ")" closes the block early. Error paths
REM below use goto labels for that reason.
setlocal EnableExtensions EnableDelayedExpansion

set "VSBT=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
set "VCTOOLS=%VSBT%\VC\Tools\MSVC"
set "SDKLIB=C:\Program Files (x86)\Windows Kits\10\Lib"

REM --- Pre-flight 1: ARM64 cross compiler present? --------------------------
if not exist "%VCTOOLS%" goto :err_no_msvc

REM pick the highest-versioned toolset that actually ships the ARM64 cross
REM compiler (vcvarsall defaults to an older toolset that may lack it).
REM !VCTOOLS! (delayed expansion) because the path contains "(x86)".
set "TOOLSET="
for /f "delims=" %%D in ('dir /b /ad /on "%VCTOOLS%"') do (
  if exist "!VCTOOLS!\%%D\bin\Hostx64\ARM64\cl.exe" set "TOOLSET=%%D"
)
if not defined TOOLSET goto :err_no_arm64_cl
goto :preflight1_ok

:err_no_msvc
echo ERROR: MSVC tools dir not found: %VCTOOLS%
exit /b 1

:err_no_arm64_cl
echo ERROR: no MSVC toolset under %VCTOOLS% ships bin\Hostx64\ARM64\cl.exe
echo The VC.Tools.ARM64 component is missing or did not install. Retry with a
echo FRESH bootstrapper from https://aka.ms/vs/17/release/vs_buildtools.exe :
echo   vs_buildtools.exe modify --installPath "%VSBT%" --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --quiet --wait
echo then check %%TEMP%%\dd_installer_*.log if it still is not there.
exit /b 1

:preflight1_ok

REM --- Pre-flight 2: a Windows SDK with arm64 libs --------------------------
set "SDKVER="
for /f "delims=" %%D in ('dir /b /ad /on "%SDKLIB%"') do if exist "%SDKLIB%\%%D\um\arm64" set "SDKVER=%%D"
if not defined SDKVER goto :err_no_sdk
goto :preflight2_ok

:err_no_sdk
echo ERROR: no Windows SDK with arm64 libs found under %SDKLIB%
echo Add one with:
echo   vs_buildtools.exe modify --installPath "%VSBT%" --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --quiet --wait
exit /b 1

:preflight2_ok
echo Using MSVC toolset %TOOLSET% and Windows SDK %SDKVER%

REM --- Enter the x64_arm64 cross environment, pinned to the good SDK --------
REM (no parenthesized block here: %VSBT% contains "(x86)", which would close it)
where cl.exe >nul 2>nul
if not errorlevel 1 goto :vcvars_done
call "%VSBT%\VC\Auxiliary\Build\vcvarsall.bat" x64_arm64 %SDKVER% -vcvars_ver=%TOOLSET%
if errorlevel 1 exit /b 1
:vcvars_done

REM --- Pre-flight 3: the cl.exe on PATH must be the ARM64-targeting one -----
set "CL_FIRST="
for /f "delims=" %%C in ('where cl.exe') do if not defined CL_FIRST set "CL_FIRST=%%C"
echo %CL_FIRST% | findstr /I "\\ARM64\\" >nul
if errorlevel 1 goto :err_wrong_cl
goto :preflight3_ok

:err_wrong_cl
echo ERROR: cl.exe on PATH is not the ARM64 cross compiler:
where cl.exe
exit /b 1

:preflight3_ok

set "ARCH_SUFFIX=arm64"
set "CL_MACHINE=ARM64"

REM From build.sh (resource script + rc.exe)
(
echo #include "winuser.h"
echo 1 RT_MANIFEST launcher.manifest
)> resources.rc
if %ERRORLEVEL% neq 0 exit /b 1

rc.exe resources.rc
if %ERRORLEVEL% neq 0 exit /b 1
move /Y resources.res resources-%ARCH_SUFFIX%.res
if %ERRORLEVEL% neq 0 exit /b 1

REM From build.sh (cl.exe compile loop); -ZI removed, version.lib omitted for arm64
cl.exe -DSCRIPT_WRAPPER -DNDEBUG -DWIN32_LEAN_AND_MEAN -Gy -MT -Os launcher.c -link -MACHINE:%CL_MACHINE% -SUBSYSTEM:CONSOLE resources-%ARCH_SUFFIX%.res user32.lib advapi32.lib shell32.lib -out:cli-%ARCH_SUFFIX%.exe
if %ERRORLEVEL% neq 0 exit /b 1

cl.exe -DSCRIPT_WRAPPER -DNDEBUG -DWIN32_LEAN_AND_MEAN -D_WINDOWS -Gy -MT -Os launcher.c -link -MACHINE:%CL_MACHINE% -SUBSYSTEM:WINDOWS resources-%ARCH_SUFFIX%.res user32.lib advapi32.lib shell32.lib -out:gui-%ARCH_SUFFIX%.exe
if %ERRORLEVEL% neq 0 exit /b 1

endlocal
