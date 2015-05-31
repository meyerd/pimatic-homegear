module.exports = {
  title: "homegear config"
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
    localIP:
      description: "Local IP of pimatic installation for RPC connection from Homegear"
      type: "string"
      default: "127.0.0.1"
    localRPCPort:
      description: "Local port for RPC connection from Homegear"
      type: "integer"
      default: 2015
    debug:
      description: "Output update message from homegear and additional infos"
      type: "boolean"
      default: true
}
