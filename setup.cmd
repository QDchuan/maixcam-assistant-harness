@echo off
rem ---------------------------------------------------------------
rem  MaixCAM ???? ?? ???????????
rem
rem  ???? maixcam\install.ps1????? -> ??? -> ?? ->
rem  ?????? home -> ?????????????
rem
rem  ??????????????????
rem
rem  NOTE: ASCII-only. cmd.exe parses a .cmd using the ANSI code page
rem  active at start, so UTF-8 Chinese here would be misread as commands.
rem ---------------------------------------------------------------

setlocal
set "SCRIPT=%~dp0maixcam\install.ps1"

if not exist "%SCRIPT%" (
  echo [ERROR] not found: %SCRIPT%
  pause
  exit /b 1
)

where pwsh >nul 2>nul
if %ERRORLEVEL%==0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT" %*
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT" %*
)
set "CODE=%ERRORLEVEL%"

echo.
if not "%CODE%"=="0" echo [FAILED] exit code %CODE%
pause
exit /b %CODE%
