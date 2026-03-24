# Remote Antenna switch 

## with ESP32-C3 super-mini

Some time ago I designed a remote antenna switch that uses 5 relays to switch 1 feed line to 5 different antennas. That way I ony have 1 cable running from the radio room to the antenna tower  and be able to use 5 different antennas depending on goal or band. 
To make switching easier I created some Arduino code that gives an interface in a browser to signal the relays. 

![alt text](https://github.com/WaarlandIT/HAM-Radio-Scripts/blob/main/images/AS.png "AS")
As you can see in the diagram of the antenna switch it's easy to use an Arduino board to signal the relays.
You can swap the + and - voltage on the relay so the GND in the diagram get s the +12volt and the relays are switched using an NPN transistor signalled from the ESP32.


