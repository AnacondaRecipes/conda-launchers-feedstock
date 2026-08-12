@echo on
setlocal EnableExtensions

if "%target_platform%"=="win-64" (
  set "arch=64"
) else if "%target_platform%"=="win-arm64" (
  set "arch=arm64"
) else (
  echo Unknown target platform: %target_platform%
  exit /b 1
)

set "launcher_dir=%PREFIX%\share\conda-launchers"
set "scripts_dir=%PREFIX%\Scripts"

if not exist "%launcher_dir%\cli-%arch%.exe" exit /b 1
if not exist "%launcher_dir%\gui-%arch%.exe" exit /b 1

if not exist "%scripts_dir%" mkdir "%scripts_dir%"
copy /Y "%launcher_dir%\cli-%arch%.exe" "%scripts_dir%\"
if %ERRORLEVEL% neq 0 exit /b 1

cd /d "%scripts_dir%"

(
echo from pathlib import Path
echo print^("cli-%arch%.exe successfully launched the accompanying Python script"^)
echo Path^("cli-%arch%-output.txt"^).write_text^("cli-%arch%.exe successfully launched the accompanying Python script"^)
)> "cli-%arch%-script.py"
if %ERRORLEVEL% neq 0 exit /b 1

set PYLAUNCH_DEBUG=1
cli-%arch%.exe
if %ERRORLEVEL% neq 0 exit /b 1
if not exist "cli-%arch%-output.txt" exit /b 1
