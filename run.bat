@echo off
chcp 65001 >nul
setlocal EnableExtensions

rem ===========================================================
rem  Star Game · 一键运行（双击本文件即可开始游戏）
rem
rem  附加参数会原样转发给 Godot，例如：
rem      run.bat --headless          无窗口运行（CI / 远程）
rem      run.bat --quit-after 120    跑 120 帧后自动退出
rem
rem  想换成别的动作，请用同目录的 editor.bat / test.bat。
rem  设 SG_NO_PAUSE=1 可跳过结束时的“按任意键”。
rem ===========================================================

rem —— 判断是否为双击启动：命令行里出现本脚本名即为双击 ——
set "PAUSE_END="
echo %cmdcmdline% | find /i "%~nx0" >nul 2>&1 && set "PAUSE_END=1"
if defined SG_NO_PAUSE set "PAUSE_END="

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\godot.ps1" -Action play %*
set "RC=%ERRORLEVEL%"

if not "%RC%"=="0" (
    echo.
    echo [!] 启动失败，退出码 %RC% ，请查看上方信息。
)

if defined PAUSE_END pause
endlocal & exit /b %RC%
