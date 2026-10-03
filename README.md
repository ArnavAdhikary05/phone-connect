# Android scrcpy Launcher

A small Windows launcher for **scrcpy + ADB** that provides a simple menu for:

- USB Android screen mirroring
- Wireless Android screen mirroring
- Dynamic Android IP detection
- Automatic ADB TCP/IP setup
- Automatic selection of the correct ADB device
- Stale/offline ADB connection cleanup
- USB fallback when wireless ADB cannot be established
- A simple workflow suitable for a headless Android phone/server

> **Important:** This project is designed to be general-purpose, but it is not guaranteed to work on every Android device, Android version, Windows network configuration, or OEM implementation. Wireless ADB behavior varies between Android versions and manufacturers.

---

## Project structure

```text
android-scrcpy-launcher/
│
├── start-phone.bat
├── start-phone.ps1
├── README.md
├── LICENSE
└── docs/
    └── troubleshooting.md
```

---

# 1. What does this project do?

The launcher gives you a simple menu:

```text
============================================
         Android scrcpy Launcher
============================================

 [1] USB
 [2] Wi-Fi
 [3] Exit
```

### USB mode

The launcher explicitly selects the USB device:

```text
PC
 │
 │ USB
 ▼
Android
 │
 ▼
ADB
 │
 ▼
scrcpy
```

This avoids the common error where ADB sees both a USB device and an old/offline TCP device:

```text
USB_SERIAL              device
PHONE_IP:5555     offline
```

The script uses:

```powershell
scrcpy -d
```

where `-d` means **select the USB device**.

### Wi-Fi mode

The launcher:

1. Finds an authorized USB ADB device.
2. Enables ADB TCP/IP mode on port `5555`.
3. Reads the Android device's IPv4 addresses dynamically.
4. Tests which address is reachable from Windows.
5. Connects to the reachable address.
6. Explicitly launches scrcpy against that TCP device.

Example:

```text
USB
 │
 ▼
adb tcpip 5555
 │
 ▼
Discover Android IP
 │
 ├── PHONE_IP
 ├── PHONE_IP
 └── another address
 │
 ▼
Test TCP/5555
 │
 ▼
adb connect <working-ip>:5555
 │
 ▼
scrcpy -s <working-ip>:5555
```

No phone IP or ADB serial number is hard-coded.

---

# 2. Requirements

## Windows

This project currently targets **Windows** because the launcher is written using:

- Batch
- PowerShell
- Windows networking commands

The underlying `adb` and `scrcpy` tools themselves support other platforms, but this repository's launcher is Windows-specific.

## Android

The phone must support ADB.

For USB setup you normally need:

- Developer options enabled
- USB debugging enabled
- This computer authorized for ADB

The first time you connect a computer to an Android phone, Android may display:

```text
Allow USB debugging?
```

You must authorize the computer.

If the phone's display is broken, this authorization step can be difficult. See the troubleshooting guide.

## ADB

Install **Android SDK Platform-Tools**, which provides:

```text
adb.exe
```

After installation, verify:

```powershell
adb version
```

and:

```powershell
adb devices
```

## scrcpy

Install scrcpy using the official project distribution.

Verify:

```powershell
scrcpy --version
```

The launcher expects both:

```text
adb.exe
scrcpy.exe
```

to be available through your Windows `PATH`.

---

# 3. Recommended installation

A convenient Windows setup is to install ADB Platform-Tools and scrcpy, then add their directories to `PATH`.

After that, open a new PowerShell window and test:

```powershell
adb version
```

```powershell
scrcpy --version
```

Then:

```powershell
adb devices
```

If your phone is connected and authorized, you should see:

```text
List of devices attached
XXXXXXXX    device
```

---

# 4. Download the project

Clone the repository:

```powershell
git clone https://github.com/YOUR_USERNAME/android-scrcpy-launcher.git
```

Enter the directory:

```powershell
cd android-scrcpy-launcher
```

Or download the repository as a ZIP and extract it.

---

# 5. USB setup

Connect the Android phone using USB.

Run:

```powershell
adb devices
```

You want:

```text
XXXXXXXX    device
```

### If you see `unauthorized`

You need to authorize the computer on the phone.

The normal process is:

1. Unlock the phone.
2. Connect USB.
3. Accept the ADB authorization dialog.
4. Run:

```powershell
adb devices
```

again.

You should now see:

```text
XXXXXXXX    device
```

### Start the launcher

Double-click:

```text
start-phone.bat
```

Choose:

```text
[1] USB
```

The launcher runs:

```powershell
adb disconnect
```

to remove stale TCP ADB entries and then:

```powershell
scrcpy -d --video-codec=h264
```

The `-d` option tells scrcpy to select the USB-connected device.

---

# 6. Wireless setup

There are two important concepts:

### USB ADB

```text
Phone <--USB--> PC
```

### TCP ADB

```text
Phone <--network--> PC
```

For the classic TCP ADB workflow used by this launcher, the phone must first be reachable over the network.

## Recommended network arrangement

For a simple private lab, you can use the Windows Mobile Hotspot:

```text
              Windows PC
          ┌───────────────┐
          │ Mobile Hotspot│
          └───────┬───────┘
                  │
                Wi-Fi
                  │
             ┌────▼────┐
             │ Android │
             └─────────┘
```

Connect the Android phone to the PC's hotspot.

The actual IP address does **not** matter.

It might be:

```text
PHONE_IP
```

or:

```text
PHONE_IP
```

or another address.

The PowerShell script discovers the address dynamically.

---

# 7. First wireless connection

For the classic `adb tcpip 5555` workflow, keep USB connected for the initial setup.

Run:

```powershell
adb devices
```

Make sure the phone is authorized.

Then launch:

```text
start-phone.bat
```

Select:

```text
[2] Wi-Fi
```

The PowerShell script performs approximately:

```powershell
adb tcpip 5555
```

Then it discovers Android IPv4 addresses.

It tests candidate addresses using Windows:

```powershell
Test-NetConnection <IP> -Port 5555
```

When it finds a reachable address:

```powershell
adb connect <IP>:5555
```

Then it verifies the device:

```powershell
adb devices
```

Finally:

```powershell
scrcpy -s <IP>:5555
```

---

# 8. Disconnect USB

After wireless ADB is successfully connected, you can test whether it works without USB.

First close scrcpy.

Unplug USB.

Run:

```powershell
adb devices
```

You should see something similar to:

```text
List of devices attached
PHONE_IP:5555    device
```

Then:

```powershell
scrcpy -s PHONE_IP:5555
```

If that works, the phone is being mirrored entirely over Wi-Fi.

---

# 9. Important: wireless ADB is not necessarily persistent

The classic command:

```powershell
adb tcpip 5555
```

usually changes the ADB daemon's behavior temporarily.

After a reboot or some Android configuration changes, you may need to enable TCP ADB again.

Therefore, this project does **not** promise:

```text
reboot phone
      ↓
wireless ADB always available
```

For modern Android devices, Android's **Wireless Debugging** feature may be the better approach.

See the troubleshooting guide for details.

---

# 10. Why does the script dynamically detect IP addresses?

A phone can receive a different DHCP address every time it connects to a network.

For example:

```text
Today:
PHONE_IP

Tomorrow:
192.168.137.51
```

Hard-coding:

```powershell
adb connect PHONE_IP:5555
```

would therefore be unreliable.

Instead, the script queries Android:

```powershell
adb shell ip -4 addr
```

and obtains candidate addresses.

It then tests them from Windows.

This makes the launcher much more portable across different networks.

---

# 11. Does it work on every phone?

Not guaranteed.

The project is intentionally designed to avoid phone-specific configuration, but Android manufacturers and versions can implement ADB and networking differently.

It is intended to work with ordinary Android devices where:

- ADB is available
- USB debugging is enabled
- the PC is authorized
- classic TCP ADB is permitted

Root access is **not required** for ordinary scrcpy usage.

A rooted phone may provide additional administration options, but the launcher itself does not require root.

---

# 12. Broken screen / headless Android

A broken physical display does not automatically prevent scrcpy.

If:

- Android boots normally
- ADB was previously enabled
- the computer is authorized
- the Android framebuffer/video encoder is functioning

scrcpy can often display the Android screen on the PC.

The difficult part is usually the initial ADB authorization.

If Android shows:

```text
Allow USB debugging?
```

and you cannot interact with the screen, you need another way to authorize the computer.

Possible approaches depend heavily on the phone model, Android version, recovery environment, and whether the device was previously authorized.

Do not blindly modify Android's ADB authorization files unless you understand the consequences.

---

# 13. Security considerations

ADB is a powerful Android debugging interface.

Do not expose ADB TCP/5555 to the public Internet.

Avoid using:

```text
Internet
   ↓
ADB :5555
```

Prefer:

```text
Private LAN
   ↓
Android
```

or:

```text
PC private hotspot
   ↓
Android
```

Also avoid using wireless ADB on an untrusted public Wi-Fi network.

If you enable classic TCP ADB temporarily, switch back to USB mode when you no longer need wireless ADB:

```powershell
adb usb
```

For modern Android devices, prefer the built-in **Wireless Debugging** pairing mechanism where available.

---

# 14. USB and Wi-Fi device selection

You may see:

```text
List of devices attached
USB_SERIAL              device
PHONE_IP:5555     device
```

These are two ADB transports for the same phone.

USB:

```powershell
scrcpy -d
```

Wireless:

```powershell
scrcpy -s PHONE_IP:5555
```

The launcher explicitly selects the correct transport so scrcpy does not fail with:

```text
ERROR: Multiple (2) ADB devices
```

---

# 15. Video encoder errors

scrcpy relies on Android's media/video encoding pipeline.

Some devices can produce errors such as:

```text
android.media.MediaCodec$CodecException
```

The launcher explicitly requests H.264:

```powershell
--video-codec=h264
```

This is intended as a compatibility-oriented choice.

If a particular phone's H.264 encoder has problems, additional scrcpy options may be necessary.

See:

```text
docs/troubleshooting.md
```

---

# 16. Troubleshooting

The troubleshooting guide covers:

- `adb` not found
- `scrcpy` not found
- `unauthorized`
- multiple ADB devices
- `offline`
- TCP/5555 connection failures
- `10060`
- `10061`
- different IP subnets
- Windows Mobile Hotspot
- Android Wireless Debugging
- MediaCodec errors
- broken displays
- USB fallback

Open:

```text
docs/troubleshooting.md
```

---

# 17. Useful commands

### List devices

```powershell
adb devices
```

### Restart ADB

```powershell
adb kill-server
adb start-server
```

### Enable TCP ADB

```powershell
adb tcpip 5555
```

### Connect wirelessly

```powershell
adb connect PHONE_IP:5555
```

### Disconnect wireless device

```powershell
adb disconnect PHONE_IP:5555
```

### Return ADB to USB mode

```powershell
adb usb
```

### Check Android IP

```powershell
adb shell ip -4 addr
```

### Check routing

```powershell
adb shell ip route
```

### USB scrcpy

```powershell
scrcpy -d
```

### Specific wireless device

```powershell
scrcpy -s PHONE_IP:5555
```

---

# 18. Open-source contribution

Contributions are welcome.

Possible improvements include:

- Android Wireless Debugging pairing support
- Linux launcher
- macOS launcher
- automatic Windows Mobile Hotspot management
- better network-interface matching
- automatic phone discovery
- GUI
- automatic retry logic
- configurable ADB port
- codec fallback logic
- logging
- device selection when multiple phones are connected

If you improve the project, please document platform-specific behavior and avoid hard-coding a particular phone model or IP address.

---

# 19. License

This project is released under the MIT License.

See:

```text
LICENSE
```

---

# 20. Credits

This launcher uses:

- **scrcpy** by Genymobile
- **Android Debug Bridge (ADB)** from Android SDK Platform-Tools

This repository is a launcher/automation project and is not a replacement for either project.

For the latest scrcpy documentation and releases, consult the official scrcpy project.

For ADB documentation, consult the official Android developer documentation.
