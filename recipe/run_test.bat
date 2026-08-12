@echo on
if not exist "%PREFIX%\share\conda-launchers\cli-32.exe" exit /b 1
if not exist "%PREFIX%\share\conda-launchers\gui-32.exe" exit /b 1
if not exist "%PREFIX%\share\conda-launchers\cli-64.exe" exit /b 1
if not exist "%PREFIX%\share\conda-launchers\gui-64.exe" exit /b 1
if not exist "%PREFIX%\share\conda-launchers\cli-arm64.exe" exit /b 1
if not exist "%PREFIX%\share\conda-launchers\gui-arm64.exe" exit /b 1
