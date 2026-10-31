# RAVLIN Graphical

A **minimal Void Linux distribution with a KDE Plasma 6 graphical session** — the graphical sibling of [RAVLIN](https://github.com/stainleSSStar/RAVLIN). It boots into **SDDM + KDE Plasma (X11)** on tty1, keeps **fish as the default shell** (in Konsole and on the console), and keeps RAVLIN's **working wifi, LAN, and sound** out of the box. It also ships an **interactive console installer** (`void-installer`) and a serial console on the live image.

> Status: `0.1.0` — KDE Plasma (X11 session) on a minimal TTY base. A Wayland session can be added later via the `plasma-workspace-wayland` subpackage + `qt6-wayland`.

## What's in it

| Area | Choice |
|---|---|
| Base | Void Linux `base-system` (glibc, runit, xbps, kernel) |
| Shell | fish — default for root, new users, and Konsole |
| Installer | `void-installer` — Void's interactive dialog-based console install |
| Desktop | KDE Plasma 6 (`plasma-desktop`, `plasma-workspace`, `kwin`, Breeze theme) via **SDDM** |
| Display | Xorg (`xorg-minimal` + vesa/fbdev fallbacks), `mesa-dri` (incl. llvmpipe for VMs) |
| Drivers | `linux-firmware` (full: wifi/LAN **and** GPU blobs), `sof-firmware` + `alsa-ucm-conf` (sound) |
| Networking | `dhcpcd` + `wpa_supplicant` (enabled by default) |
| Sound | `alsa-utils` + PipeWire (`pipewire`, `wireplumber` — ships the PulseAudio compat layer) with `plasma-pa` tray applet |
| Session mgmt | `elogind` (logind) so Plasma logout/shutdown/restart work on runit; `polkit-kde-agent` |
| Apps | `konsole`, `dolphin`, `systemsettings` — the essentials to run and configure the desktop |
| Bootloader | GRUB (BIOS + 32/64-bit EFI) |

The full package list on top of `base-system` is [`packages.txt`](packages.txt) — RAVLIN's list plus the graphical stack. Everything else (X11/Wayland session extras, NetworkManager, pipewire-video, tmux, etc.) is deliberately left out to stay small.

bash and dash stay installed because system scripts (including `void-installer`) need them — fish replaces them only as the *login* shell.

## Building the ISO

The build uses [void-mklive](https://github.com/void-linux/void-mklive) (pinned commit), so you need either a Void Linux host or Docker:

```sh
git clone https://github.com/stainleSSStar/RAVLIN-graphical.git
cd RAVLIN-graphical
bash build.sh
```

- On a **Void host**, the build runs natively.
- Anywhere else (macOS, other Linux, CI), it automatically runs inside the official `ghcr.io/void-linux/void-glibc` container (`--privileged`, required by mklive). The build script is Bash 3.2 compatible, so macOS's bundled shell can drive it; only the container itself needs bash, which the entrypoint installs on demand.

Output: `ravlin-graphical-live-x86_64-0.1.0.iso`.

Useful overrides (honoured on the native path *and* forwarded into the Docker/Podman path):

```sh
RAVLIN_MIRROR=https://repo-default.voidlinux.org/current bash build.sh  # pick a mirror
MKLIVE_REF=master bash build.sh                                          # track upstream mklive
```

### CI builds and releases

No local tooling needed — the repo ships a GitHub Actions workflow (`.github/workflows/build.yml`) that builds the ISO in the same privileged Void container void-mklive uses for its own CI, and can publish a release:

- **Manual build:** GitHub → *Actions* → *Build RAVLIN Graphical ISO* → *Run workflow*. Tick **"Also publish a GitHub release"** to publish the ISO as a release in one go.
- **Tag build:** push a tag like `v0.1.0` — the ISO is built and released automatically (`v*` tags trigger the release job).

Every release ships the ISO plus a `sha256sum.txt`. By default releases land on this repository's *Releases* page. To publish into a separate releases repository instead, add two repository secrets:

| Secret | Value |
|---|---|
| `RELEASES_REPO` | e.g. `stainleSSStar/RAVLIN-graphical-releases` |
| `RELEASES_TOKEN` | a personal access token with `contents:write` on that repo |

#### What CI validates

Every build is gated on three QEMU jobs (software emulation — the runners have no KVM), all booting the actual ISO artifacts:

- **BIOS boot** — the ISO boots through its own bootloader chain (SeaBIOS → ISOLINUX → kernel); over the serial console CI verifies: fish login shell with the RAVLIN config, `void-installer` present, RAVLIN Graphical `os-release`, `dhcpcd`/`wpa_supplicant` *running*, ALSA detecting the emulated sound card, the live hostname, and **SDDM + elogind + PipeWire + WirePlumber running** (the graphical stack is up).
- **UEFI boot** — the same ISO boots through the EFI chain (OVMF → GRUB EFI → kernel) to a working live session with SDDM running.
- **Install test** — boots the live ISO, then drives the *real interactive `void-installer`* through its dialog menus onto a blank 12 GiB disk (Local source). The disk then boots through its own GRUB and the installed system is verified: fish, identity, services, sound — plus **SDDM, PipeWire and the Plasma session present on the installed disk** — including a *forced `base-files` reinstall* to prove the `os-release` survives package updates (the `preserve=` pattern in `/etc/xbps.d/49-ravlin-graphical-preserve.conf`).

Honest limits: tests run on emulated hardware (virtio disk/NIC, emulated HDA audio, vesa/std VGA), so physical wifi radios, GPUs and speakers remain untested by CI. The graphical session is verified by service/process checks over the serial console, not by screenshot.

### Repository layout

```
├── build.sh              # entry point: fetches void-mklive, assembles the ISO
├── packages.txt          # live ISO package list (RAVLIN's + KDE Plasma stack)
├── postsetup.sh          # mklive hook: fish registration, os-release, service enabling
├── rootfs/               # overlay copied into the live image (-I)
│   ├── etc/
│   │   ├── os-release    # RAVLIN Graphical identity
│   │   ├── xbps.d/49-ravlin-graphical-preserve.conf  # keep os-release across base-files updates
│   │   ├── issue, motd   # live session branding & instructions
│   │   ├── shells        # valid login shells
│   │   ├── hostname      # default hostname: ravlin
│   │   ├── default/useradd   # new users get SHELL=/usr/bin/fish
│   │   └── skel/.config/fish/config.fish   # fish prompt for new users
│   └── root/.config/fish/config.fish       # fish prompt for root
├── ci/                   # QEMU/expect boot, install and verify scripts
│   ├── smoke-bios.exp    # BIOS boot test via the ISO's ISOLINUX bootloader
│   ├── smoke-uefi.exp    # UEFI boot test via the ISO's GRUB EFI bootloader
│   ├── install-ravlin.exp    # drives the real interactive void-installer
│   ├── verify-install.exp    # boots the installed disk via its own GRUB
│   └── postinstall-chroot.sh # CI-only serial-console test plumbing
└── .gitignore
```

`rootfs/usr/bin/void-installer` is generated at build time from void-mklive's `installer.sh` (with RAVLIN Graphical branding) — same mechanism `mkiso.sh` uses, minus the extra packages.

## Installing

1. Write the ISO to a USB stick and boot it:
   ```sh
   sudo dd if=ravlin-graphical-live-x86_64-0.1.0.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
2. The live system boots into the **SDDM login screen** on tty1. Log in as `root` (password `voidlinux`) — you land in KDE Plasma. A serial console login is available too.
3. Run the installer from a terminal (Konsole) or a console tty:
   ```fish
   void-installer
   ```
   It walks you through keymap, locale, timezone, hostname, root password, user creation, partitioning (`cfdisk`/`fdisk`), mount points, GRUB, and services — fully interactive, no graphical installer.
4. Choose the default **local install** source when prompted (see note below).
5. Reboot into the installed RAVLIN Graphical system — SDDM + Plasma again, now from disk. New users log into fish inside Konsole.

### Important note on install sources

`void-installer` offers two sources:

- **Local (default)** — copies the live rootfs to disk. This is the RAVLIN Graphical install: KDE Plasma, fish everywhere, drivers, branding. Use this.
- **Network** — installs a stock Void `base-system` from a mirror and **does not include the RAVLIN Graphical package set**, because it pulls the vanilla Void metapackage. Avoid it for now.

## Post-install quick reference

```fish
# wifi (WPA): edit /etc/wpa_supplicant/wpa_supplicant.conf, then:
wpa_passphrase "SSID" "password" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf
sudo ln -s /etc/sv/wpa_supplicant /var/service/   # if not already enabled

# sound in Plasma: the plasma-pa tray applet controls PipeWire; alsamixer works too

# packages
sudo xbps-install -S <pkg>
sudo xbps-remove <pkg>
```

Optional additions if you want more than the minimum: `NetworkManager` + `plasma-nm` for GUI wifi management, `udisks2` for removable media in Dolphin, `intel-ucode`/`amd-ucode` for CPU microcode, `plasma-workspace-wayland` + `qt6-wayland` for a Wayland session.

## Design decisions

- **KDE Plasma on top of RAVLIN's TTY base.** Same build pipeline (void-mklive), same installer, same fish/networking/sound choices — plus `sddm`, Plasma, Xorg, PipeWire and elogind.
- **X11 session by default.** Plasma 6 runs fine on Xorg; this keeps the package set small and works on the widest hardware (incl. VMs via vesa/llvmpipe). Wayland is an optional add-on (see above).
- **PipeWire instead of PulseAudio.** Plasma 6 expects PipeWire; Void's `pipewire` package ships the PulseAudio compatibility layer, so ALSA/Pulse apps keep working.
- **elogind enabled.** On runit there is no systemd-logind; elogind provides the logind API so Plasma's logout/shutdown/restart and `polkit-kde-agent` work.
- **void-installer instead of a custom installer.** Same reasoning as RAVLIN: upstream, battle-tested, dialog-based. Local-source installs copy the whole live rootfs — graphical stack included.
- **bash stays installed.** Removing it breaks virtually every system script. fish is the *default shell*, not the only binary on disk.
- **os-release branding persists — explicitly.** Same mechanism as RAVLIN: `postsetup.sh` replaces the `base-files` symlink with a real file, and `/etc/xbps.d/49-ravlin-graphical-preserve.conf` tells xbps to preserve it across `base-files` updates. CI proves it with a forced reinstall.
- **Live hostname is ravlin.** The pinned void-mklive checkout is patched so the vmklive dracut hook writes `ravlin` instead of `void-live`.
- **Serial console on the live image.** The live kernel cmdline carries `console=tty0 console=ttyS0`, so a live session is also usable over serial — CI drives all its checks over it while SDDM owns tty1. Installed systems are untouched (the installer writes its own GRUB config).

## Roadmap

- [x] TTY base with fish, wifi/LAN/sound (inherited from RAVLIN)
- [x] KDE Plasma 6 graphical session (this repo)
- [ ] Optional CPU microcode packages
- [ ] RAVLIN metapackage in a hosted xbps repository (network-source installs)
- [ ] Wayland session option

## Credits

- [Void Linux](https://voidlinux.org) — the base distribution
- [void-mklive](https://github.com/void-linux/void-mklive) — the live image generator and the console installer
- [KDE Plasma](https://kde.org/plasma-desktop/) — the desktop environment
- [RAVLIN](https://github.com/stainleSSStar/RAVLIN) — the TTY-only sibling this distro is based on
