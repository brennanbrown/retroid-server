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
       '.___[3.5mm]________[microSD]__________________.'
```

# retroid-server

A Retroid Pocket 2S running as a LAN web server. Termux + Caddy serving
static files on port 8080, SSH on 8022, auto-start on boot via Termux:Boot.
The folder `device/` mirrors `$HOME` on the device. Sync to the Retroid with
`scripts/deploy.sh`.

## Hardware

| Spec | Value |
|---|---|
| Model | Retroid Pocket 2S (`ums512_1h10`, USB reads "Unisoc Phone") |
| SoC | Unisoc T610, 2x Cortex-A75 + 6x Cortex-A55 |
| GPU | Mali-G52 (OpenGL ES 3.2) |
| RAM | 3.5 GB usable |
| Internal storage | 128 GB flash (`/data` = 109 GB usable) |
| microSD | 64 GB card mounted at `/storage/61FD-B500` |
| OS | Android 11 (SDK 30), build `RP2S_V1.0.0.37_20230818` |
| Kernel | Linux 4.14.193, aarch64 |
| Battery | Li-ion, 25°C at idle while plugged in |
| Network | Wi-Fi 5 (LAN IP `192.168.1.69`) |
| USB | USB-C carries data (`adb` works; vid `1782`, pid `4001` charge-only → ADB PID once debugging enabled) |

## Ports and access

| Service | Port | Auth |
|---|---|---|
| `sshd` | 8022 | public key only |
| Caddy (HTTP) | 8080 | none (LAN only) |

Using 8022/8080 (Termux defaults). Non-root Android can't bind below 1024.

```sh
# Over Wi-Fi / LAN
ssh -p 8022 192.168.1.69          # uses ~/.ssh/id_ed25519
curl http://192.168.1.69:8080/

# Over USB only (no network needed)
adb forward tcp:8022 tcp:8022
adb forward tcp:8080 tcp:8080
ssh -p 8022 localhost
curl http://localhost:8080/
```

## Files

```
device/                        mirrors $HOME on the RP2S
  Caddyfile                    -> ~/Caddyfile
  www/index.html               -> ~/www/index.html   (docroot)
  .termux/boot/start-server.sh -> ~/.termux/boot/start-server.sh
scripts/
  deploy.sh                  push device/ -> device home, chmod boot scripts
  status.sh                  ssh + http health check
apks/                        F-Droid installers (gitignored)
```

On-device logs at `~/boot.log` (boot-script timestamps) and `~/caddy.log`.

## Setup

1. `brew install --cask android-platform-tools` on MacOS.
2. RP2S: Settings → About → tap Build number x7 → Developer options →
   **USB debugging** → allow the Mac's RSA prompt. USB-C data confirmed
   (`adb devices` lists `Retroid_Pocket_2S`).
3. Replaced the Play Store Termux build with the **F-Droid** build
   (`com.termux` 0.118.3 + `com.termux.boot` 0.8.1). Run `adb install` for both.
4. In Termux: `pkg install openssh` → started `sshd` → install your
   `~/.ssh/id_ed25519.pub` into `~/.ssh/authorized_keys`.
5. Key-only hardening: `~/.termux/../usr/etc/ssh/sshd_config.d/99-keyonly.conf`
   sets `PasswordAuthentication no`.
6. `pkg install caddy` (2.11.7 in termux-main) → `Caddyfile` serves
   `~/www` on `:8080`.
7. `dumpsys deviceidle whitelist +com.termux` exempted Termux from
   battery optimization via adb.
8. `~/.termux/boot/start-server.sh`: `termux-wake-lock` → `sshd` →
   `caddy run` under `nohup`, logging to `~/caddy.log`.

## Operations

```sh
scripts/status.sh                         # ssh + http health check
scripts/deploy.sh                         # push repo device/ tree onto the unit
RETROID_HOST=10.0.0.5 scripts/deploy.sh   # override target host

ssh -p 8022 192.168.1.69 'caddy stop; caddy start --config ~/Caddyfile'  # restart web
ssh -p 8022 192.168.1.69 'tail ~/caddy.log'                              # logs
```

## Security

- LAN-only currently.
- sshd does not use passwords.
- Caddy serves a static docroot; the admin API (`localhost:2019`) is
  device-local only.

## Maintence

- No firmware charge limit for the battery.
  (`charge_control_limit` is a µA current limit and system-writable only).
  Passive cooling only.
- Termux is doze-whitelisted, and the boot script.

## Verification

- [x] USB-C data + `adb` from the Mac
- [x] Termux (F-Droid) + `sshd` reachable over Wi-Fi and `adb forward`
- [x] Static page on 8080 reachable from the Mac (both paths)
- [x] Key-only SSH enforced; Termux battery-exempted
- [x] Reboot → Termux:Boot brings back sshd + Caddy (`~/boot.log` records the run)

## Installation

Download `termux_1002.apk` and `termux-boot_1000.apk`) with
`adb install` → open each once → install openssh + caddy → deploy
`device/` → run boot script contents once by hand.
