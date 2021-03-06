db = require './db'
protocol = require './protocol'
route = require './route'

server_id = parseInt process.env.RAILGUN_ID
db.init server_id, process.env.RAILGUN_DATABASE, (servers, regions)->
  console.log "loaded #{Object.keys(servers).length} servers and #{Object.keys(regions).length} regions"
  route.init server_id, servers, regions, ->
    protocol.init server_id, servers, regions, route.update
