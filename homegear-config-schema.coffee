module.exports = {
  title: "homegear-thermostat config"
  type: "object"
  properties:
    host:
      description: "IP of homegear"
      type: "string"
      default: "127.0.0.1"
    port:
      description: "Homegear port (Default: 2001)"
      type: "integer"
      default: 2001
    debug:
      description: "Output update message from homegear and additional infos"
      type: "boolean"
      default: true
}
