@echo on
REM Adapted from the MSVC (vs*) branch of conda/conda-launchers recipe/build.sh
REM   https://github.com/conda/conda-launchers/blob/24.7.1-5/recipe/build.sh
REM Invoked from bld.bat on win-arm64; launcher.c is already patched there.
setlocal EnableExtensions

set "ARCH_SUFFIX=arm64"
set "CL_MACHINE=ARM64"

cd /d "%BUILD_PREFIX%"

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
