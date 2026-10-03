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

---

## 21. USB debugging is enabled but no authorization popup appears

### Symptom

You run:

```powershell
adb devices
```

and Android appears as:

```text
USB_SERIAL    unauthorized
```

but the phone does not show the `Allow USB debugging?` authorization dialog.

### Why this happens

Enabling **USB debugging** only enables the ADB interface. A new computer normally still needs to be authorized by the Android device.

ADB authorization is associated with the specific computer/ADB key, so another computer may need to be authorized separately.

### Try these steps

#### 1. Unlock the phone

Keep the phone unlocked while connecting the USB cable.

Disconnect and reconnect the cable, then run:

```powershell
adb kill-server
adb start-server
adb devices
```

#### 2. Check the USB connection mode

On Android, open the USB notification and, where available, choose a data mode such as:

```text
File Transfer
```

instead of charging-only mode.

Then reconnect the cable.

#### 3. Revoke previous USB debugging authorizations

On the phone, open:

```text
Settings
→ Developer options
→ Revoke USB debugging authorizations
```

Then:

1. Turn USB debugging OFF.
2. Turn USB debugging ON again.
3. Reconnect the USB cable.
4. Run:

```powershell
adb devices
```

The authorization dialog should normally appear for an untrusted computer.

#### 4. Try another USB cable or USB port

Try a known-good data cable and another USB port. Avoid USB hubs during initial setup when possible.

#### 5. Check the computer's ADB keys

On Windows:

```powershell
dir "$env:USERPROFILE\.android"
```

You may see:

```text
adbkey
adbkey.pub
```

`adbkey` is the private ADB key.

**Never publish or share `adbkey`.**

Do not delete the keys as a first troubleshooting step unless you understand that doing so can require re-authorizing devices.

### If the phone has a broken screen

If the Android screen is broken and the device has never authorized this computer, the authorization dialog may be impossible to confirm normally.

Depending on the phone and Android version, possible approaches include:

- using a working touchscreen
- connecting an OTG mouse
- using an external display/input method if supported
- using a computer that was already authorized
- using a suitable recovery/debugging environment

The exact solution is device-specific.

### Important

Do not assume that:

```text
USB debugging = ON
```

means:

```text
Every computer = authorized
```

These are separate states.

Expected progression:

```text
USB debugging enabled
        ↓
Computer connects
        ↓
unauthorized
        ↓
Android authorization dialog
        ↓
User accepts
        ↓
device
```

Expected final result:

```text
USB_SERIAL    device
```

Once the device reaches the `device` state, the launcher can use it.

---

## 22. `adb` commands entered inside the Android shell do not work

If your prompt looks like:

```text
kali:/ #
```

you are already inside the Android shell.

Commands such as:

```text
adb devices
adb shell
adb connect
```

are normally run from the PC, not from inside the Android shell.

From the PC:

```powershell
adb devices
adb shell
```

Inside Android, use Android/Linux commands directly, for example:

```sh
ip route
ip -4 addr
ss -lnt
settings get global http_proxy
```

For example, this is correct from the Android shell:

```sh
settings get global http_proxy
```

while this is normally incorrect from inside Android:

```sh
adb shell settings get global http_proxy
```

---

## 23. Checking for a local proxy such as `127.0.0.1:9050`

If an application reports an error similar to:

```text
127.0.0.1:9050
```

but Android's global proxy settings are empty, the proxy may be configured inside the application itself.

Check Android's global proxy settings:

```sh
settings get global http_proxy
settings get global global_http_proxy_host
settings get global global_http_proxy_port
settings list global | grep -i proxy
```

Check whether anything is listening on port 9050:

```sh
ss -lnt | grep 9050
```

If there is no output, nothing is currently listening on TCP port 9050.

For an F-Droid-based client, also check the application's own settings for proxy/Tor/SOCKS configuration.

Do not remove networking rules or proxy configuration blindly; first determine which component created the configuration.

---

## 24. F-Droid/NetHunter Store reports "No mirrors available"

If the application reports:

```text
Error getting F-Droid index file
No mirrors available
```

first verify that the phone itself has working network and DNS access.

From Android:

```sh
ping -c 3 8.8.8.8
ping -c 3 f-droid.org
```

Then, if available:

```sh
curl -I https://f-droid.org
```

or:

```sh
wget -S --spider https://f-droid.org
```

Interpretation:

- If IP connectivity and HTTPS both work, investigate the F-Droid/NetHunter Store repository configuration or client.
- If `8.8.8.8` works but the domain fails, investigate DNS.
- If both fail, investigate the Android network/VPN/firewall configuration.

Also check whether the application has its own proxy configuration.

---

## 25. ADB TCP/5555 is listening but Windows still cannot connect

On Android:

```sh
ss -lnt | grep 5555
```

A listener similar to:

```text
*:5555
```

or:

```text
[::]:5555
```

indicates that ADB is listening.

From Windows:

```powershell
Test-NetConnection PHONE_IP -Port 5555
```

If Android is listening but Windows reports:

```text
TcpTestSucceeded : False
```

the problem is likely between the two hosts, such as:

- different networks
- routing
- hotspot isolation
- firewall rules
- VPN/network-interface selection

The presence of a listener on Android does not by itself prove that Windows can reach it.
