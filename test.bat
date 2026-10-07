@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ===========================================================
rem  Star Game · 跑全部单元测试 + 集成测试（双击本文件）
rem
rem  不需要打开编辑器、不需要素材、不需要开窗口。
rem  设 SG_NO_PAUSE=1 可跳过结束时的“按任意键”（供 CI 调用）。
rem ===========================================================

set "PAUSE_END="
echo %cmdcmdline% | find /i "%~nx0" >nul 2>&1 && set "PAUSE_END=1"
if defined SG_NO_PAUSE set "PAUSE_END="

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" -Action test %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [!] 有测试未通过，退出码 %RC%
)

if defined PAUSE_END pause
endlocal & exit /b %RC%
