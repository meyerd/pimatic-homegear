module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  # MaxCubeConnection = require 'max-control'
  xmlrpc = require 'homematic-xmlrpc'
  # Promise.promisifyAll(MaxCubeConnection.prototype)
  M = env.matcher
  settled = (promise) -> Promise.settle([promise])

  class HomematicThermostat extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # Promise that is resolved when the connection is established
      @_lastAction = new Promise( (resolve, reject) =>
        @hmserver = xmlrpc.createServer({host: '0.0.0.0', port: 2015})
        @hmclient = xmlrpc.createClient({host: @config.host, port: @config.port, path: '/'})
        @hmclient.methodCall('init', ['http://' + '192.168.0.196' + ':' + '2015', 'pimatic-homegear', 5], (err, result) =>
          if err
            env.logger.error "error calling init on homegear " + err
          if @config.debug
            env.logger.debug "called init function to homegear successfully " + result
        )
      ).timeout(60000).catch( (error) ->
        env.logger.error "Error on connecting to homegear: #{error.message}"
        env.logger.debug error.stack
        return
      )
      # @mc.once("connected", =>
      #    if @config.debug
      #      env.logger.debug "Connected, waiting for first update from cube"
      #    @mc.once("update", resolve)
      #  )
      #  @mc.once('error', reject)
      #  return
      #)

      @hmserver.on('error', (method, params) =>
        if @config.debug
          env.logger.debug "homegear error " + params
      )

      @hmserver.on('NotFound', (method, params) =>
        if @config.debug
          env.logger.debug "called NotFound", params
      )

      @hmserver.on('event', (err, params, callback) =>
        if @config.debug
          env.logger.debug "event " + params
      )

      @hmserver.on('newDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "newDevice " + params
      )

      @hmserver.on('deleteDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "deleteDevices " + params
      )

      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("HomematicHeatingThermostat", {
        configDef: deviceConfigDef.HomematicHeatingThermostat,
        createCallback: (config, lastState) -> new HomematicHeatingThermostat(config, lastState)
      })

      @framework.deviceManager.registerDeviceClass("HomematicWallThermostat", {
        configDef: deviceConfigDef.HomematicWallThermostat,
        createCallback: (config, lastState) -> new HomematicWallThermostat(config, lastState)
      })

      @framework.deviceManager.registerDeviceClass("HomematicContactSensor", {
        configDef: deviceConfigDef.HomematicContactSensor,
        createCallback: (config, lastState) -> new HomematicContactSensor(config, lastState)
      })

      @framework.deviceManager.registerDeviceClass("Homegear", {
        configDef: deviceConfigDef.Homegear,
        createCallback: (config, lastState) -> new Homegear(config, lastState)
      })

    setTemperatureSetpoint: (rfAddress, mode, value) ->
      @_lastAction = settled(@_lastAction).then( =>
        if @config.debug
          env.logger.debug "setTemperatureSetpoint", rfAddress, mode, value
        #@mc.setTemperatureAsync(rfAddress, mode, value)
      )
      return @_lastAction


  plugin = new HomematicThermostat

  class HomematicHeatingThermostat extends env.devices.HeatingThermostat

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperatureSetpoint = lastState?.temperatureSetpoint?.value
      @_mode = lastState?.mode?.value or "auto"
      @_battery = lastState?.battery?.value or "ok"
      @_lastSendTime = 0

    changeModeTo: (mode) ->
      temp = @_temperatureSetpoint
      if mode is "auto"
        temp = null
      return plugin.setTemperatureSetpoint(@config.rfAddress, mode, temp).then( =>
        @_lastSendTime = new Date().getTime()
        @_setSynced(false)
        @_setMode(mode)
      )

    changeTemperatureTo: (temperatureSetpoint) ->
      if @temperatureSetpoint is temperatureSetpoint then return
      return plugin.setTemperatureSetpoint(@config.rfAddress, @_mode, temperatureSetpoint).then( =>
        @_lastSendTime = new Date().getTime()
        @_setSynced(false)
        @_setSetpoint(temperatureSetpoint)
      )

  class HomematicWallThermostat extends env.devices.TemperatureSensor
    _temperature: null

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperature = lastState?.temperature?.value
      super()

    getTemperature: -> Promise.resolve(@_temperature)

  class HomematicContactSensor extends env.devices.ContactSensor

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_contact = lastState?.contact?.value

  class Homegear extends env.devices.Sensor

    attributes:
      dutycycle:
        description: "Percentage of max rf limit reached"
        type: "number"
        unit: "%"
      memoryslots:
        description: "Available memory slots for commands"
        type: "number"

    _dutycycle: 0
    _memoryslots: 50

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_dutycycle = plugin.mc.dutyCycle
      @_memoryslots = plugin.mc.memorySlots

    getDutycycle: -> Promise.resolve(@_dutycycle)
    getMemoryslots: -> Promise.resolve(@_memoryslots)

  return plugin

