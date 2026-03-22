# APPS.md — Software Inventory

> **Host:** mk-uP5520
> **OS:** Ubuntu 24.04.4 LTS
> **Kernel:** 6.19.8-061908-generic
> **Last updated:** 2026-03-22 14:50:12
> **Hardware:** Dell Inc. Precision 5520
> **GPU:** NVIDIA Corporation GM107GLM [Quadro M1200 Mobile] (rev a2)

---

## Table of Contents

1. [APT — OS & Core Packages](#apt--os--core-packages)
2. [APT — Third-Party Applications](#apt--third-party-applications)
3. [Snap Packages](#snap-packages)
4. [Homebrew Formulas](#homebrew-formulas)
5. [Homebrew Casks](#homebrew-casks)
6. [npm Global Packages](#npm-global-packages)
7. [Drivers & Firmware](#drivers--firmware)
8. [Manually Installed / /opt](#manually-installed--opt)

---

## APT — OS & Core Packages

| Package | Version | Source |
|---------|---------|--------|
| `ubuntu-desktop` | 1.539.2 | Ubuntu |
| `ubuntu-desktop-minimal` | 1.539.2 | Ubuntu |
| `ubuntu-standard` | 1.539.2 | Ubuntu |
| `ubuntu-minimal` | 1.539.2 | Ubuntu |

## APT — Third-Party Applications

| Application | Package | Version | Source/Repo |
|-------------|---------|---------|-------------|
| BleachBit | `bleachbit` | 4.6.0-3 | ubuntu-repo |
| Brave Browser | `brave-browser` | 1.88.134 | brave-browser-release.sources |
| build-essential | `build-essential` | 12.10ubuntu1 | ubuntu-repo |
| containerd.io | `containerd.io` | 2.2.2-1~ubuntu.24.04~noble | docker.sources |
| curl | `curl` | 8.5.0-2ubuntu10.8 | ubuntu-repo |
| Docker Buildx Plugin | `docker-buildx-plugin` | 0.31.1-1~ubuntu.24.04~noble | docker.sources |
| Docker CE | `docker-ce` | 5:29.3.0-1~ubuntu.24.04~noble | docker.sources |
| Docker CLI | `docker-ce-cli` | 5:29.3.0-1~ubuntu.24.04~noble | docker.sources |
| Docker Compose Plugin | `docker-compose-plugin` | 5.1.1-1~ubuntu.24.04~noble | docker.sources |
| Git | `git` | 1:2.43.0-1ubuntu7.3 | ubuntu-repo |
| Google Chrome | `google-chrome-stable` | 146.0.7680.153-1 | google-chrome.list |
| Grub Customizer | `grub-customizer` | 5.2.5-0ubuntu1~ppa1n | PPA danielrichter2007 |
| MegaSync | `megasync` | 6.1.1-2.1 | meganz.list |
| Midnight Commander | `mc` | 3:4.8.30-1ubuntu0.1 | ubuntu-repo |
| Node.js (system) | `nodejs` | 18.19.1+dfsg-6ubuntu5 | ubuntu-repo |
| npm (system) | `npm` | 9.2.0~ds1-2 | ubuntu-repo |
| NVIDIA Container Toolkit | `nvidia-container-toolkit` | 1.19.0-1 | nvidia-container-toolkit.list |
| NVIDIA Driver 580 | `nvidia-driver-580` | 580.126.09-0ubuntu0.24.04.2 | ubuntu-repo |
| Proton Mail | `proton-mail` | 1.12.1 | protonvpn-stable.sources |
| ProtonVPN Daemon | `proton-vpn-daemon` | 0.13.6 | protonvpn-stable.sources |
| ProtonVPN (GTK) | `proton-vpn-gtk-app` | 4.15.0 | protonvpn-stable.sources |
| Rclone | `rclone` | 1.60.1+dfsg-3ubuntu0.24.04.4 | ubuntu-repo |
| Remmina | `remmina` | 1.4.35+dfsg-0ubuntu5.1 | ubuntu-repo |
| Remote Desktop Manager | `remotedesktopmanager` | 2025.3.1.1 | devolutions.net |
| VS Code | `code` | 1.112.0-1773778351 | vscode.sources |
| wget | `wget` | 1.21.4-1ubuntu4.1 | ubuntu-repo |

## Snap Packages

| Application | Version | Revision | Channel | Publisher |
|-------------|---------|----------|---------|-----------|
| `bare` *(runtime)* | 1.0 | 5 | latest/stable | canonical** |
| `core22` *(runtime)* | 20260225 | 2411 | latest/stable | canonical** |
| `core24` *(runtime)* | 20260211 | 1499 | latest/stable | canonical** |
| **firefox** | 148.0.2-1 | 7967 | latest/stable | mozilla** |
| **firmware-updater** | 0+git.7d22721 | 223 | latest/stable | canonical** |
| `gnome-42-2204` *(runtime)* | 0+git.c1d3d69-sdk0+git.015db9a | 247 | latest/stable/… | canonical** |
| `gnome-46-2404` *(runtime)* | 0+git.f1cd5fa-sdk0+git.ca9c59c | 153 | latest/stable | canonical** |
| `gtk-common-themes` *(runtime)* | 0.1-81-g442e511 | 1535 | latest/stable/… | canonical** |
| **htop** | 3.4.1 | 5548 | latest/stable | maxiberta* |
| **keepassxc** | 2.7.9 | 1854 | latest/stable | keepassxreboot |
| `kf5-5-113-qt-5-15-11-core22` *(runtime)* | 5.113 | 1 | latest/stable | kde** |
| `mesa-2404` *(runtime)* | 25.0.7-snap211 | 1165 | latest/stable | canonical** |
| **snap-store** | 0+git.515109e7 | 1310 | 2/stable/… | canonical** |
| `snapd` *(runtime)* | 2.74.1 | 26382 | latest/stable | canonical** |
| `snapd-desktop-integration` *(runtime)* | 0.9 | 343 | latest/stable | canonical** |
| **thunderbird** | 140.8.1esr-1 | 1029 | latest/stable | canonical** |

## Homebrew Formulas

> Linuxbrew prefix: `/home/linuxbrew/.linuxbrew`
> Node.js/npm managed by brew — **use brew versions, not system apt ones**.

| Formula | Version | Description |
|---------|---------|-------------|
| `ada-url` | 3.4.3 | WHATWG-compliant and fast URL parser written in modern C++ |
| `berkeley-db@5` | 5.3.28_1 | High performance key/value database |
| `binutils` | 2.46.0 | GNU binary tools for native development |
| `brotli` | 1.2.0 | Generic-purpose lossless compression algorithm by Google |
| `bzip2` | 1.0.8 | Freely available high-quality data compressor |
| `ca-certificates` | 2026-03-19 | Mozilla CA certificate store |
| `c-ares` | 1.34.6 | Asynchronous DNS library |
| `expat` | 2.7.5 | XML 1.0 parser |
| `fmt` | 12.1.0 | Open-source formatting library for C++ |
| `gcc` | 15.2.0_1 | GNU compiler collection |
| `gemini-cli` | 0.34.0 | Interact with Google Gemini AI models from the command-line |
| `gmp` | 6.3.0 | GNU multiple precision arithmetic library |
| `hdrhistogram_c` | 0.11.9 | C port of the HdrHistogram |
| `icu4c@78` | 78.3 | C/C++ and Java libraries for Unicode and globalization |
| `isl` | 0.27 | Integer Set Library for the polyhedral model |
| `libedit` | 20251016-3.1_1 | BSD-style licensed readline alternative |
| `libffi` | 3.5.2 | Portable Foreign Function Interface library |
| `libmpc` | 1.4.0 | C library for the arithmetic of high precision complex numbers |
| `libnghttp2` | 1.68.1 | HTTP/2 C Library |
| `libnghttp3` | 1.15.0 | HTTP/3 library written in C |
| `libngtcp2` | 1.21.0 | IETF QUIC protocol implementation |
| `libuv` | 1.52.1 | Multi-platform support library with a focus on asynchronous I/O |
| `libx11` | 1.8.13 | X.Org: Core X11 protocol client library |
| `libxau` | 1.0.12 | X.Org: A Sample Authorization Protocol for X |
| `libxcb` | 1.17.0 | X.Org: Interface to the X Window System protocol |
| `libxdmcp` | 1.1.5 | X.Org: X Display Manager Control Protocol library |
| `llhttp` | 9.3.1 | Port of http_parser to llparse |
| `lz4` | 1.10.0 | Extremely Fast Compression algorithm |
| `mpdecimal` | 4.0.1 | Library for decimal floating point arithmetic |
| `mpfr` | 4.2.2 | C library for multiple-precision floating-point computations |
| `ncurses` | 6.6 | Text-based UI library |
| `node` | 25.8.1_1 | Open-source, cross-platform JavaScript runtime environment |
| `opencode` | 1.2.20 | AI coding agent, built for the terminal |
| `openssl@3` | 3.6.1 | Cryptography and SSL/TLS Toolkit |
| `pcre2` | 10.47_1 | Perl compatible regular expressions library with a new API |
| `python@3.14` | 3.14.3_1 | Interpreted, interactive, object-oriented programming language |
| `qwen-code` | 0.12.6 | AI-powered command-line workflow tool for developers |
| `readline` | 8.3.3 | Library for command-line editing |
| `ripgrep` | 15.1.0 | Search tool like grep and The Silver Searcher |
| `simdjson` | 4.4.2 | SIMD-accelerated C++ JSON parser |
| `sqlite` | 3.52.0 | Command-line interface for SQLite |
| `unzip` | 6.0_8 | Extraction utility for .zip compressed archives |
| `uvwasi` | 0.0.23 | WASI syscall API built atop libuv |
| `xorgproto` | 2025.1 | X.Org: Protocol Headers |
| `xsel` | 1.2.1 | Command-line program for getting and setting the contents of the X selection |
| `xz` | 5.8.2 | General-purpose data compression with high compression ratio |
| `zlib` | 1.3.2 | General-purpose lossless data-compression library |
| `zlib-ng-compat` | 2.3.3_1 | Zlib replacement with optimizations for next generation systems |
| `zstd` | 1.5.7_1 | Zstandard is a real-time compression algorithm |

## Homebrew Casks

| Application | Version | Description |
|-------------|---------|-------------|
| **claude-code** | 2.1.81 | claude-code: 2.1.81 |
| **codex** | 0.116.0 | codex: 0.116.0 |

## npm Global Packages

> Using Homebrew Node.js: `/home/linuxbrew/.linuxbrew/bin/node`

| Package | Version |
|---------|---------|
| `npm@11.11.0` | (see brew node) |
| `` | (see brew node) |

## Drivers & Firmware

### NVIDIA

| Component | Version / Status |
|-----------|-----------------|
| NVIDIA Driver 580 (apt) | 580.126.09-0ubuntu0.24.04.2 |
| NVIDIA Container Toolkit | 1.19.0-1 |
| nvidia-smi GPU | NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver. Make sure that the latest NVIDIA driver is installed and running.
not loaded (reboot required) |
| Running kernel | 6.19.8-061908-generic |

### Firmware (fwupd)

| Device | Current Version |
|--------|----------------|
| Core™ i7-7820HQ CPU @ 2.90GHz | 0x000000f8 |
| GM107GLM [Quadro M1200 Mobile] | a2 |
| HD Graphics 630 | 04 |
| SSD 970 EVO Plus 2TB | 2B2QEXM7 |
| System Firmware | 1.40.0 |
| AMT [unprovisioned] | 11.8.96.4657 |
| UEFI dbx | 20230501 |
| TPM | 1.3.2.8 |

### Dell BIOS

| Property | Value |
|----------|-------|
| BIOS Version | N/A |
| BIOS Release Date | N/A |
| System | Dell Precision 5520 |

## Manually Installed / /opt

| Application | Location | Version |
|-------------|----------|---------|
| Brave Browser | `/opt/brave.com/brave` | 146.1.88.134 |
| Google Chrome | `/opt/google/chrome` | 146.0.7680.153 |
| MegaSync | `/opt/megasync` | MEGA v6.1.1 (1c13b13) |
| Docker (symlink) | `/usr/local/bin/docker` | 29.3.0 |
| Claude Code CLI | `/home/linuxbrew/.linuxbrew/bin/claude` | 2.1.81 (Claude Code) |

---

## APT Sources (Third-Party Repos)

| Repo/PPA | File |
|----------|------|
| Brave Browser | `/etc/apt/sources.list.d/brave-browser-release.sources` |
| Google Chrome | `/etc/apt/sources.list.d/google-chrome.list` |
| VS Code | `/etc/apt/sources.list.d/vscode.sources` |
| Docker CE | `/etc/apt/sources.list.d/docker.sources` |
| NVIDIA Container Toolkit | `/etc/apt/sources.list.d/nvidia-container-toolkit.list` |
| MegaSync | `/etc/apt/sources.list.d/meganz.list` |
| ProtonVPN | `/etc/apt/sources.list.d/protonvpn-stable.sources` |
| Grub Customizer PPA | `/etc/apt/sources.list.d/danielrichter2007-ubuntu-grub-customizer-noble.sources` |

---

*Auto-generated by `scripts/update-inventory.sh` — do not edit manually.*
