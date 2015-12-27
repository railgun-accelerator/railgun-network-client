pg = require 'pg'

module.exports =
  init: (server_id, database, callback)->
    pg.connect database, (error, client, done) ->
      throw error if error
      client.query 'SELECT *, host(address) as host, network(address) as network FROM servers', (error, result) ->
        throw error if error
        servers = {}
        for row in result.rows
          row.private_address ?= row.public_address
          row.tos = '0x' + row.tos.toString(16) if row.tos?
          servers[row.id] = row
        servers[server_id].next_hop = server_id
        client.query 'SELECT * FROM links WHERE "from" = $1::smallint or "to" = $1::smallint', [server_id], (error, result) ->
          throw error if error
          for row in result.rows
#            row.mode = row.mode.split('-')
#            if row.mode.length > 1
#              row.mode =
#                mode: row.mode[0]
#                encap: row.mode[1]
#                sport: row.mode[2]
#                dport: row.mode[3]
#            else
#              row.mode =
#                mode: row.mode[0]
            if row.from == server_id
              servers[row.to].link = row.mode
              servers[row.to].next_hop = row.to
            else
              servers[row.from].link = row.mode
              servers[row.from].next_hop = row.from
          client.query 'SELECT id FROM regions', (error, result) ->
            throw error if error
            regions = {}
            for row in result.rows
              regions[row.id] = id: row.id, addresses: []
            client.query 'SELECT region_id, address FROM addresses', (error, result) ->
              throw error if error
              for row in result.rows
                regions[row.region_id].addresses.push row.address
              reachable_servers = (server.id for i, server of servers when server.link?)
              reachable_servers.push server_id
              client.query 'SELECT DISTINCT ON (region_id) region_id, server_id FROM gateways WHERE server_id = ANY($1::smallint[]) ORDER BY region_id, server_id = $2::smallint DESC, delay', [reachable_servers, server_id], (error, result) ->
                throw error if error
                for row in result.rows
                  regions[row.region_id].gateway = row.server_id

                # temp hack before railgun-network protocol
                switch server_id
                  when 2, 8
                    servers[21].next_hop = 20
                    servers[22].next_hop = 20
                    servers[23].next_hop = 20
                    regions[0].gateway = 21
                    regions[1].gateway = 23
                  when 1, 9
                    servers[20].next_hop = 8
                    servers[21].next_hop = 8
                    servers[22].next_hop = 8
                    servers[23].next_hop = 8
                done()
                callback servers, regions
