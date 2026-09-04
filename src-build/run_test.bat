@echo on
REM Standalone smoke-test for a built launcher exe (x64 exes on an x64 host).
REM The launcher resolves python.exe relative to its own location (..\python.exe),
REM so the exe is copied into <prefix>\Scripts for the test.
REM
REM Usage:  run_test.bat <path-to-cli-exe> [python-prefix]
REM         default prefix: C:\miniconda3
setlocal EnableExtensions

set "EXE=%~1"
if "%EXE%"=="" (
  echo Usage: run_test.bat ^<path-to-cli-exe^> [python-prefix]
  exit /b 1
)
set "PREFIX=%~2"
if "%PREFIX%"=="" set "PREFIX=C:\miniconda3"

for %%F in ("%EXE%") do set "EXE_NAME=%%~nxF"
set "SCRIPTS_DIR=%PREFIX%\Scripts"

if not exist "%PREFIX%\python.exe" (
  echo No python.exe at %PREFIX%
  exit /b 1
)
if not exist "%SCRIPTS_DIR%" mkdir "%SCRIPTS_DIR%"
copy /Y "%EXE%" "%SCRIPTS_DIR%\"
if %ERRORLEVEL% neq 0 exit /b 1

cd /d "%SCRIPTS_DIR%"
set "BASE=%EXE_NAME:.exe=%"

(
echo from pathlib import Path
echo print^("%EXE_NAME% successfully launched the accompanying Python script"^)
echo Path^("%BASE%-output.txt"^).write_text^("ok"^)
)> "%BASE%-script.py"
if %ERRORLEVEL% neq 0 exit /b 1

set PYLAUNCH_DEBUG=1
"%EXE_NAME%"
if %ERRORLEVEL% neq 0 exit /b 1
if not exist "%BASE%-output.txt" exit /b 1
type "%BASE%-output.txt"
endlocal
