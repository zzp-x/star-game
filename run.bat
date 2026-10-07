@echo off
rem ============================================================
rem  Star Game - run the game.  Double-click this file.
rem
rem  !!! KEEP THIS FILE PURE ASCII !!!
rem  cmd.exe tracks its read position in a .bat file in BYTES but
rem  decodes characters by CODE PAGE. Multi-byte characters make
rem  the two drift apart, so later lines get shredded and even
rem  "rem" lines get executed as commands. Every Chinese string
rem  lives in tools\godot.ps1 instead (UTF-8 with BOM, which
rem  PowerShell reads correctly).
rem
rem  Extra arguments are forwarded to Godot as-is:
rem      run.bat --headless
rem      run.bat --quit-after 120
rem
rem  Exit code is passed through unchanged.
rem ============================================================

chcp 65001 >nul
setlocal EnableExtensions

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" -Action play %*
set "RC=%ERRORLEVEL%"

rem Keep the window open on failure so the message can be read.
rem The game has its own window, so success needs no pause.
if not "%RC%"=="0" if not defined SG_NO_PAUSE pause

endlocal & exit /b %RC%
