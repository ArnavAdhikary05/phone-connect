# Troubleshooting

This guide covers the most common problems when using Android scrcpy Launcher.

---

## 1. `adb` is not recognized

### Error

```text
'adb' is not recognized as an internal or external command
```

### Cause

Android SDK Platform-Tools is either not installed or its directory is not in Windows `PATH`.

### Test

```powershell
adb version
```

### Fix

Install Android SDK Platform-Tools and add the directory containing `adb.exe` to `PATH`.

Open a new terminal after changing PATH.

---

## 2. `scrcpy` is not recognized

### Test

```powershell
scrcpy --version
```

If Windows cannot find it, install scrcpy and add its installation directory to PATH.

Open a new terminal afterward.

---

## 3. ADB shows `unauthorized`

Example:

```text
XXXXXXXX    unauthorized
```

Android has not authorized this computer.

Normally:

1. Unlock the phone.
2. Connect USB.
3. Accept the RSA/USB debugging authorization dialog.
4. Run:

```powershell
adb devices
```

again.

Expected:

```text
XXXXXXXX    device
```

### Broken screen

If the display is broken, authorization may require:

- a working touchscreen with an OTG mouse
- an external display solution, if supported
- an already-authorized computer
- a suitable recovery/debugging environment

The exact method is device-specific.

---

## 4. Multiple ADB devices

Example:

```text
USB_SERIAL              device
PHONE_IP:5555     device
```

Running plain:

```powershell
scrcpy
```

can produce:

```text
ERROR: Multiple ADB devices
```

Use:

```powershell
scrcpy -d
```

for USB.

Use:

```powershell
scrcpy -s PHONE_IP:5555
```

for Wi-Fi.

The launcher handles this automatically.

---

## 5. ADB device is `offline`

Example:

```text
PHONE_IP:5555     offline
```

Remove stale TCP connections:

```powershell
adb disconnect
```

Then reconnect:

```powershell
adb connect PHONE_IP:5555
```

If necessary:

```powershell
adb kill-server
adb start-server
```

Then reconnect the phone.

---

## 6. Error 10060

Example:

```text
cannot connect to 192.168.x.x:5555
...
(10060)
```

This generally means Windows could not establish the TCP connection.

Check:

```powershell
Test-NetConnection PHONE_IP -Port 5555
```

For example:

```powershell
Test-NetConnection PHONE_IP -Port 5555
```

Check the result:

```text
TcpTestSucceeded : True
```

If it is:

```text
False
```

common causes include:

- different networks
- Wi-Fi client isolation
- Windows firewall
- Android firewall
- ADB not listening on TCP/5555
- wrong IP address
- phone changed Wi-Fi networks

---

## 7. Error 10061

Example:

```text
No connection could be made because the target machine actively refused it.
```

This commonly means the IP is reachable but there is no service accepting connections on port 5555.

Check:

```powershell
adb shell getprop service.adb.tcp.port
```

Expected for classic TCP ADB:

```text
5555
```

Then:

```powershell
adb tcpip 5555
```

Wait a few seconds and retry.

---

## 8. Phone and PC are on different subnets

Example:

```text
PC:
PC_IP

Phone:
PHONE_IP
```

These addresses are on different private networks.

They may not be able to communicate directly.

Use the same LAN or a private hotspot where peer-to-peer communication is allowed.

Check the PC:

```powershell
ipconfig
```

Check Android:

```powershell
adb shell ip route
```

---

## 9. Using Windows Mobile Hotspot

A common setup is:

```text
Windows PC
   │
   └── Mobile Hotspot
          │
          └── Android
```

Connect the Android phone to the PC's hotspot before selecting Wi-Fi mode.

The exact hotspot subnet is controlled by Windows and can vary by configuration.

Do not hard-code an address such as:

```text
PHONE_IP
```

The launcher discovers the phone address dynamically.

If connectivity still fails, run:

```powershell
ipconfig
```

and:

```powershell
adb shell ip route
```

The PC and Android need a route that allows them to communicate.

---

## 10. Android Wireless Debugging

Modern Android versions may prefer or require the built-in:

```text
Developer options
    → Wireless debugging
```

workflow.

This can use a pairing port and an ADB connection port that are not necessarily TCP/5555.

The launcher in this repository uses the classic:

```powershell
adb tcpip 5555
```

workflow.

If your Android version does not allow that workflow, use Android Wireless Debugging manually.

Typical workflow:

1. Enable Developer options.
2. Enable Wireless debugging.
3. Choose Pair device with pairing code.
4. Use:

```powershell
adb pair IP:PAIRING_PORT
```

5. Enter the displayed pairing code.
6. Then connect using the displayed ADB connection address/port:

```powershell
adb connect IP:CONNECTION_PORT
```

The exact UI and ports vary by Android version.

---

## 11. USB works but Wi-Fi does not

This is a very useful diagnostic distinction.

If:

```powershell
scrcpy -d
```

works but wireless mode does not, then:

- Android ADB is working
- USB is working
- scrcpy is working

The problem is likely networking or TCP ADB.

Check:

```powershell
adb tcpip 5555
```

then:

```powershell
adb shell ip -4 addr
```

and:

```powershell
Test-NetConnection PHONE_IP -Port 5555
```

---

## 12. Wi-Fi works but USB scrcpy fails

If ADB shows:

```text
USB_SERIAL    device
```

but scrcpy fails with a MediaCodec error, the issue may be Android's video encoder rather than ADB.

Try:

```powershell
scrcpy -d --video-codec=h264
```

The launcher already uses H.264.

You can also consult scrcpy's current documentation for codec-specific options.

---

## 13. MediaCodec error

Example:

```text
android.media.MediaCodec$CodecException
```

This is an Android media encoder issue.

Possible causes include:

- OEM-specific encoder bugs
- unsupported encoder configuration
- Android media framework problems
- high resolution/bitrate constraints
- a device-specific codec issue

Start with:

```powershell
scrcpy -d --video-codec=h264
```

If that fails, try other scrcpy-supported codec/configuration options.

---

## 14. Phone's physical screen is broken

scrcpy can still work if Android is running and ADB is authorized.

However, if USB debugging was never enabled/authorized before the display broke, the initial authorization can be the difficult part.

If the phone is rooted, do not modify system authentication files blindly. Android security behavior varies by version.

---

## 15. Find Android's IP manually

Run:

```powershell
adb shell ip -4 addr
```

or:

```powershell
adb shell ip route
```

Example:

```text
PHONE_SUBNET/24 dev wlan0 ... src PHONE_IP
```

The `src` address is often the phone's LAN address.

---

## 16. Check TCP/5555 manually

From Windows:

```powershell
Test-NetConnection PHONE_IP -Port 5555
```

Successful:

```text
TcpTestSucceeded : True
```

Failed:

```text
TcpTestSucceeded : False
```

---

## 17. Windows Firewall

If TCP/5555 is blocked by Windows Firewall, verify your network profile and firewall rules.

Do not disable the firewall globally just to make ADB work.

Prefer a narrowly scoped rule if one is actually required, and only on a trusted private network.

---

## 18. Security warning

ADB is a powerful debugging interface.

Do not expose TCP/5555 to:

- the public Internet
- untrusted Wi-Fi
- shared/public networks

Prefer:

```text
Private LAN
```

or:

```text
Private PC hotspot
```

When finished with classic TCP ADB, you can return the daemon to USB mode:

```powershell
adb usb
```

For newer Android versions, Wireless Debugging is generally preferable to exposing classic TCP ADB on an untrusted network.

---

## 19. Useful reset procedure

If ADB becomes confused:

```powershell
adb disconnect
adb kill-server
adb start-server
adb devices
```

Reconnect the USB cable and authorize the phone if necessary.

Then:

```powershell
adb tcpip 5555
```

followed by:

```powershell
adb connect PHONE_IP:5555
```

---

## 20. Report a bug

When reporting an issue, include:

```text
Windows version:
Android version:
Phone model:
ADB version:
scrcpy version:
USB works?:
Wi-Fi works?:
Output of adb devices:
Output of adb shell ip route:
Output of Test-NetConnection PHONE_IP -Port 5555:
```

Do not post:

- ADB private keys
- passwords
- Wi-Fi passwords
- personal IP information if it is not necessary
- device identifiers if you do not want them public
