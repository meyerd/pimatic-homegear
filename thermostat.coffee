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
        # @mc = new HomegearConnection(@config.host, @config.port)
        @hmclinet = xmlrpc.CreateClient({host: @config.host, port: @config.port, path: '/'})
        @hmserver = xmlrpc.CreateServer({host: '127.0.0.1', port: 2015})
        @mc.once("connected", =>
          if @config.debug
            env.logger.debug "Connected, waiting for first update from cube"
          @mc.once("update", resolve)
        )
        @mc.once('error', reject)
        return
      ).timeout(60000).catch( (error) ->
        env.logger.error "Error on connecting to max cube: #{error.message}"
        env.logger.debug error.stack
        return
      )
    
      @hmserver.on('NotFound', (method, params) =>
        if @config.debug
          env.logger.debug "NotFound: ", params
      )
      
      @hmserver.on('system.multicall', (method, params, callback) =>
        if @config.debug
          env.logger.debug "system.multicall", params
      )
      
      @hmserver.on('event', (err, params, callback) =>
        if @config.debug
          env.logger.debug "event", params
      )
      
      @hmserver.on('newDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "newDevice", params
      )
      
      @hmserver.on('deleteDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "deleteDevices", params
      )

      #@mc.on('error', (error) =>
      #  env.logger.error "connection error: #{error}"
      #  env.logger.debug error.stack
      #)

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
###
      plugin.mc.on("update", (data) =>
        data = data[@config.rfAddress]
        if data?
          now = new Date().getTime()
###
          ###
          Give the cube some time to handle the changes. If we send new values to the cube
          we set _lastSendTime to the current time. We consider the values as succesfull set, when
          the command was not rejected. But the updates comming from the cube in the next 30
          seconds do not always reflect the updated values, therefore we ignoring the old values
          we got by the update message for 30 seconds. 

          In the case that the cube did not react to our the send commands, the values will be 
          overwritten with the internal state (old ones) of the cube after 30 seconds, because
          the update event is emitted by max-control periodically.
          ###
###
          if now - @_lastSendTime < 30*1000
            # only if values match, we are synced
            if data.setpoint is @_temperatureSetpoint and data.mode is @_mode
              @_setSynced(true)
          else
            # more then 30 seconds passed, set the values anyway
            @_setSetpoint(data.setpoint)
            @_setMode(data.mode)
            @_setSynced(true)
          @_setValve(data.valve)
          @_setBattery(data.battery)
        return
      )
      super()
###

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

###
      plugin.mc.on("update", (data) =>
        data = data[@config.rfAddress]
        if data?.actualTemperature?
          @_temperature = data.actualTemperature
          @emit 'temperature', @_temperature
      )
###

    getTemperature: -> Promise.resolve(@_temperature)

  class HomematicContactSensor extends env.devices.ContactSensor

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_contact = lastState?.contact?.value

###
      plugin.mc.on("update", (data) =>
        data = data[@config.rfAddress]
        if data?
          @_setContact(data.state is 'closed')
        return
      )
      super()
###

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

###
      plugin.mc.on("status", (info) =>
        @emit 'dutycycle', info.dutyCycle
        @emit 'memoryslots', info.memorySlots
      )
      super()
###

    getDutycycle: -> Promise.resolve(@_dutycycle)
    getMemoryslots: -> Promise.resolve(@_memoryslots)

  return plugin

