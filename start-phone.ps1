# ============================================================
# Android Wireless scrcpy Launcher
# ============================================================
#
# Features:
#   - Detects authorized USB ADB device dynamically
#   - Handles unauthorized devices
#   - Removes stale TCP ADB connections
#   - Enables classic ADB TCP/IP on port 5555
#   - Dynamically discovers Android IPv4 addresses
#   - Tests reachability from Windows
#   - Automatically connects to a reachable IP
#   - Explicitly selects the wireless ADB device
#   - Falls back to USB if wireless fails
#
# No phone serial numbers or IP addresses are hard-coded.
#
# ============================================================

#Requires -Version 5.1

$ErrorActionPreference = "Continue"


# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

function Write-Info {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Yellow
}

function Write-ErrorMessage {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red
}

function Fail-Script {
    param([string]$Message)

    Write-Host ""
    Write-ErrorMessage "[ERROR] $Message"
    Write-Host ""

    exit 1
}


# ------------------------------------------------------------
# Banner
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       Android Wireless scrcpy" -ForegroundColor Cyan
Write-Host "       Dynamic Network Detection" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {

    Fail-Script `
        "adb.exe was not found in PATH. Install Android SDK Platform-Tools."
}

if (-not (Get-Command scrcpy -ErrorAction SilentlyContinue)) {

    Fail-Script `
        "scrcpy.exe was not found in PATH. Install scrcpy."
}


# ------------------------------------------------------------
# Detect authorized USB devices
# ------------------------------------------------------------

Write-Info "[1/7] Detecting Android ADB devices..."

$adbDevicesOutput = @(adb devices 2>$null)

$authorizedUsbDevices = @()
$unauthorizedUsbDevices = @()
$offlineUsbDevices = @()

foreach ($line in $adbDevicesOutput) {

    if ($line -match "^(\S+)\s+(\S+)$") {

        $serial = $Matches[1]
        $state  = $Matches[2]

        # TCP/IP devices contain ":"
        # Physical USB devices normally do not.
        $isTcpDevice = $serial -match ":"

        if (-not $isTcpDevice) {

            switch ($state) {

                "device" {
                    $authorizedUsbDevices += $serial
                }

                "unauthorized" {
                    $unauthorizedUsbDevices += $serial
                }

                "offline" {
                    $offlineUsbDevices += $serial
                }
            }
        }
    }
}


# ------------------------------------------------------------
# Handle unauthorized device
# ------------------------------------------------------------

if ($unauthorizedUsbDevices.Count -gt 0) {

    Write-Host ""

    Write-ErrorMessage "============================================"
    Write-ErrorMessage "          DEVICE NOT AUTHORIZED"
    Write-ErrorMessage "============================================"

    Write-Host ""

    foreach ($device in $unauthorizedUsbDevices) {

        Write-Host "Unauthorized device:" -ForegroundColor Yellow
        Write-Host "  $device"
    }

    Write-Host ""

    Write-Host "USB debugging is enabled, but this computer"
    Write-Host "has not been authorized by Android."
    Write-Host ""

    Write-Host "Unlock the phone and accept the Android dialog:"
    Write-Host ""

    Write-Host '    "Allow USB debugging?"' -ForegroundColor Yellow

    Write-Host ""

    Write-Host "After authorization, run the launcher again."
    Write-Host ""

    Write-Host "For a broken display, an OTG mouse or another"
    Write-Host "supported external-input/display method may be"
    Write-Host "required for the initial authorization."
    Write-Host ""

    exit 1
}


# ------------------------------------------------------------
# Handle no USB device
# ------------------------------------------------------------

if ($authorizedUsbDevices.Count -eq 0) {

    Fail-Script `
        "No authorized USB Android device was found. Connect and authorize the phone first."
}


# ------------------------------------------------------------
# Handle multiple USB devices
# ------------------------------------------------------------

if ($authorizedUsbDevices.Count -gt 1) {

    Write-Host ""

    Write-ErrorMessage "============================================"
    Write-ErrorMessage "       MULTIPLE USB DEVICES DETECTED"
    Write-ErrorMessage "============================================"

    Write-Host ""

    foreach ($device in $authorizedUsbDevices) {

        Write-Host "  $device"
    }

    Write-Host ""

    Write-Host "Disconnect the extra USB devices and retry."
    Write-Host ""

    exit 1
}


$usbDevice = $authorizedUsbDevices[0]

Write-Success "[OK] USB device: $usbDevice"


# ------------------------------------------------------------
# Remove stale TCP ADB devices
# ------------------------------------------------------------

Write-Host ""
Write-Info "[2/7] Cleaning stale wireless ADB connections..."

adb disconnect | Out-Null

Start-Sleep -Seconds 1


# ------------------------------------------------------------
# Enable ADB TCP/IP
# ------------------------------------------------------------

Write-Host ""
Write-Info "[3/7] Enabling ADB TCP/IP mode on port 5555..."

$tcpResult = @(adb -s $usbDevice tcpip 5555 2>&1)

if ($tcpResult.Count -gt 0) {

    foreach ($line in $tcpResult) {

        Write-Host $line
    }
}

Start-Sleep -Seconds 3


# ------------------------------------------------------------
# Discover Android IPv4 addresses
# ------------------------------------------------------------

Write-Host ""
Write-Info "[4/7] Detecting Android IPv4 addresses..."

$androidIpOutput = @(
    adb -s $usbDevice shell ip -4 addr 2>$null
)

if ($androidIpOutput.Count -eq 0) {

    Write-Host ""
    Write-WarningMessage "Android returned no IPv4 address information."

    Write-Host ""
    Write-Host "Trying routing table instead..."

    $routeOutput = @(
        adb -s $usbDevice shell ip route 2>$null
    )

    if ($routeOutput.Count -eq 0) {

        Fail-Script `
            "Could not obtain Android network information."
    }

    Write-Host ""
    Write-Host "Android route table:"
    $routeOutput | ForEach-Object {
        Write-Host $_
    }

    Fail-Script `
        "No usable IPv4 address could be determined."
}


# ------------------------------------------------------------
# Parse IPv4 addresses
# ------------------------------------------------------------

$phoneIPs = New-Object System.Collections.Generic.List[string]

foreach ($line in $androidIpOutput) {

    if ($line -match `
        "inet\s+(\d{1,3}(?:\.\d{1,3}){3})/\d+") {

        $ip = $Matches[1]

        # Exclude loopback
        if ($ip -like "127.*") {
            continue
        }

        # Exclude link-local
        if ($ip -like "169.254.*") {
            continue
        }

        # Exclude common Android emulator-only address
        if ($ip -like "10.0.2.*") {
            continue
        }

        # Avoid duplicates
        if (-not $phoneIPs.Contains($ip)) {

            [void]$phoneIPs.Add($ip)
        }
    }
}


# ------------------------------------------------------------
# No IPs found
# ------------------------------------------------------------

if ($phoneIPs.Count -eq 0) {

    Write-Host ""
    Write-Host "Android network output:"
    $androidIpOutput | ForEach-Object {
        Write-Host $_
    }

    Fail-Script `
        "No usable IPv4 address was found on the Android device."
}


# ------------------------------------------------------------
# Show candidate addresses
# ------------------------------------------------------------

Write-Host ""

Write-Host "Candidate Android IPv4 addresses:" `
    -ForegroundColor Cyan

foreach ($ip in $phoneIPs) {

    Write-Host "  $ip"
}


# ------------------------------------------------------------
# Test TCP port 5555
# ------------------------------------------------------------

Write-Host ""
Write-Info "[5/7] Testing TCP/5555 reachability..."

$workingIP = $null

foreach ($ip in $phoneIPs) {

    Write-Host ""
    Write-Host "Testing $ip`:5555 ..."

    try {

        $reachable = Test-NetConnection `
            -ComputerName $ip `
            -Port 5555 `
            -InformationLevel Quiet `
            -WarningAction SilentlyContinue

    }
    catch {

        $reachable = $false
    }

    if ($reachable) {

        Write-Success "[OK] TCP/5555 reachable on $ip"

        $workingIP = $ip

        break
    }

    Write-WarningMessage "[NO] TCP/5555 not reachable on $ip"
}


# ------------------------------------------------------------
# If Windows test fails, try adb connect anyway
# ------------------------------------------------------------

if (-not $workingIP) {

    Write-Host ""

    Write-WarningMessage `
        "No candidate passed the Windows TCP test."

    Write-Host ""
    Write-WarningMessage `
        "Trying adb connect directly against each candidate..."

    foreach ($ip in $phoneIPs) {

        $target = "${ip}:5555"

        Write-Host ""
        Write-Host "Trying $target ..."

        $connectOutput = @(
            adb connect $target 2>&1
        )

        foreach ($line in $connectOutput) {

            Write-Host $line
        }

        $connectText = $connectOutput -join " "

        if ($connectText -match `
            "connected to|already connected") {

            $workingIP = $ip

            break
        }
    }
}


# ------------------------------------------------------------
# Wireless failed
# ------------------------------------------------------------

if (-not $workingIP) {

    Write-Host ""

    Write-ErrorMessage "============================================"
    Write-ErrorMessage "       WIRELESS ADB CONNECTION FAILED"
    Write-ErrorMessage "============================================"

    Write-Host ""

    Write-Host "Possible causes:"
    Write-Host ""
    Write-Host "  1. Phone and PC are on different networks."
    Write-Host "  2. Windows Mobile Hotspot blocks peer traffic."
    Write-Host "  3. Android is not reachable on TCP/5555."
    Write-Host "  4. Windows Firewall is blocking the connection."
    Write-Host "  5. Android requires Wireless Debugging pairing."
    Write-Host "  6. The phone is connected through another interface."
    Write-Host "  7. The Wi-Fi network uses client isolation."
    Write-Host ""

    Write-WarningMessage `
        "Falling back to USB scrcpy..."

    Write-Host ""

    # Explicitly select the USB device.
    scrcpy `
        -s $usbDevice `
        --video-codec=h264

    exit 0
}


# ------------------------------------------------------------
# Build TCP serial
# ------------------------------------------------------------

$wifiDevice = "${workingIP}:5555"

Write-Host ""
Write-Info "[6/7] Connecting to $wifiDevice..."


# Clean stale connection first
adb disconnect | Out-Null

Start-Sleep -Seconds 1


# Connect
$connectionOutput = @(
    adb connect $wifiDevice 2>&1
)

foreach ($line in $connectionOutput) {

    Write-Host $line
}

Start-Sleep -Seconds 2


# ------------------------------------------------------------
# Verify the exact wireless device
# ------------------------------------------------------------

$finalDevices = @(adb devices 2>$null)

$wirelessVerified = $false

foreach ($line in $finalDevices) {

    if (
        $line -match `
        ("^" + [regex]::Escape($wifiDevice) + "\s+device$")
    ) {

        $wirelessVerified = $true

        break
    }
}


# ------------------------------------------------------------
# Wireless verification failed
# ------------------------------------------------------------

if (-not $wirelessVerified) {

    Write-Host ""

    Write-ErrorMessage `
        "[ERROR] Wireless ADB connection could not be verified."

    Write-Host ""

    Write-WarningMessage `
        "Falling back to USB scrcpy..."

    Write-Host ""

    scrcpy `
        -s $usbDevice `
        --video-codec=h264

    exit 0
}


# ------------------------------------------------------------
# Launch scrcpy over Wi-Fi
# ------------------------------------------------------------

Write-Host ""

Write-Success "[OK] Wireless ADB connected!"
Write-Success "     Device: $wifiDevice"

Write-Host ""

Write-Info "[7/7] Starting scrcpy over Wi-Fi..."

Write-Host ""

# Explicitly select the wireless transport.
# This prevents USB/TCP duplicate-device errors.
scrcpy `
    -s $wifiDevice `
    --video-codec=h264


# ------------------------------------------------------------
# End
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================"
Write-Host "scrcpy closed."
Write-Host "============================================"