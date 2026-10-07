@echo off
rem ============================================================
rem  Star Game - run all unit + integration tests.
rem  Double-click this file.
rem
rem  No editor, no asset, no window needed.
rem
rem  !!! KEEP THIS FILE PURE ASCII !!!
rem  See the note at the top of run.bat for why. Short version:
rem  cmd.exe mis-parses multi-byte characters inside .bat files.
rem  All Chinese text lives in tools\godot.ps1.
rem
rem  Set SG_NO_PAUSE=1 to skip the closing "press any key"
rem  (this is what CI should use).
rem ============================================================

chcp 65001 >nul
setlocal EnableExtensions

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" -Action test %*
set "RC=%ERRORLEVEL%"

rem The test report IS the output, so always pause by default.
if not defined SG_NO_PAUSE pause

endlocal & exit /b %RC%
