@echo on
REM Windows counterpart of build.sh (conda-build ignores build.sh on win).
setlocal EnableExtensions

set "target_dir=%PREFIX%\share\conda-launchers"
mkdir "%target_dir%"
if %ERRORLEVEL% neq 0 exit /b 1

for %%F in (cli-64.exe gui-64.exe cli-arm64.exe gui-arm64.exe) do (
  copy /Y "%SRC_DIR%\%%F" "%target_dir%\"
  if errorlevel 1 exit /b 1
)
endlocal
