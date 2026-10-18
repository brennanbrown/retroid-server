```ascii
         _L2_  _L1_         [USB-C]         _R1_  _R2_
       .'    ''    '._____________________.'    ''    '.
      /                                                 \
     |      _       .---------------------.      (Y)     |
     |    _| |_     |   retroid-server    |   (X)   (B)  |
     |   |_   _|    |   .:*~*:._.:*~*:.   |      (A)     |
     |     |_|      |    :8022  ssh       |              |
     |              |    :8080  http      |              |
     |    (___)     |   .:*~*:._.:*~*:.   |     (___)    |
     |    SEL/ST    '---------------------'     HOME     |
      \                                                 /
       '.___[3.5mm]________[microSD]__________________.'bkb
```

# retroid-server

A Retroid Pocket 2S running as a LAN web server. Termux + Caddy serving
static files on port 8080, SSH on 8022, auto-start on boot via Termux:Boot.

Turn any spare Android device (an old phone, tablet, or retro handheld) into
an always-on LAN web server. **No root needed.**

- **Termux** provides a Linux userland on Android
- **Caddy** serves static files on port `8080`
- **OpenSSH** (`sshd`) gives key-only shell access on port `8022`
- **Termux:Boot** brings both back after a reboot

The `device/` folder mirrors `$HOME` inside Termux. Edit files locally, then
push them with `scripts/deploy.sh`.

This was built and tested on a Retroid Pocket 2S (see
[Reference setup](#retroid)).

## Requirements

| What | Notes |
|---|---|
| Android device | Android 7+ (required by current Termux builds), ARM or x86 |
| Computer | macOS, Linux, or Windows (WSL) with `ssh`, `curl`, and `adb` |
| Network | Device and computer on the same LAN (or just a USB cable, see below) |
| USB cable | Must carry data, not just charge (needed for `adb`) |

## Ports and access

| Service | Port | Auth |
|---|---|---|
| `sshd` | 8022 | public key only |
| Caddy (HTTP) | 8080 | none (LAN only) |

These are the Termux defaults. Without root, Android apps can't bind ports
below 1024, so `:22` and `:80` are not options.

Replace `<device-ip>` below with your device's LAN address.

```sh
# Over Wi-Fi / LAN
ssh -p 8022 <device-ip>
curl http://<device-ip>:8080/

# Over USB only (no network needed)
adb forward tcp:8022 tcp:8022
adb forward tcp:8080 tcp:8080
ssh -p 8022 localhost
curl http://localhost:8080/
```

Termux runs as a single Android user and ignores the SSH username, so any
username (or none) works.

## Files

```
device/                          mirrors $HOME in Termux
  Caddyfile                      -> ~/Caddyfile
  www/index.html                 -> ~/www/index.html   (docroot)
  .termux/boot/start-server.sh   -> ~/.termux/boot/start-server.sh
scripts/
  deploy.sh                      push device/ -> device $HOME, chmod boot scripts
  status.sh                      ssh + http health check
apks/                            downloaded APKs (gitignored)
```

On-device logs are written to `~/boot.log` (boot-script timestamps) and
`~/caddy.log`.

## Setup

### 1. Install `adb` on your computer

```sh
brew install --cask android-platform-tools   # macOS
sudo apt install adb                         # Debian / Ubuntu
```

On Windows, use Google's
[SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools).

### 2. Enable USB debugging

On the device: **Settings → About phone → tap Build number 7 times**, then
**Developer options → USB debugging**. Plug in, accept the RSA fingerprint
prompt, and check:

```sh
adb devices          # should list your device as "device", not "unauthorized"
```

Menu names vary by vendor. On some devices "About" lives under **System**.

### 3. Install Termux and Termux:Boot

Get both from [F-Droid](https://f-droid.org/packages/com.termux/) or the
[Termux GitHub releases](https://github.com/termux/termux-app/releases).
**Don't use the Play Store build.** It's outdated, and Termux:Boot only works
when both apps come from the same source (they must share a signing key).

```sh
adb install apks/termux.apk
adb install apks/termux-boot.apk
```

Open **Termux** once so it can set itself up. Then open **Termux:Boot** once
so Android registers its boot receiver.

### 4. Install packages and set up SSH keys

In Termux on the device:

```sh
pkg update
pkg install openssh caddy
passwd               # temporary password, only needed to copy your key
sshd
```

Find the device's IP under **Settings → Wi-Fi → (your network)**, or run
`adb shell ip -4 addr show wlan0` from your computer. Then, from your
computer:

```sh
ssh-copy-id -p 8022 <device-ip>
ssh -p 8022 <device-ip>      # should log in without a password
```

### 5. Turn off password login

On the device (or over SSH):

```sh
echo 'PasswordAuthentication no' > $PREFIX/etc/ssh/sshd_config.d/99-keyonly.conf
pkill sshd; sshd
```

Check that passwords are now refused:

```sh
ssh -o PubkeyAuthentication=no -p 8022 <device-ip>   # expect "Permission denied"
```

### 6. Deploy the config and web root

From your computer, in this repo:

```sh
DEVICE_HOST=<device-ip> scripts/deploy.sh
```

For the first run, start the services by hand (or just reboot):

```sh
ssh -p 8022 <device-ip> 'sh ~/.termux/boot/start-server.sh'
```

### 7. Keep Android from killing Termux

Exempt Termux from battery optimization:

```sh
adb shell dumpsys deviceidle whitelist +com.termux
```

The boot script also takes a wake lock (`termux-wake-lock`) so the CPU
stays awake with the screen off. Some vendors (Xiaomi, Samsung, Huawei,
OnePlus, ...) add their own aggressive app killers. See
[dontkillmyapp.com](https://dontkillmyapp.com) for per-vendor settings, and
allow "autostart" for Termux:Boot if your device has that option.

### 8. Reboot and verify

```sh
adb reboot
# wait for boot, then unlock the device once (see below)
DEVICE_HOST=<device-ip> scripts/status.sh
```

You should see `ok` for ssh and `200` for http.

If the device has a screen lock, Android keeps app data encrypted until the
first unlock after boot. Termux:Boot only runs your script after that first
unlock, so an unattended reboot leaves the server down until someone
unlocks it. With no screen lock (swipe or none), it starts on its own.

## Configuration

The scripts read these environment variables:

| Variable | Default | Purpose |
|---|---|---|
| `DEVICE_HOST` | `192.168.1.69` | Device IP or hostname |
| `DEVICE_SSH_PORT` | `8022` | sshd port |
| `DEVICE_HTTP_PORT` | `8080` | Caddy port (`status.sh` only) |

Export `DEVICE_HOST` in your shell profile so you don't have to repeat it.
Alternatively, add a `Host` entry to `~/.ssh/config` and use that name:

```
Host android-server
  HostName <device-ip>
  Port 8022
```

Give the device a DHCP reservation (static lease) on your router so its IP
doesn't change. Android 10+ uses a randomized MAC for each saved network by
default. Set **Wi-Fi → (network) → Privacy → Use device MAC** before creating
the reservation (or any per-device router rule, like band steering).
Otherwise forgetting and re-adding the network gives the device a new MAC,
and a new IP.

To serve your own site, replace the contents of `device/www/` and run
`scripts/deploy.sh`. Caddy can also act as a reverse proxy or serve HTTPS.
Edit `device/Caddyfile` for that (see the
[Caddyfile docs](https://caddyserver.com/docs/caddyfile)).

## Operations

```sh
scripts/status.sh                                 # ssh + http health check
scripts/deploy.sh                                 # push device/ tree onto the device

ssh -p 8022 <device-ip> 'caddy reload --config ~/Caddyfile'   # apply Caddyfile changes
ssh -p 8022 <device-ip> 'tail ~/caddy.log'                    # web server logs
ssh -p 8022 <device-ip> 'cat ~/boot.log'                      # boot history
```

## Security

- Intended for LAN use only. Don't port-forward 8022/8080 on your router.
  For remote access, use a VPN such as WireGuard or Tailscale.
- sshd accepts public keys only, once step 5 is done.
- Caddy serves a static docroot. Its admin API (`localhost:2019`) is only
  reachable from the device itself.
- `.gitignore` excludes APKs, `.ssh/` folders, keys, and `.env*` files.
  Keep it that way.

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `adb devices` shows nothing | Cable is charge-only, or USB mode isn't set to file transfer / PTP |
| `adb devices` shows `unauthorized` | Unlock the device and accept the RSA prompt, `adb kill-server` and retry |
| Services don't start after reboot | Unlock the device once after boot. Open Termux:Boot once and make sure both apps come from the same source; check `~/boot.log`, allow autostart in vendor settings |
| Services running but unreachable after reboot | Wi-Fi didn't reconnect. Check `adb shell dumpsys wifi \| grep -E "mWifiInfo\|level2FailureCode"`. Repeated `ASSOCIATION_REJECTION` on a dual-band SSID usually means a router band-steering rule is rejecting the band Android prefers. Give the device its own single-band SSID instead. Use `adb forward` meanwhile |
| Server dies when the screen is off | Battery optimization or a vendor app killer, see step 7 |
| `bind: permission denied` | Port below 1024, use 1024 or higher |
| `pkg` errors / 404s | Run `termux-change-repo` and pick another mirror |
| IP keeps changing | Set a DHCP reservation on your router |

## Hardware

- Leaving a phone on a charger 24/7 wears the battery out over time. Use a
  firmware or vendor charge limit (often called "battery protection" or
  "limit to 80%") if your device has one.
- Keep the device somewhere with airflow. Most phones only have passive
  cooling.

## Retroid

The device this was developed and tested on:

| Spec | Value |
|---|---|
| Model | Retroid Pocket 2S (`ums512_1h10`, USB reads "Unisoc Phone") |
| SoC | Unisoc T610, 2x Cortex-A75 + 6x Cortex-A55 |
| RAM | 3.5 GB usable |
| Storage | 128 GB internal + 64 GB microSD |
| OS | Android 11 (SDK 30), build `RP2S_V1.0.0.37_20230818` |
| Kernel | Linux 4.14.193, aarch64 |
| Termux | `com.termux` 0.118.3 + `com.termux.boot` 0.8.1 (F-Droid) |
| Caddy | 2.11.7 (termux-main) |

Device-specific notes:

- USB-C carries data out of the box (vid `1782`).
- There's no user-settable charge limit. `charge_control_limit` is a µA
  current limit and only system-writable. Idles at about 25°C while plugged in.
- Verified: `adb` over USB, SSH and HTTP over both Wi-Fi and
  `adb forward`, key-only SSH, and Termux:Boot restarting sshd + Caddy after
  a reboot (runs right after the first unlock; `~/boot.log` records it).
- The router's Smart Steering pins this device to 2.4 GHz. After a reboot,
  Android's auto-join kept trying 5 GHz first and getting
  `ASSOCIATION_REJECTION`, so Wi-Fi stayed down until a manual connect
  (which went straight to 2.4 GHz). The services were still reachable over
  `adb forward`.
