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

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS01.jpg | width=100 "AS1")

You can now manage the relays. At the bottom you see a link "Wifi settings", click on that to set your home wifi.

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS02.jpg "AS2")

Select your SSID and set your password, check the static IP box if you want to set that.

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS03.jpg "AS3")

After clicking Save & Connect the ESP32 will restart and connect to your wifi. 
If you set a static IP you can browse to that or you have to check your router to find the ip-address.
