@echo off
chcp 65001 >nul
title Zero - 启动中...

:: =============================================
:: Zero 一键启动脚本
:: 自动查找 Love2D 并运行项目
:: =============================================

set GAME_DIR=%~dp0
set LOVE_EXE=

:: 尝试常见安装路径
if exist "D:\WorkSpace_Love2d\Engine\LOVE\love.exe" (
    set LOVE_EXE=D:\WorkSpace_Love2d\Engine\LOVE\love.exe
    goto :found
)
if exist "C:\Program Files\LOVE\love.exe" (
    set LOVE_EXE=C:\Program Files\LOVE\love.exe
    goto :found
)
if exist "C:\Program Files (x86)\LOVE\love.exe" (
    set LOVE_EXE=C:\Program Files (x86)\LOVE\love.exe
    goto :found
)
if exist "D:\Program Files\LOVE\love.exe" (
    set LOVE_EXE=D:\Program Files\LOVE\love.exe
    goto :found
)
if exist "D:\LOVE\love.exe" (
    set LOVE_EXE=D:\LOVE\love.exe
    goto :found
)

:: 尝试 PATH 中查找
where love.exe >nul 2>&1
if %errorlevel% == 0 (
    set LOVE_EXE=love.exe
    goto :found
)

:: 找不到，提示用户手动配置
echo.
echo [错误] 找不到 love.exe！
echo.
echo 请编辑 run.bat，在下方手动填入你的 Love2D 安装路径：
echo   set LOVE_EXE=C:\你的路径\love.exe
echo.
echo 或者确保 Love2D 已加入系统 PATH 环境变量。
echo.
pause
exit /b 1

:found
echo.
echo  ██████╗ ███████╗██████╗  ██████╗
echo  ╚════╝  ██╔════╝██╔══██╗██╔═══██╗
echo   ░░░░   █████╗  ██████╔╝██║   ██║
echo   ░░░░   ██╔══╝  ██╔══██╗██║   ██║
echo  ██████╗ ███████╗██║  ██║╚██████╔╝
echo  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝
echo.
echo  Love2D: %LOVE_EXE%
echo  项目:   %GAME_DIR%
echo.

start "" "%LOVE_EXE%" "%GAME_DIR%"
exit /b 0
