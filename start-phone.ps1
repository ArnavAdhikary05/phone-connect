# ============================================================
# Android Wireless scrcpy - Dynamic Network Version
# ============================================================

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       Android Wireless scrcpy" -ForegroundColor Cyan
Write-Host "       Dynamic Network Detection" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Check required programs
# ------------------------------------------------------------

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] adb.exe not found." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command scrcpy -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] scrcpy.exe not found." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# Find USB Android device
# ------------------------------------------------------------

Write-Host "[1/7] Detecting Android device..." -ForegroundColor Yellow

$devices = adb devices

$usbDevice = $null

foreach ($line in $devices) {

    if ($line -match "^(\S+)\s+device$") {

        $serial = $Matches[1]

        # Ignore TCP/IP devices
        if ($serial -notmatch ":") {
            $usbDevice = $serial
            break
        }
    }
}

if (-not $usbDevice) {
    Write-Host ""
    Write-Host "[ERROR] No authorized USB Android device found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Connect the phone through USB and make sure ADB is authorized."
    exit 1
}

Write-Host "[OK] USB device: $usbDevice" -ForegroundColor Green

# ------------------------------------------------------------
# Clean stale ADB TCP connections
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2/7] Cleaning old wireless ADB connections..." -ForegroundColor Yellow

adb disconnect | Out-Null

Start-Sleep -Seconds 1

# ------------------------------------------------------------
# Enable TCP/IP ADB
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3/7] Enabling ADB TCP/IP mode..." -ForegroundColor Yellow

$tcpResult = adb -s $usbDevice tcpip 5555

Write-Host $tcpResult

Start-Sleep -Seconds 3

# ------------------------------------------------------------
# Get Android network interfaces
# ------------------------------------------------------------

Write-Host ""
Write-Host "[4/7] Detecting phone network addresses..." -ForegroundColor Yellow

$routeOutput = adb -s $usbDevice shell ip route

Write-Host ""
Write-Host "Android routing table:"
Write-Host $routeOutput

# Get all IPv4 addresses from Android
$ipOutput = adb -s $usbDevice shell ip -4 addr

$phoneIPs = @()

foreach ($line in $ipOutput) {

    if ($line -match "inet\s+(\d+\.\d+\.\d+\.\d+)/\d+") {

        $ip = $Matches[1]

        # Ignore loopback
        if ($ip -notlike "127.*") {

            # Ignore obvious cellular/virtual addresses
            if (
                $ip -notlike "169.254.*" -and
                $ip -notlike "10.0.2.*"
            ) {
                $phoneIPs += $ip
            }
        }
    }
}

if ($phoneIPs.Count -eq 0) {

    Write-Host ""
    Write-Host "[ERROR] Could not find a usable IPv4 address." -ForegroundColor Red

    Write-Host ""
    Write-Host "Android addresses:"
    Write-Host $ipOutput

    exit 1
}

Write-Host ""
Write-Host "Candidate phone IPs:" -ForegroundColor Cyan

foreach ($ip in $phoneIPs) {
    Write-Host "  $ip"
}

# ------------------------------------------------------------
# Find the IP reachable from Windows
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5/7] Testing network connectivity..." -ForegroundColor Yellow

$workingIP = $null

foreach ($ip in $phoneIPs) {

    Write-Host ""
    Write-Host "Testing $ip : 5555 ..."

    $test = Test-NetConnection `
        -ComputerName $ip `
        -Port 5555 `
        -InformationLevel Quiet `
        -WarningAction SilentlyContinue

    if ($test) {

        Write-Host "[OK] Port 5555 reachable on $ip" -ForegroundColor Green

        $workingIP = $ip
        break
    }
    else {

        Write-Host "[NO] $ip is not reachable on port 5555" -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------
# If port isn't reachable, try ADB connection anyway
# ------------------------------------------------------------

if (-not $workingIP) {

    Write-Host ""
    Write-Host "No reachable TCP/5555 address detected." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Attempting ADB connection to each candidate..." -ForegroundColor Yellow

    foreach ($ip in $phoneIPs) {

        $target = "${ip}:5555"

        Write-Host ""
        Write-Host "Trying $target ..."

        $result = adb connect $target

        Write-Host $result

        if ($result -match "connected to") {

            $workingIP = $ip
            break
        }
    }
}

# ------------------------------------------------------------
# Wireless connection failed
# ------------------------------------------------------------

if (-not $workingIP) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " Wireless ADB connection failed" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red

    Write-Host ""
    Write-Host "Possible causes:"
    Write-Host ""
    Write-Host "1. Phone and PC are on different networks."
    Write-Host "2. Windows hotspot/client isolation is blocking traffic."
    Write-Host "3. Android is not listening on TCP port 5555."
    Write-Host "4. Firewall is blocking TCP/5555."
    Write-Host "5. The phone changed Wi-Fi networks."
    Write-Host ""

    Write-Host "Falling back to USB scrcpy..." -ForegroundColor Yellow

    # USB encoder workaround
    scrcpy -d --video-codec=h264

    exit 0
}

# ------------------------------------------------------------
# Connect to working address
# ------------------------------------------------------------

$wifiDevice = "${workingIP}:5555"

Write-Host ""
Write-Host "[6/7] Connecting to $wifiDevice..." -ForegroundColor Yellow

adb disconnect | Out-Null

Start-Sleep -Seconds 1

$connection = adb connect $wifiDevice

Write-Host $connection

Start-Sleep -Seconds 2

# Verify
$adbList = adb devices

if ($adbList -match [regex]::Escape($wifiDevice) + "\s+device") {

    Write-Host ""
    Write-Host "[OK] Wireless ADB connected!" -ForegroundColor Green
    Write-Host "Device: $wifiDevice" -ForegroundColor Green

}
else {

    Write-Host ""
    Write-Host "[ERROR] Wireless ADB connection could not be verified." -ForegroundColor Red

    Write-Host ""
    Write-Host "Falling back to USB..."

    scrcpy -d --video-codec=h264

    exit 0
}

# ------------------------------------------------------------
# Launch scrcpy
# ------------------------------------------------------------

Write-Host ""
Write-Host "[7/7] Starting scrcpy over Wi-Fi..." -ForegroundColor Yellow
Write-Host ""

scrcpy -s $wifiDevice --video-codec=h264

Write-Host ""
Write-Host "scrcpy closed."