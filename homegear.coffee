module.exports = (env) ->

  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  # MaxCubeConnection = require 'max-control'
  xmlrpc = require 'homematic-xmlrpc'
  # Promise.promisifyAll(MaxCubeConnection.prototype)
  M = env.matcher
  settled = (promise) -> Promise.settle([promise])

  class Homematic extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      # Promise that is resolved when the connection is established
      ###
      @_lastAction = new Promise( (resolve, reject) =>

	      resolve null
        return
      ).timeout(60000).catch( (error) ->
        env.logger.error "Error on connecting to homegear: #{error.message}"
        env.logger.debug error.stack
        return
      )
      ###
      # TODO: there has to be a trigger when pimatic is running instead of timeout
      @hmserver = xmlrpc.createServer({host: '0.0.0.0', port: 2015})
      @hmclient = xmlrpc.createClient({host: @config.host, port: @config.port, path: '/'})

      delay = (time, fn, args...) ->
        setTimeout fn, time, args...

      setTimeout ((client, config) -> client.methodCall('init',
                                                        ['http://' + config.localIP + ':' + config.localRPCPort, 'pimatic-homegear', 5],
                                                        (err, result) =>
                                                          if err
                                                            env.logger.error "error calling init on homegear " + err
                                                          if config.debug
                                                            env.logger.debug "called init function to homegear successfully " + result
	      )
      ), 20000, @hmclient, @config
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
          env.logger.debug "homegear called unimplemented function", method, "with params", params
      )

      ###
      @hmserver.on('system.listMethods', (err, params, callback) =>
        if @config.debug
          env.logger.debug "homegear called system.listMethods", params
        callback(null, ['error', 'event', 'listDevices'])
      )
      ###

      @hmserver.on('system.multicall', (err, ps, callback) =>
        results = []
        for mp in ps
          do (mp, @config, results, @hmserver) ->
            for mpp in mp
              do (mpp, @config, results, @hmserver) ->
                # env.logger.debug "mpp:", mpp
                methodName = mpp.methodName
                params = mpp.params
                if @config.debug
                  env.logger.debug "homegear multicalled", methodName, params
                @hmserver.emit(methodName, err, params, (err1, value) =>
                  if err1
                    env.logger.error "error multicalling", methodName
                    env.logger.debug err1.stack
                  results.push(value)
                )
        callback(null, results);
      )

      @hmserver.on('listDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "homegear called listDevices", params
        callback(null, []);
      )

      @hmserver.on('event', (err, params, callback) =>
        if @config.debug
          env.logger.debug "homegear called event" + params
        callback(null, '')
      )

      @hmserver.on('newDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "homegear called newDevices " + params
        callback(null, '')
      )

      @hmserver.on('deleteDevices', (err, params, callback) =>
        if @config.debug
          env.logger.debug "deleteDevices " + params
        callback(null, '')
      )

      deviceConfigDef = require("./device-config-schema")
      @framework.deviceManager.registerDeviceClass("HomematicHeatingThermostat", {
        configDef: deviceConfigDef.HomematicHeatingThermostat,
        createCallback: (config, lastState) -> new HomematicHeatingThermostat(config, lastState)
      })

      @framework.deviceManager.registerDeviceClass("HomematicThermostat", {
        configDef: deviceConfigDef.HomematicThermostat,
        createCallback: (config, lastState) -> new HomematicThermostat(config, lastState)
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


  plugin = new Homematic

  class HomematicHeatingThermostat extends env.devices.HeatingThermostat
    ###
    attributes:
      temperature:
        description: "Actual measured temperature"
        type: "number"
        unit: "°C"
      boost:
        description: "Boost state"
        type: "number"
        unit: "min"
      faultReporting:
        description: "Thermostat is reporting a fault"
        type: "string"
        enum: ["no fault", "valve tight", "adjusting range too large",
               "adjusting range too large", "communication error",
               "-", "low battery", "valve error position"]
      partyStartTime:
        description: "Party start time"
        type: "number"

    _temperature: 0
    _boost: 0
    _faultReporting: 0
    _partyStartTime: 0

    getTemperature: -> Promise.resolve(@_temperature)
    getBoost: -> Promise.resolve(@_boost)
    getFaultReporting: -> Promise.resolve(@_faultReporting)
    getPartyStartTime: -> Promise.resolve(@_partyStartTime)
    ###

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperatureSetpoint = lastState?.temperatureSetpoint?.value
      @_mode = lastState?.mode?.value or 1
      @_battery = lastState?.battery?.value or 0.0
      ###
      @_temperature = lastState?.temperature?.value or 0.0
      @_boost = lastState?.boost?.value or 0
      @_faultReporting = lastState?.faultReporting?.value or 0
      @_partyStartTime = lastState?.partyStartTime?.value or 0
      ###
      @_valve = lastState?.valve?.value or 0
      @_lastSendTime = 0

      plugin.hmserver.on('event', (err, params, callback) =>
        env.logger.debug "HomematicHeatingThermostat event called", params
        [interfaceID, peerID, channel, parameterName, value] = params
        if peerID is @config.peerID and channel is @config.channel
          #env.logger.debug "HomematicHeatingThermostat parameter", parameterName, "value", value
          now = new Date().getTime()

          switch parameterName
            when 'ACTUAL_TEMPERATURE' then
            #  @_setTemperature(value)
            when 'BATTERY_STATE'
              # TODO: fix this to support voltages
              if value < 1.7
                @_setBattery("low")
              else
                @_setBattery("ok")
            when 'BOOST_STATE' then
            #    @_setBoost(value)
            when 'CONTROL_MODE'
              if value == 0
                @_setMode("auto")
              else if value == 1
                @_setMode("manu")
              else if value == 2
                # party mode
                env.logger.debug "HomematicHeatingThermostat party mode received"
              else if value == 3
                @_setMode("boost")
            when 'FAULT_REPORTING'
              if value == 6
                @_setBattery("low")
            #  if value == 1
            #    @_setFaultReporting("no fault")
            #  else if value == 2
            #    @_setFaultReporting("valve tight")
            #  else if value == 3
            #    @_setFaultReporting("adjusting range too large")
            #  else if value == 4
            #    @_setFaultReporting("adjusting range too small")
            #  else if value == 5
            #    @_setFaultReporting("communication error")
            #  else if value == 6
            #    @_setBattery("low")
            #    @_setFaultReporting("low battery")
            #  else if value == 7
            #    @_setFaultReporting("valve error position")
            when 'PARTY_START_TIME' then
            #  @_setPartyStartTime(value)
            when 'SET_TEMPERATURE'
              @_setSetpoint(value)
            when 'VALVE_STATE'
              #env.logger.debug "HomematicHeatingThermostat valve state", value
              @_setValve(value)
            else
              env.logger.error "HomematicHeatingThermostat unknown parameterName", parameterName
          @_setSynced(true)
        return
      )
      super()

    ###
    _setTemperature: (temperature) ->
      if temperature is @_temperature then return
      @_temperature = temperature
      @emit "temperature", @_temperature

    _setBoost: (boost) ->
      if boost is @_boost then return
      @_boost = boost
      @emit "boost", @_boost

    _setFaultReporting: (faultReporting) ->
      if faultReporting is @_faultReporting then return
      @_faultReporting = faultReporting
      @emit "faultReporting", @_faultReporting

    _setPartyStartTime: (partyStartTime) ->
      if partyStartTime is @_partyStartTime then return
      @_partyStartTime = partyStartTime
      @emit "partyStartTime", @_partyStartTime
    ###

    changeModeTo: (mode) ->
      temp = @_temperatureSetpoint
      if mode is "auto"
        temp = null
      return plugin.setTemperatureSetpoint(@config.rfAddress, mode, temp).then( =>
        @_lastSendTime = new Date().getTime()
        #@_setSynced(false)
        @_setMode(mode)
      )

    changeTemperatureTo: (temperatureSetpoint) ->
      if @temperatureSetpoint is temperatureSetpoint then return
      return plugin.setTemperatureSetpoint(@config.rfAddress, @_mode, temperatureSetpoint).then( =>
        @_lastSendTime = new Date().getTime()
        #@_setSynced(false)
        @_setSetpoint(temperatureSetpoint)
      )

  class HomematicThermostat extends env.devices.TemperatureSensor
    _temperature: null

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_temperature = lastState?.temperature?.value
      super()

      plugin.hmserver.on('event', (err, params, callback) =>
        env.logger.debug "HomematicHeatingThermostat event called", params
        [interfaceID, peerID, channel, parameterName, value] = params
        if peerID is @config.peerID and channel is @config.channel
          if parameterName == 'ACTUAL_TEMPERATURE'
            @_temperature = value
            @emit 'temperature', @_temperature
      )

    getTemperature: -> Promise.resolve(@_temperature)

  class Homegear extends env.devices.Sensor

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      super()

  return plugin

