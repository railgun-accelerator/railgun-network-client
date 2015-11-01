child_process = require 'child_process'

ip_exec = (commands, force=false, callback)->
  args = ['-batch', '-']
  if force
    args.push '-force'
  child = child_process.spawn 'ip', args, stdio: ['pipe', process.stdout, process.stderr]
  child.on 'close', callback
  child.stdin.end commands.join('\n') + "\n"
iptables_exec = (commands, noflush = false, callback )->
  args = []
  if noflush
    args.push '--noflush'
  child = child_process.execFile 'iptables-restore', args, stdio: ['pipe', process.stdout, process.stderr]
  result = (["*#{table}"].concat(rules, 'COMMIT').join("\n") for table, rules of commands when rules.length > 0).join("\n") + "\n"
  child.on 'close', callback
  child.stdin.end result

module.exports =
  init: (server_id, servers, regions)->

    ip = []
    ipforce = []
    iptables = {nat: [], mangle: [], filter: []}

    ipforce.push "rule del pref 200 fwmark 0x1 lookup 200"
    ipforce.push "rule del pref 400 to #{servers[server_id].network} lookup main"
    ipforce.push "rule del pref 401 tos 4 lookup 100"
    ipforce.push "rule del pref 402 iif lo lookup main"
    ipforce.push "rule del pref 403 to 10.0.0.0/8 lookup 100"

    ip.push "rule add pref 200 fwmark 0x1 lookup 200"
    ip.push "rule add pref 400 to #{servers[server_id].network} lookup main" # 到自己 VPN 内网, 不进行路由
    ip.push "rule add pref 401 tos 4 lookup 100" # 源站选路
    ip.push "rule add pref 402 iif lo lookup main" # 除源站选路外, 本机发出的其他报文, 不进行路由
    ip.push "rule add pref 403 to 10.0.0.0/8 lookup 100" # 转发报文

    ip.push "route replace local default dev lo table 200"
    ip.push "route flush table 100"

    #console.log servers
    for i, server of servers when server.id != server_id
      # 相邻的节点建立 tunnel
      if server.link? and server.link != 'direct'
        ipforce.push "link del railgun#{server.id}"
#        mode = null
#        encap = null
#        sport = null
#        dport = null
        [mode, encap, sport, dport] = server.link.split '-'
        if encap
          if encap == 'gue'
            ipproto='gue'
          else if mode == 'ipip'
            ipproto='ipproto 4'
          else if mode == 'gre'
            ipproto='ipproto 47'
          ipforce.push "fou del port #{dport}"
          ipforce.push "fou add port #{dport} #{ipproto}"
          ip.push "link add railgun#{server.id} type #{mode} remote #{server.public_address} ttl 64 encap #{encap} encap-sport #{sport} encap-dport #{dport}"
        else
          ip.push "link add railgun#{server.id} type #{mode} remote #{server.public_address} ttl 64"

        ip.push "addr add dev railgun#{server.id} #{process.env.RAILGUN_ADDRESS} peer #{server.address}"
        ip.push "link set dev railgun#{server.id} up"

      else if server.next_hop?
        # 为了调试方便, 把不相邻但是可达的节点在 main 做个路由, 这个生产不会使用.
        ip.push "route replace #{server.network} dev railgun#{server.next_hop} src #{servers[server_id].host}"

      # 可达节点的路由
      if server.next_hop?
        ip.push "route replace #{server.network} dev railgun#{server.next_hop} src #{servers[server_id].host} table 100"
        ip.push "route replace tos #{server.tos} default dev railgun#{server.next_hop} src #{servers[server_id].host}" if server.tos?


      # 连接保持
      if server.tos?
        iptables.mangle.push "-A FORWARD -m connmark --mark 0 -m realm --realm #{server.id} -j CONNMARK --set-mark #{server.id}"
        iptables.mangle.push "-A FORWARD -m connmark --mark #{server.id} -j TOS --set-tos #{server.tos}"
        iptables.mangle.push "-A OUTPUT -m connmark --mark 0 -m realm --realm #{server.id} -j CONNMARK --set-mark #{server.id}"
        iptables.mangle.push "-A OUTPUT -m connmark --mark #{server.id} -j TOS --set-tos #{server.tos}"

    for i, region of regions when region.gateway?
      for address in region.addresses
        if region.gateway == server_id
          ip.push "route add #{address} via #{process.env.RAILGUN_GATEWAY} table 100"
        else
          ip.push "route add #{address} advmss 1360 dev railgun#{servers[region.gateway].next_hop} src #{servers[server_id].host} realm #{region.gateway} table 100"

    #console.log ipforce.join("\n")
    #console.log '-'
    ip_exec ipforce, true, (code)->
      console.log code
      #console.log error, stdout, stderr
      #console.log ip.join("\n")
      ip_exec ip, false, (code)->
        #throw error if error
        console.log code
        iptables_exec iptables, true, (code)->
          console.log code
          #throw error if error
          process.exit()
