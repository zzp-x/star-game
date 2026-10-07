@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ===========================================================
rem  Star Game · 打开 Godot 编辑器（双击本文件）
rem  首次打开若提示启用插件，去
rem  Project → Project Settings → Plugins 勾选 Gut（跑测试才需要）
rem ===========================================================

set "PAUSE_END="
echo %cmdcmdline% | find /i "%~nx0" >nul 2>&1 && set "PAUSE_END=1"
if defined SG_NO_PAUSE set "PAUSE_END="

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" -Action editor %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [!] 编辑器异常退出，退出码 %RC% ，请查看上方信息。
)

if defined PAUSE_END pause
endlocal & exit /b %RC%
