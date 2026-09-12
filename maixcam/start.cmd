@echo off
rem ---------------------------------------------------------------
rem  MaixCAM Assistant - start the app.
rem
rem    maixcam\start.cmd          -> port 8890
rem    maixcam\start.cmd 9001     -> another port
rem
rem  This is a FORK of DeepSeek Harness, built from source. It runs
rem  with its OWN DSH_HOME (C:\Users\chuan\.dsh-maixcam), so its
rem  sessions, workspaces, settings and plugins are entirely separate
rem  from any other dsh install on this machine.
rem
rem  NOTE: this file is ASCII-only on purpose. cmd.exe parses a .cmd
rem  with the ANSI code page active at start, so UTF-8 Chinese text
rem  here would be misread as commands.
rem ---------------------------------------------------------------

setlocal
set "PORT=%~1"
if "%PORT%"=="" set "PORT=8890"
set "APPHOME=%~dp0.."
set "DSH_HOME=C:\Users\chuan\.dsh-maixcam"

pushd "%APPHOME%"
echo [maixcam] app root : %APPHOME%
echo [maixcam] dsh home : %DSH_HOME%
echo [maixcam] starting : node apps/cli/lib/bin.js --profile maixcam --port %PORT%
echo [maixcam] a browser window should open with the URL
echo.

node apps\cli\lib\bin.js --profile maixcam --patch maixcam\app.patch.yml --port %PORT%

echo.
echo [maixcam] stopped. Press any key to close.
pause >nul
popd
endlocal
