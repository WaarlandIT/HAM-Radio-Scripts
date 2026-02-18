## The bash script installs a large number of HAM-Radio related software packages. 

#### The script is created only to work on Xubuntu/Ubuntu 24.04 on Intel/AMD x86_64 CPU architecture.

## Requirements

- Ubuntu 24.04 LTS (Noble Numbat)
- Regular user account with `sudo` privileges
- Internet connection

Download the script using wget:
```
wget https://raw.githubusercontent.com/WaarlandIT/HAM-Radio-Scripts/refs/heads/main/install_software_packages.sh
```

Give the script execute rights:
`chmod +x install_software_packages.sh`

And run it:
`./install_software_packages.sh`

The script asks for some information:
```
Enter your ham radio callsign:
Enter your handle/name:
Enter your grid square (e.g., FN20):
```
This information will be used in default configuration wherever it is possible to insert. 
Next you get a list of options:
```
================================================
   Ham Radio Software Installer - Ubuntu 24.04
================================================
Callsign: PA3RPW | Grid: JO22
================================================

1.  Install ALL packages (recommended for first-time setup)
2.  System preparation & core utilities
3.  Digital modes (WSJT-X, JS8Call, FLDigi suite)
4.  APRS applications (Xastir, Direwolf, YAAC)
5.  Logging applications (CQRLOG, KLog, TrustedQSL)
6.  SDR applications (GQRX, CubicSDR, SDRAngel)
7.  Morse code applications
8.  Antenna modeling (NEC2, Yagiuda)
9.  Winlink (Pat Winlink with ARDOP)
10. Satellite tracking (Gpredict, Predict)
11. General ham radio utilities
12. Install HamClock
13. Install DX Spider Cluster server

0.  Exit

Enter your choice [0-13]:
```
I choose **1** to install all packages.

The installer starts, all packes will be installed from the default repository, the developer's website or even compiled from source. 
That can take a while depending on how fast your computer is etc. **Don't lose the internet connection and your computer must be active all the time.**

After some time you get a pop-up question about AX25, that is used for packet radio 

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/ax25.png "AX25")

Answer **Yes** by moving the cursor with the arrow keys on your keyboard and hit enter. 

Again after some time you get a config file in an editor where you can enter your callsign between the quotes and some other details, you can also do this later.

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/winlink.png "Winlink")

Close the editor by clicking **CTRL-X** and when you made some changes you need to answer with a **Y** and **Enter** to continue.

When all is done wyou see this:
```
[INFO] All installations complete!

[INFO] Installation process completed. Check messages above for any failures.
Press Enter to exit...
[INFO] Installation complete!
```
When you press **Enter** you see the following notes:
```
================================================
  Post-Installation Notes
================================================

1. Some applications may require logout/login for group permissions
2. Configure applications with your callsign: PA3RPW
3. Your grid square: JO22
4. RTL-SDR users: Blacklist DVB-T drivers if needed:
   echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf
5. For WSJT-X: Run 'wsjtx' and configure your station details
6. For Pat Winlink: Edit ~/.config/pat/config.json with your info
7. For GridTracker: Launch from applications menu or run 'gridtracker'
8. Check ~/hamradio/ for additional installed applications

```


## Post-Installation

- Log out and back in after installation for USB and serial port group permissions to take effect
- VarAC requires a manual ZIP download from [varac-hamradio.com](https://www.varac-hamradio.com/downloadlinux) — use menu option 14
- SDRPlay RSP users: download drivers from [sdrplay.com/downloads](https://www.sdrplay.com/downloads/)
- RTL-SDR users may need to blacklist the DVB-T kernel module:
  ```bash
  echo 'blacklist dvb_usb_rtl28xxu' | sudo tee /etc/modprobe.d/blacklist-rtl.conf
  ```



The installation is now complete and it is now time to explore all the software in the menu of your desktop. 

All applications are registered under a **Ham Radio** submenu in your desktop applications menu.

---

## Installed Software

### Digital Modes

| Application | Description |
|---|---|
| [WSJT-X](https://wsjt.sourceforge.io/) | Weak-signal digital modes: FT8, FT4, JT65, WSPR, and more. The standard for HF DX and contest operating. |
| [JTDX](https://www.jtdx.tech/) | Alternative WSJT-X fork with additional decoding improvements for FT8/JT65. |
| [JS8Call](https://js8call.com/) | Keyboard-to-keyboard messaging using the JS8 mode — a conversational variant of FT8. |
| [GridTracker](https://gridtracker.org/) | Real-time map and grid square overlay for WSJT-X and JS8Call traffic. |
| [FLDigi](http://www.w1hkj.com/) | Multi-mode software modem supporting PSK31, RTTY, CW, Olivia, SSTV, and many others. |
| [FLRig](http://www.w1hkj.com/) | CAT rig control front-end that integrates with FLDigi and other logging software. |
| [FLMsg](http://www.w1hkj.com/) | Structured message forms for ICS/FEMA traffic handling over FLDigi. |
| [FLAmp](http://www.w1hkj.com/) | Multi-station ARQ file transfer using the AMP protocol over FLDigi. |
| [FLArq](http://www.w1hkj.com/) | ARQ automatic repeat-request file transfer for FLDigi. |
| [QSSTV](https://charlesreid1.com/wiki/QSSTV) | Slow-scan television (SSTV) and HAMDRM digital image transmission. |
| [XLog](https://www.nongnu.org/xlog/) | Lightweight QSO logger that integrates with FLDigi for on-air logging. |

---

### Logging

| Application | Description |
|---|---|
| [CQRLOG](https://www.cqrlog.com/) | Full-featured DX and contest logger with cluster spotting, LoTW upload, and online lookups. |
| [KLog](https://www.klog.xyz/) | Cross-platform QSO logger with ADIF support and award tracking. |
| [TrustedQSL](https://lotw.arrl.org/lotw-help/installation/) | ARRL Logbook of the World (LoTW) client for digitally signing and submitting QSOs. |
| [PyQSO](https://github.com/ctjacobs/pyqso) | Lightweight Python/GTK QSO logging application with ADIF import/export. |
| [TLF](https://tlf.sourceforge.net/) | Ncurses-based contest logger popular for CW and phone contests. |

---

### SDR (Software Defined Radio)

| Application | Description |
|---|---|
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
|---|---|
| [Xastir](https://xastir.org/) | Feature-rich APRS mapping client with support for TNC, internet, and audio interfaces. |
| [Direwolf](https://github.com/wb2osz/direwolf) | Software TNC and APRS decoder/encoder. Supports AFSK, KISS, AGW, and iGate operation. |
| [APRx](https://github.com/OH2MQK/aprx) | Lightweight APRS iGate and digipeater daemon. |
| [APRS Digi](https://github.com/n1vux/aprsdigi) | Standalone AX.25/APRS digipeater. |

---

### Satellite

| Application | Description |
|---|---|
| [Gpredict](https://gpredict.oz9aec.net/) | Real-time satellite tracking with Doppler correction control for rigs and rotators. |

---

### Winlink

| Application | Description |
|---|---|
| [Pat](https://getpat.io/) | Winlink email-over-radio client supporting ARDOP, Vara, Pactor, and packet. |
| [ardopcf](https://github.com/pflarue/ardop) | ARDOP (Amateur Radio Digital Open Protocol) TNC for HF Winlink connections. Installed from binary or built from source. |
| AX.25 tools | Linux AX.25 stack utilities (`ax25-tools`, `ax25-apps`) for packet radio. |

---

### Antenna Modeling

| Application | Description |
|---|---|
| [NEC2C](https://www.nec2.org/) | Numerical Electromagnetics Code antenna modeling engine, compiled for Linux. |
| [xNEC2C](https://www.xnec2c.org/) | GTK graphical front-end for NEC2C with real-time pattern visualisation. |
| [YagiUDA](https://www.vk5dj.com/yagi.html) | Command-line Yagi-Uda antenna design and optimisation tool. |

---

### Morse Code

| Application | Description |
|---|---|
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

### Winlink / Chat

| Application | Description |
|---|---|
| [VarAC](https://www.varac-hamradio.com/) | Chat and file transfer over the VARA HF/FM modem. Runs under Wine. Requires manual ZIP download from the VarAC website. |

---

### Utilities

| Application | Description |
|---|---|
| [HamClock](https://www.clearskyinstitute.com/ham/HamClock/) | Clock, solar conditions, propagation bands, and DX spots display. Built from source. |
| [CHIRP](https://chirp.danplanet.com/) | Cross-platform radio memory programmer supporting hundreds of VHF/UHF transceivers. |
| [FreeDV](https://freedv.org/) | Open-source digital voice mode for HF, using codec2 for narrow-bandwidth SSB. |
| [XDX](https://www.dxwatch.com/) | DX cluster telnet client for spotting and call lookups. |
| [SPLAT!](https://www.qsl.net/kd2bd/splat.html) | RF terrain analysis and path-loss prediction tool using SRTM elevation data. |
| [HamLib](https://hamlib.github.io/) | `rigctl` / `rotctl` — command-line rig and rotator control utilities. |
| GPSd | GPS daemon with client tools for position-aware applications. |
| [voacapl](https://github.com/jawatson/voacapl) | VOACAP HF propagation prediction engine, built from source. |
| [VOACAP GUI](https://github.com/jawatson/pythonprop) | Graphical propagation planner and circuit reliability plotter built on voacapl. Run with `voacapgui`. |
| [D-Rats](https://github.com/ham-radio-software/D-Rats) | D-STAR low-speed data communications client for messaging and file transfer. Cloned and run from source. |
| FCC Exam / Ham Exam | US amateur radio licence exam study and practice tools. |
| WWL | Maidenhead grid locator calculator and distance/bearing tool. |

---

### Cluster / Server

| Application | Description |
|---|---|
| [DX Spider](http://www.dxcluster.org/) | Perl-based DX cluster node server. Dependencies are installed automatically; full node configuration is manual. |

---

*73 de PA3RPW*

