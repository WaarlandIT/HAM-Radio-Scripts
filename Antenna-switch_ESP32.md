# Remote Antenna switch 

## with ESP32-C3 super-mini

Some time ago I designed a remote antenna switch that uses 5 relays to switch 1 feed line to 5 different antennas. That way I ony have 1 cable running from the radio room to the antenna tower  and be able to use 5 different antennas depending on goal or band. 
To make switching easier I created some Arduino code that gives an interface in a browser to signal the relays. 

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS.png "AS")

As you can see in the diagram of the antenna switch it's easy to use an Arduino board to signal the relays.
You can swap the + and - voltage on the relay so the GND in the diagram get s the +12volt and the relays are switched using an NPN transistor signalled from the ESP32.

To connect the ESP32 to the antenna switch I use some NPN transostors 

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/ASschema.png "ASschema")

## Install the ESP32

I used the Arduino IDE to compile and upload the code to the board. 

After uploading the ESP32 enables a wifi access point (AS) you can connect to without a password. After you are connected browse to http://192.168.4.1

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS01.jpg "AS1")

You can now manage the relays. At the bottom you see a link "Wifi settings", click on that to set your home wifi.

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS02.jpg "AS2")

Select your SSID and set your password, check the static IP box if you want to set that.

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS03.jpg "AS3")

After clicking Save & Connect the ESP32 will restart and connect to your wifi. 
If you set a static IP you can browse to that or you have to check your router to find the ip-address.

## Added a help page in the Webinterface
### Web Interface
Open http://<ip>/ in any browser to access the antenna switch control panel. Click an antenna button to activate it. Only one antenna can be active at a time. Use All OFF to deactivate all outputs.

### Switch Antenna
Switch to a specific antenna via GET request:

GET /?antenna=N
N = antenna number 1–5, or 0 to turn all off.

Examples:

- http://<ip>/?antenna=1   → activate Antenna 1
- http://<ip>/?antenna=3   → activate Antenna 3
- http://<ip>/?antenna=0   → all OFF

JSON response:

{"status":"ok","antenna":1,"name":"Antenna 1"}

### Get Status

Query the currently active antenna:

GET /status

JSON response (antenna active):

{"status":"ok","antenna":2,"name":"Antenna 2","active":true}

JSON response (all off):

{"status":"ok","antenna":0,"name":"off","active":false}

### WiFi Configuration

Open http://<ip>/config to change WiFi settings. DHCP is the default. Enable Use static IP to assign a fixed address.

To reset WiFi config and return to AP mode:

- Hold the BOOT button for 3 seconds at runtime, or
- Hold BOOT while powering on the board


### Access Point Mode

When no WiFi is configured (or connection fails), the board starts its own AP:

SSID: AS01  (open, no password)

Config portal: http://192.168.4.1/config

Antenna control is also available via AP at http://192.168.4.1/

### curl Examples

- curl http://<ip>/?antenna=2
- curl http://<ip>/?antenna=0
- curl http://<ip>/status
