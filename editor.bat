@echo off
rem ============================================================
rem  Star Game - open the Godot editor.  Double-click this file.
rem
rem  First launch tip: if Godot asks to enable a plugin, go to
rem  Project -> Project Settings -> Plugins and tick "Gut"
rem  (only needed for running tests, not for playing).
rem
rem  !!! KEEP THIS FILE PURE ASCII !!!
rem  See the note at the top of run.bat for why. Short version:
rem  cmd.exe mis-parses multi-byte characters inside .bat files.
rem  All Chinese text lives in tools\godot.ps1.
rem ============================================================

chcp 65001 >nul
setlocal EnableExtensions

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" -Action editor %*
set "RC=%ERRORLEVEL%"

rem The editor has its own window, so only pause when it failed.
if not "%RC%"=="0" if not defined SG_NO_PAUSE pause

endlocal & exit /b %RC%
