@echo on
set "target_dir=%PREFIX%\share\conda-launchers"
mkdir "%target_dir%"
if %ERRORLEVEL% neq 0 exit /b 1
copy /Y cli-32-*.exe "%target_dir%\cli-32.exe"
if %ERRORLEVEL% neq 0 exit /b 1
copy /Y gui-32-*.exe "%target_dir%\gui-32.exe"
if %ERRORLEVEL% neq 0 exit /b 1
copy /Y cli-64-*.exe "%target_dir%\cli-64.exe"
if %ERRORLEVEL% neq 0 exit /b 1
copy /Y gui-64-*.exe "%target_dir%\gui-64.exe"
if %ERRORLEVEL% neq 0 exit /b 1
copy /Y cli-arm64-*.exe "%target_dir%\cli-arm64.exe"
if %ERRORLEVEL% neq 0 exit /b 1
copy /Y gui-arm64-*.exe "%target_dir%\gui-arm64.exe"
if %ERRORLEVEL% neq 0 exit /b 1