Pimatic Homegear Plugin
=======================

Plugin to interface with homegear (https://www.homegear.eu).

Based on pimatic-max (https://github.com/pimatic/pimatic-max)
and homematic-manager (https://github.com/hobbyquaker/homematic-manager).

Plugin to control the MAX! Thermostat (http://www.eq-3.de)

Configuration
-------------
You can load the plugin by editing your `config.json` to include (host = Homegear IP port=Homegear Port (default:2001)). The local ip and rpc port are required for the RPC server, to establish a connection from homegear back to pimatic and receive events:

````json
{
   "plugin": "homegear",
   "host": "127.0.0.1",
   "port": 2001,
   "localIP": "127.0.0.1",
   "localRPCPort": 2015
}
````

Use the debug output in pimatic to find out the peerID and channel of the devices.

Thermostats can be defined by adding them to the `devices` section in the config file.
Set the `class` attribute to `HomematicHeatingThermostat`. For example:

```json
{
  "id": "bathroomLeft",
  "class": "HomematicHeatingThermostat",
  "name": "Bathroom Radiator left",
  "peerID": 2,
  "channel": 4,
  "comfyTemp": 23.0,
  "ecoTemp": 17.5,
}
```

Additionally, to see the current room temperature a `HomematicThermostat` with the same peerID and channel has to be added

```json
{
  "id": "temperatureBathroomLeft",
  "class": "HomematicThermostat",
  "name": "Bathroom Temperature Radiator left",
  "peerID": 2,
  "channel": 4,
}
```

