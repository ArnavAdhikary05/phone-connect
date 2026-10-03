@echo off
setlocal EnableExtensions EnableDelayedExpansion

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
echo ============================================
echo.

set /p "choice=Select option: "

if "%choice%"=="1" goto usb
if "%choice%"=="2" goto wifi
if "%choice%"=="3" goto end

echo.
echo [ERROR] Invalid option.
timeout /t 2 >nul
goto menu


:usb
cls

echo ============================================
echo              USB scrcpy
echo ============================================
echo.

where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb.exe was not found.
    echo.
    echo Install Android SDK Platform-Tools and add
    echo its directory to the Windows PATH.
    echo.
    pause
    goto menu
)

where scrcpy >nul 2>&1
if errorlevel 1 (
    echo [ERROR] scrcpy.exe was not found.
    echo.
    echo Install scrcpy and add it to the Windows PATH.
    echo.
    pause
    goto menu
)

echo [1/3] Cleaning stale wireless ADB connections...
adb disconnect >nul 2>&1

echo.
echo [2/3] Checking connected Android devices...
echo.

adb devices

echo.
echo ============================================
echo Checking USB authorization...
echo ============================================
echo.

set "USB_DEVICE="
set "UNAUTHORIZED_DEVICE="
set /a USB_COUNT=0

for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (

    if "%%B"=="device" (
        if not "%%A"=="" (
            set /a USB_COUNT+=1
            set "CURRENT_DEVICE=%%A"

            echo [AUTHORIZED] %%A

            if !USB_COUNT! EQU 1 (
                set "USB_DEVICE=%%A"
            )
        )
    )

    if "%%B"=="unauthorized" (
        if not "%%A"=="" (
            set "UNAUTHORIZED_DEVICE=%%A"
            echo [UNAUTHORIZED] %%A
        )
    )

    if "%%B"=="offline" (
        if not "%%A"=="" (
            echo [OFFLINE] %%A
        )
    )
)

echo.

if defined UNAUTHORIZED_DEVICE (
    echo ============================================
    echo           DEVICE NOT AUTHORIZED
    echo ============================================
    echo.
    echo Device:
    echo   %UNAUTHORIZED_DEVICE%
    echo.
    echo USB debugging is enabled, but this computer
    echo has NOT been authorized by the Android device.
    echo.
    echo Unlock the phone and accept the Android dialog:
    echo.
    echo      "Allow USB debugging?"
    echo.
    echo You may also see:
    echo.
    echo      "Always allow from this computer"
    echo.
    echo After authorizing the computer, run this
    echo option again.
    echo.
    echo If the phone display is broken, use an OTG
    echo mouse/external display if supported.
    echo.
    pause
    goto menu
)

if !USB_COUNT! EQU 0 (
    echo ============================================
    echo         NO AUTHORIZED USB DEVICE
    echo ============================================
    echo.
    echo Connect an Android device through USB and
    echo make sure USB debugging is enabled and
    echo authorized for this computer.
    echo.
    pause
    goto menu
)

if !USB_COUNT! GTR 1 (
    echo ============================================
    echo       MULTIPLE USB DEVICES DETECTED
    echo ============================================
    echo.
    echo More than one authorized USB device is
    echo connected.
    echo.
    echo This launcher needs one USB device at a time
    echo for automatic selection.
    echo.
    echo Disconnect the additional devices and retry.
    echo.
    pause
    goto menu
)

echo [OK] Authorized USB device:
echo      %USB_DEVICE%
echo.

echo [3/3] Starting scrcpy over USB...
echo.

rem -s explicitly selects the detected USB device.
rem H.264 is used for broad compatibility.
scrcpy -s "%USB_DEVICE%" --video-codec=h264

echo.
echo ============================================
echo scrcpy closed.
echo ============================================
echo.

pause
goto menu


:wifi
cls

echo ============================================
echo           Wireless scrcpy
echo ============================================
echo.

where adb >nul 2>&1
if errorlevel 1 (
    echo [ERROR] adb.exe was not found.
    pause
    goto menu
)

where scrcpy >nul 2>&1
if errorlevel 1 (
    echo [ERROR] scrcpy.exe was not found.
    pause
    goto menu
)

echo Starting dynamic wireless connection...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-phone.ps1"

echo.
echo ============================================
echo Wireless mode finished.
echo ============================================
echo.

pause
goto menu


:end
endlocal
exit /b 0