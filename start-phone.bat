@echo off
title Android scrcpy Launcher
color 0A

:menu

cls

echo ============================================
echo          Android scrcpy Launcher
echo ============================================
echo.
echo  [1] USB
echo  [2] Wi-Fi
echo  [3] Exit
echo.

set /p choice="Select option: "

if "%choice%"=="1" goto usb
if "%choice%"=="2" goto wifi
if "%choice%"=="3" exit

echo.
echo Invalid option.
timeout /t 2 >nul
goto menu


:usb

cls

echo ============================================
echo              USB scrcpy
echo ============================================
echo.

echo Cleaning old ADB connections...
adb disconnect >nul 2>&1

echo.
echo Checking USB device...
adb devices

echo.
echo Starting scrcpy using USB...
echo.

scrcpy -d --video-codec=h264

echo.
echo scrcpy closed.
pause
goto menu


:wifi

cls

echo ============================================
echo           Wireless scrcpy
echo ============================================
echo.

echo Starting dynamic wireless connection...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-phone.ps1"

echo.
echo Wireless mode finished.
pause
goto menu