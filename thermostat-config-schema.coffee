module.exports = {
  title: "homegear-thermostat config"
  type: "object"
  properties:
    host:
      description: "IP of homegear"
      type: "string"
      default: "127.0.0.1"
    port:
      description: "Homegear port (Default: 2000)"
      type: "integer"
      default: 62910
    debug:
      description: "Output update message from homegear and additional infos"
      type: "boolean"
      default: true
}
