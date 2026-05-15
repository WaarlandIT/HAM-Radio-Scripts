# Ham Radio Software Installer

The bash script installs a large number of HAM-Radio related software packages, organises them into a **Ham Radio** submenu in your desktop applications menu, and writes proper `.desktop` entries for every application.

> **Version 1.0.2 — 2026-05-15**

---

## Requirements

- Ubuntu **26.04 LTS "Resolute Raccoon"**
- Regular user account with `sudo` privileges
- Active internet connection throughout the installation
- x86\_64 (amd64), ARM64, or ARMv7 CPU architecture

> The script will warn you and ask for confirmation if it detects a non-26.04 system.

---

## Companion scripts

Two helper scripts are provided alongside the installer:

| Script | Purpose |
| --- | --- |
| `check_links.sh` | Verifies every download URL and git repository used by the installer |
| `check_packages.sh` | Checks every required apt package against the 26.04 repos before installing |

Run these first to spot any issues on your specific machine before committing to the full install.

---

## Quick start

Download the script:

```bash
wget https://raw.githubusercontent.com/WaarlandIT/HAM-Radio-Scripts/refs/heads/main/install_hamradio.sh
```

Make it executable and run it:

```bash
chmod +x install_hamradio.sh
./install_hamradio.sh
```

The script asks for your station details:

```
Enter your ham radio callsign:
Enter your handle/name:
Enter your grid square (e.g. JO22):
```

---

## Installation menu

After entering your details, the main menu appears:

```
================================================
   Ham Radio Software Installer v1.0.2
   Ubuntu resolute edition
================================================
Callsign: PA3RPW | Grid: JO22
================================================

1.  Install ALL packages (recommended first-time setup)
2.  System preparation & core utilities
3.  Digital modes (WSJT-X, JS8Call, FLDigi suite)
4.  APRS applications (Xastir, Direwolf, YAAC)
5.  Logging applications (CQRLOG, KLog, TrustedQSL)
6.  SDR applications (GQRX, CubicSDR, SDRAngel)
7.  Morse code applications
8.  Antenna modeling (NEC2, Yagiuda)
9.  Winlink (Pat Winlink with ARDOP)
10. Satellite tracking (Gpredict)
11. General ham radio utilities
12. Install HamClock
13. Install DX Spider Cluster server
14. Install VarAC (Wine-based chat over VARA)
15. Install D-Rats (D-STAR data communications)
16. Install voacapl + pythonprop (HF propagation)

0.  Exit
```

Choose **1** to install everything. Individual categories can be installed separately by choosing their number — useful for re-running a single section or adding something later.

> **Note:** The full install skips VarAC (option 14) because it requires a manual ZIP download. Run option 14 separately after downloading the ZIP from [varac-hamradio.com/download](https://www.varac-hamradio.com/download).

Packages are installed from the Ubuntu repositories, the developer's website, or compiled from source where necessary. **Do not interrupt the internet connection and keep the computer active throughout.**

---

## During installation

**AX.25 configuration** — during the Winlink section, a dialog may appear asking about AX.25 packet radio. Use the arrow keys to select **Yes** and press Enter.

**Pat Winlink config** — a config file opens in an editor. You can enter your callsign and other details now, or close without changes (`Ctrl+X`) and edit `~/.config/pat/config.json` later.

---

## After installation

When complete you will see:

```
[INFO] All installations complete!
```

Press **Enter** to exit. A post-installation summary is printed:

```
========================================================
  Post-Installation Notes
========================================================

GENERAL
  • Log out and back in for group permission changes
  • All apps appear under 'Ham Radio' in your applications menu
  • Station: PA3RPW  |  Grid: JO22

DIGITAL MODES
  • WSJT-X:      wsjtx        (configure station on first run)
  • GridTracker: gridtracker

WINLINK / ARDOP
  • Edit config:   ~/.config/pat/config.json
  • Run ARDOP:     ardopcf 8515 <capture_dev> <playback_dev>
  • List devices:  aplay -l
  • As a service:  sudo systemctl enable --now ardop@$USER

VARAC  (requires manual install — menu option 14)
  • Download ZIP:  https://www.varac-hamradio.com/download
  • Enable 'Linux Compatible Mode' on first launch

D-RATS
  • Run:    d-rats
  • Update: git -C ~/hamradio/d-rats pull

VOACAPL / VOACAP GUI
  • GUI: voacapgui
  • CLI: voacapl ~/itshfbc
  • Missing data? Run: makeitshfbc

SDR
  • Blacklist DVB-T if RTL-SDR isn't detected:
    echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf
  • SDRPlay drivers: https://www.sdrplay.com/downloads/

========================================================
  73 de PA3RPW
========================================================
```

---

## Post-installation notes

- **Log out and back in** for USB and serial port group permissions (`plugdev`, `dialout`) to take effect.
- **VarAC** requires a manual ZIP download from [varac-hamradio.com/download](https://www.varac-hamradio.com/download) — use menu option 14 separately.
- **SDRPlay RSP** users: download drivers from [sdrplay.com/downloads](https://www.sdrplay.com/downloads/).
- **RTL-SDR** users may need to blacklist the DVB-T kernel module:
  ```bash
  echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf
  ```
- **HamClock**: the original creator (WB0OEW) became a Silent Key in January 2026 and the original site is offline. The installer uses the community-maintained source fork and points HamClock at the community backend (`hamclock.com:80`).

---

## Installed software

All applications appear under a **Ham Radio** submenu in your desktop applications menu, grouped by category.

### Digital Modes

| Application | Description |
| --- | --- |
| [WSJT-X](https://wsjt.sourceforge.io/) | Weak-signal digital modes: FT8, FT4, JT65, WSPR, and more. The standard for HF DX and contest operating. |
| [JTDX](https://www.jtdx.tech/) | Alternative WSJT-X fork with additional decoding improvements for FT8/JT65. |
| [JS8Call](https://js8call.com/) | Keyboard-to-keyboard messaging using the JS8 mode — a conversational variant of FT8. |
| [GridTracker](https://gridtracker.org/) | Real-time map and grid square overlay for WSJT-X and JS8Call traffic. Version resolved dynamically at install time. |
| [FLDigi](http://www.w1hkj.com/) | Multi-mode software modem supporting PSK31, RTTY, CW, Olivia, SSTV, and many others. |
| [FLRig](http://www.w1hkj.com/) | CAT rig control front-end that integrates with FLDigi and other logging software. |
| [FLMsg](http://www.w1hkj.com/) | Structured message forms for ICS/FEMA traffic handling over FLDigi. |
| [FLAmp](http://www.w1hkj.com/) | Multi-station ARQ file transfer using the AMP protocol over FLDigi. |
| [FLArq](http://www.w1hkj.com/) | ARQ file transfer for FLDigi. Has no separate tarball — built from inside the fldigi source tree. |
| [QSSTV](https://charlesreid1.com/wiki/QSSTV) | Slow-scan television (SSTV) and HAMDRM digital image transmission. |
| [XLog](https://www.nongnu.org/xlog/) | Lightweight QSO logger that integrates with FLDigi for on-air logging. |

---

### Logging

| Application | Description |
| --- | --- |
| [CQRLOG](https://www.cqrlog.com/) | Full-featured DX and contest logger with cluster spotting, LoTW upload, and online lookups. |
| [KLog](https://www.klog.xyz/) | Cross-platform QSO logger with ADIF support and award tracking. |
| [TrustedQSL](https://lotw.arrl.org/lotw-help/installation/) | ARRL Logbook of the World (LoTW) client for digitally signing and submitting QSOs. |
| [PyQSO](https://github.com/ctjacobs/pyqso) | Lightweight Python/GTK QSO logging application with ADIF import/export. |
| [TLF](https://tlf.sourceforge.net/) | Ncurses-based contest logger popular for CW and phone contests. |

---

### SDR (Software Defined Radio)

| Application | Description |
| --- | --- |
| [GQRX](https://gqrx.dk/) | Graphical SDR receiver supporting RTL-SDR, HackRF, LimeSDR, and other SoapySDR hardware. |
| [CubicSDR](https://cubicsdr.com/) | Cross-platform SDR receiver with a clean spectrum/waterfall interface. |
| [Quisk](https://james.ahlstrom.name/quisk/) | SDR transceiver software with transmit support for compatible hardware. |
| [CuteSDR](https://sourceforge.net/projects/cutesdr/) | Simple Qt-based SDR receiver application. |
| [SoapySDR](https://github.com/pothosware/SoapySDR) | Hardware abstraction layer providing a unified API across SDR devices. |
| [RTL-SDR](https://osmocom.org/projects/rtl-sdr) | Driver and utilities for RTL2832U-based DVB-T dongles used as wideband receivers. |

> **Note:** SDRPlay RSP drivers must be downloaded separately from [sdrplay.com/downloads](https://www.sdrplay.com/downloads/).

---

### APRS

| Application | Description |
| --- | --- |
| [Xastir](https://xastir.org/) | Feature-rich APRS mapping client with support for TNC, internet, and audio interfaces. |
| [Direwolf](https://github.com/wb2osz/direwolf) | Software TNC and APRS decoder/encoder. Supports AFSK, KISS, AGW, and iGate operation. |
| [APRx](https://github.com/OH2MQK/aprx) | Lightweight APRS iGate and digipeater daemon. |
| [APRS Digi](https://github.com/n1vux/aprsdigi) | Standalone AX.25/APRS digipeater. |

---

### Satellite

| Application | Description |
| --- | --- |
| [Gpredict](https://gpredict.oz9aec.net/) | Real-time satellite tracking with Doppler correction control for rigs and rotators. |

---

### Winlink

| Application | Description |
| --- | --- |
| [Pat](https://getpat.io/) | Winlink email-over-radio client supporting ARDOP, Vara, Pactor, and packet. |
| [ardopcf](https://github.com/pflarue/ardop) | ARDOP TNC for HF Winlink connections. Installed from binary release or built from source. |
| AX.25 tools | Linux AX.25 stack utilities (`ax25-tools`, `ax25-apps`) for packet radio. |

---

### Winlink / Chat

| Application | Description |
| --- | --- |
| [VarAC](https://www.varac-hamradio.com/) | Chat and file transfer over the VARA HF/FM modem. Runs under Wine. **Requires manual ZIP download** from [varac-hamradio.com/download](https://www.varac-hamradio.com/download) — use menu option 14. |

---

### Antenna Modeling

| Application | Description |
| --- | --- |
| [NEC2C](https://www.nec2.org/) | Numerical Electromagnetics Code antenna modeling engine, compiled for Linux. |
| [xNEC2C](https://www.xnec2c.org/) | GTK graphical front-end for NEC2C with real-time pattern visualisation. |
| [YagiUDA](https://www.vk5dj.com/yagi.html) | Command-line Yagi-Uda antenna design and optimisation tool. |

---

### Morse Code

| Application | Description |
| --- | --- |
| [Aldo](https://www.nongnu.org/aldo/) | Interactive Morse code trainer using the Koch method. |
| CW | CW keyer and tone generator for sending and playing back Morse. |
| CWcp | Curses-based Morse code practice application. |
| XCWcp | X11 graphical Morse code practice tool. |
| Morse | Text-to-Morse conversion utility. |
| Morse2ASCII | Decodes Morse audio or text input to ASCII. |
| MorseGen | Morse code audio file generator. |
| [QRQ](https://fkurz.net/ham/qrq.html) | High-speed CW trainer designed for experienced operators. |
| XDeMorse | Visual Morse code decoder with audio input. |

---

### Utilities

| Application | Description |
| --- | --- |
| [HamClock](https://github.com/marshmadnesss/ESPHamClock) | Clock, solar conditions, propagation bands, and DX spots display. Built from community-maintained source fork. Uses `hamclock.com:80` as backend (original site offline since Jan 2026). |
| [CHIRP](https://chirp.danplanet.com/) | Cross-platform radio memory programmer supporting hundreds of VHF/UHF transceivers. |
| [FreeDV](https://freedv.org/) | Open-source digital voice mode for HF, using codec2 for narrow-bandwidth SSB. |
| [XDX](https://www.dxwatch.com/) | DX cluster telnet client for spotting and call lookups. |
| [SPLAT!](https://www.qsl.net/kd2bd/splat.html) | RF terrain analysis and path-loss prediction tool using SRTM elevation data. |
| [HamLib](https://hamlib.github.io/) | `rigctl` / `rotctl` — command-line rig and rotator control utilities. |
| GPSd | GPS daemon with client tools for position-aware applications. |
| [voacapl](https://github.com/jawatson/voacapl) | VOACAP HF propagation prediction engine, built from source. |
| [VOACAP GUI](https://github.com/jawatson/pythonprop) | Graphical propagation planner built on voacapl. Run with `voacapgui`. |
| [D-Rats](https://github.com/ham-radio-software/D-Rats) | D-STAR low-speed data communications client. Cloned from GitHub and run from a Python venv. |
| FCC Exam / Ham Exam | US amateur radio licence exam study and practice tools. |
| WWL | Maidenhead grid locator calculator and distance/bearing tool. |

---

### Cluster / Server

| Application | Description |
| --- | --- |
| [DX Spider](http://www.dxcluster.org/) | Perl-based DX cluster node server. Dependencies installed automatically; full node configuration is manual. |

---

### HF Propagation

| Application | Description |
| --- | --- |
| [voacapl](https://github.com/jawatson/voacapl) | VOACAP HF propagation prediction engine. Requires `gfortran`. Data files created by `makeitshfbc` after install. |
| [pythonprop / VOACAP GUI](https://github.com/jawatson/pythonprop) | Python GUI frontend for voacapl with circuit reliability plots. Installed in a dedicated venv. Run with `voacapgui`. |

---

## Changelog

| Version | Date | Notes |
| --- | --- | --- |
| 1.0.2 | 2026-05-15 | Bug fixes: explicit `/tmp/` paths for all downloaded packages, `cd` back after HamClock build, `makeitshfbc` called with full path, VarAC `.desktop` path quoting, `install_all` step counter corrected, GridTracker curl guard added |
| 1.0.1 | 2026-05-15 | OS check restricted to 26.04 / resolute only; corrected fccexam/hamexam availability; FLArq built from fldigi tarball; HamClock switched to community fork; VarAC URL corrected to `/download`; WineHQ resolute repo note added; all link and package checks passing |
| 1.0.0 | 2026-05-14 | Initial release for Ubuntu 26.04 "Resolute Raccoon". Complete desktop menu integration, dynamic version resolution for GridTracker/JS8Call/Pat/ardopcf, 26.04 package name updates |

---

*73 de PA3RPW*
