Pimatic Homematic Plugin
========================

Plugin to interface with homegear (https://www.homegear.eu).

Based on pimatic-max (https://github.com/pimatic/pimatic-max)
and homematic-manager (https://github.com/hobbyquaker/homematic-manager).

Plugin to control the MAX! Thermostat (http://www.eq-3.de)

Configuration
-------------
You can load the plugin by editing your `config.json` to include (host = Homegear IP port=Homegear Port (default:2001)):

````json
{
   "plugin": "homegear",
   "host": "192.168.X.X",
   "port": 2001
}
````

Use the debug output in pimatic to find out the rfAddress of the devices. Sample debug output:

````
09:04:42.165 [pimatic-homegear] got update
09:04:42.168 [pimatic-homegear] { type: 'Heating Thermostat',
09:04:42.168 [pimatic-homegear]>  address: '12345cf', <-- rfAddress
09:04:42.168 [pimatic-homegear]>  serial: 'KEQ04116',
09:04:42.168 [pimatic-homegear]>  name: 'Heizung',
09:04:42.168 [pimatic-homegear]>  roomId: 1,
09:04:42.168 [pimatic-homegear]>  comfortTemperature: 23,
09:04:42.168 [pimatic-homegear]>  ecoTemperature: 16.5,
09:04:42.168 [pimatic-homegear]>  maxTemperature: 30.5,
09:04:42.168 [pimatic-homegear]>  minTemperature: 4.5,
09:04:42.168 [pimatic-homegear]>  temperatureOffset: 3.5,
09:04:42.168 [pimatic-homegear]>  windowOpenTemperature: 12,
09:04:42.168 [pimatic-homegear]>  valve: 0,
09:04:42.168 [pimatic-homegear]>  setpoint: 17,
09:04:42.168 [pimatic-homegear]>  battery: 'ok',
09:04:42.168 [pimatic-homegear]>  mode: 'manu' }
````

Thermostats can be defined by adding them to the `devices` section in the config file.
Set the `class` attribute to `HomematicHeatingThermostat`. For example:

```json
{
  "id": "bathroomLeft",
  "class": "HomematicHeatingThermostat",
  "name": "Bathroom Radiator left",
  "rfAddress": "12345cf",
  "comfyTemp": 23.0,
  "ecoTemp": 17.5,
}
```

For contact sensors add this config:

```json
{
  "id": "window-bathroom",
  "class": "HomematicContactSensor",
  "name": "Bathroom Window",
  "rfAddress": "12345df"
}
```
