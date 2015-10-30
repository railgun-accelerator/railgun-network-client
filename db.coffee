pg = require 'pg'

module.exports =
  init: (server_id, database)->
    pg.connect database, (error, client, done) ->
      throw error if error
      client.query 'SELECT * from servers', (error, result) ->
        throw error if error
        servers = {}
        for row in result.rows
          servers[row.id] = row
        client.query 'SELECT * from links where from = $1::int or to = $1::int', [server_id], (error, result) ->
          throw error if error
          for row in result.rows
            if row.from == server_id
              servers[row.to].link = row
            else
              servers[row.from].link = row
          client.query 'SELECT id FROM regions', (error, result) ->
            throw error if error
            regions = {}
            for row in result.rows
              regions[row.id] = addresses: []
            client.query 'SELECT region_id, address FROM addresses', (error, result) ->
              throw error if error
              for row in result.rows
                regions[row.region_id].addresses.push row.address
              reachable_servers = (server.id for server in servers when server.link?)
              reachable_servers.push server_id
              client.query 'SELECT DISTINCT ON (region_id) region_id, server_id FROM gateways WHERE server_id in $1 ORDER BY delay', [reachable_servers], (error, result) ->
                throw error if error
                for row in result.rows
                  regions[row.region_id].gateway = row.server_id
              done()
              callback servers, regions