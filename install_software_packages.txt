The bash script installs a large number of HAM-Radio related software packages. The script is created only to work on Xubuntu/Ubuntu 24.04 on Intel/AMD x86_64 CPU architecture.

Download the script using wget:
`wget https://raw.githubusercontent.com/WaarlandIT/HAM-Radio-Scripts/refs/heads/main/install_software_packages.sh`

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


Answer **Yes** by moving the cursor with the arrow keys on your keyboard and hit enter. 

Again after some time you get a config file in an editor where you can enter your callsign between the quotes and some other details, you can also do this later.

Close the editor by clicking **CTRL-X** and when you made some changes you need to answer with a **Y** and **Enter** to continue.

When all is done wyou see this:
```
[INFO] All installations complete!

[INFO] Installation process completed. Check messages above for any failures.
Press Enter to exit...
[INFO] Installation complete!
```
When you press **Enter** you see the following nots:
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

The installation is now complete and it is now time to explore all the software in the menu of your desktop. 
