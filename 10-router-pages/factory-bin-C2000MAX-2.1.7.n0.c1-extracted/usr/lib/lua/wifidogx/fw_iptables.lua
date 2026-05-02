--
-- Copyright (C) Spyderj
--

local log = require 'mylog'
local tasklet = require 'tasklet.util'
local nixio = require 'nixio'
local string, os, table = string, os, table
local tonumber = tonumber
local fw_start = false
local CHAIN_OUTGOING = 'wifidog_outgoing'
local CHAIN_OUTGOING2 = 'wifidog_outgoing2'
local CHAIN_OUTGOING_SKIP = 'wifidog_outgoing_skip'
local CHAIN_TO_INTERNET = 'wifidog_2internet'
local CHAIN_INCOMING = 'wifidog_incoming'
local CHAIN_SERVERS = 'wifidog_servers'
local CHAIN_GLOBAL = 'wifidog_global'
local CHAIN_KNOWN = 'wifidog_known'
local CHAIN_UNKNOWN = 'wifidog_unknown'
local CHAIN_LOCKED  = 'wifidog_locked'
local CHAIN_TRUSTED = 'wifidog_trusted'
local conf_data = require 'wifidogx.conf'
local MARK_NONE = '0x0/0x7'
local MARK_KNOWN = '0x1'
local MARK_LOCKED = '0x2'

local servers = {}
local green_ip = {}
local authed_mac = {}
local white_mac = {}
local black_mac = {}
local tmpbuf = tmpbuf
local func_skip = false
local fw = {}

local function execute(cmd,max,every_sleeptime)
	local fail = 1
	while true do
		local pid = os.fork()
		if pid == 0 then
			os.close(2)
			os.execl('/bin/sh', '/bin/sh', '-c', cmd)
			os.exit(1)
		end
		
		local _, status = os.waitpid(pid)
		if os.WEXITSTATUS(status) == 0 then
			log.info('executed: ', cmd)
			return true
		else
			log.error('execution failed: ', cmd,",failed times:",fail)
			if not max or fail >= max then 
				return false
			else
				fail = fail + 1
				if every_sleeptime then
					nixio.nanosleep(every_sleeptime)
				else
					nixio.nanosleep(0,250000000)
				end
				
			end
		end
	end
end

local function iptables_longdo_command(...)
	execute(tmpbuf:rewind():putstr('iptables ', ...):str(),4,3)
	execute(tmpbuf:rewind():putstr('ip6tables ', ...):str(),4,3)
end

local function iptables_do_command(...)
	execute(tmpbuf:rewind():putstr('iptables ', ...):str(),3)
	execute(tmpbuf:rewind():putstr('ip6tables ', ...):str(),3)
end

local function iptables_do_command_once(...)
	execute(tmpbuf:rewind():putstr('iptables ', ...):str())
	execute(tmpbuf:rewind():putstr('ip6tables ', ...):str())
end

local function iptables_do4_command(...)
	execute(tmpbuf:rewind():putstr('iptables ', ...):str(),3)
end
local function iptables_do4_command_once(...)
	execute(tmpbuf:rewind():putstr('iptables ', ...):str())
end
local function iptables_do6_command(...)
	execute(tmpbuf:rewind():putstr('ip6tables ', ...):str(),3)
end
local function iptables_do6_command_once(...)
	execute(tmpbuf:rewind():putstr('ip6tables ', ...):str())
end
local action_modes = {
	block = 'REJECT',
	drop = 'DROP',
	allow = 'ACCEPT',
	log = 'LOG',
	ulog = 'ULOG',
}

local function iptables_do_rule(table, chain, rules, idx)
	local action, protocol, port, mask = rules[idx], rules[idx + 1], rules[idx + 2], rules[idx + 3]
	
	tmpbuf:rewind():putstr('iptables -t ', table, ' -A ', chain)
	if mask then
		tmpbuf:putstr(' -d ', mask)
	end
	if protocol then
		tmpbuf:putstr(' -p ', protocol)
	end
	if port then
		tmpbuf:putstr(' --dport ', port)
	end
	tmpbuf:putstr(' -j ', action_modes[action])
	
	execute(tmpbuf:str(),3)
end

local function iptables_load_ruleset(conf, table, setname, chain)
	local rules = conf.rulesets[setname]
	if rules then
		local len = #rules
		local idx = 1
		while idx <= len do 
			iptables_do_rule(table, chain, rules, idx)
			idx = idx + 4
		end
	end
end

function fw.clean_outgoing()
	authed_mac = { }
	iptables_do_command('-t mangle -F ', CHAIN_OUTGOING)
end

function fw.allow_skip()
	if not func_skip then
		func_skip = true
		iptables_longdo_command('-t mangle -I ', CHAIN_OUTGOING_SKIP,' -i ',conf_data.gw_interface,  ' -j MARK --set-mark 1')
	end
end

function fw.deny_skip()
	if func_skip then
		func_skip = false
		iptables_longdo_command('-t mangle -F ', CHAIN_OUTGOING_SKIP)
	end
end

function fw.allow(client)
	local mac = client.mac
	if not authed_mac[mac] then
		iptables_longdo_command(string.format('-t mangle -A %s -m mac --mac-source %s -j MARK --set-mark %s', 
				CHAIN_OUTGOING, client.mac, MARK_KNOWN))
				
	
		authed_mac[mac] = true
	end
end

function fw.deny(client)
	local mac = client.mac
	if authed_mac[mac] then
		iptables_longdo_command(string.format('-t mangle -D %s -m mac --mac-source %s -j MARK --set-mark %s', 
			CHAIN_OUTGOING,mac, MARK_KNOWN))
			
		
		authed_mac[mac] = nil
	end
end

function fw.update_white_maclist(action, maclist)
	if action == '=' then
		iptables_do_command('-t mangle -F ', CHAIN_TRUSTED)
		white_mac = {}
		for _, mac in pairs(maclist) do 
			iptables_do_command(string.format(
				'-t mangle -A %s -m mac --mac-source %s -j MARK --set-mark %s', 
				CHAIN_TRUSTED, mac, MARK_KNOWN))
			white_mac[mac] = true
		end
	elseif action == '+' then
		for _, mac in pairs(maclist) do 
			if not white_mac[mac] then
				iptables_do_command(string.format(
					'-t mangle -A %s -m mac --mac-source %s -j MARK --set-mark %s', 
					CHAIN_TRUSTED, mac, MARK_KNOWN))
				white_mac[mac] = true
			end
		end
	elseif action == '-' then
		for _, mac in pairs(maclist) do 
			if white_mac[mac] then
				iptables_do_command(string.format(
					'-t mangle -D %s -m mac --mac-source %s -j MARK --set-mark %s', 
					CHAIN_TRUSTED, mac, MARK_KNOWN))
				white_mac[mac] = nil
			end
		end
	end
end

function fw.update_black_maclist(action, maclist)
	if action == '=' then
		iptables_do_command('-t mangle -F ', CHAIN_LOCKED)
		black_mac = {}
		for _, mac in pairs(maclist) do 
			iptables_do_command(string.format(
				'-t mangle -A %s -m mac --mac-source %s -j MARK --set-mark %s', 
				CHAIN_LOCKED, mac, MARK_LOCKED))
			black_mac[mac] = true
		end
	elseif action == '+' then
		for _, mac in pairs(maclist) do 
			if not black_mac[mac] then
				iptables_do_command(string.format(
					'-t mangle -A %s -m mac --mac-source %s -j MARK --set-mark %s', 
					CHAIN_LOCKED, mac, MARK_LOCKED))
				black_mac[mac] = true
			end
		end
	elseif action == '-' then
		for _, mac in pairs(maclist) do 
			if black_mac[mac] then
				iptables_do_command(string.format(
					'-t mangle -D %s -m mac --mac-source %s -j MARK --set-mark %s', 
					CHAIN_LOCKED, mac, MARK_LOCKED))
				black_mac[mac] = nil
			end
		end
	end
end

function fw.update_server(hostname)
	if not fw_start then
		return
	end
	if hostname:is_ipv4() and not green_ip[hostname] then
		green_ip[hostname] = true
		iptables_do4_command('-t filter -A ', CHAIN_SERVERS, ' -d ', hostname, ' -j ACCEPT')
		iptables_do4_command('-t nat -A ', CHAIN_SERVERS, ' -d ', hostname, ' -j ACCEPT')
		return {hostname}
	else
		local iplist = tasklet.getaddrbyname(hostname)
		local old_iplist = servers[hostname]
		for _, ip in pairs(iplist) do 
			if not old_iplist or table.find(old_iplist, ip) and not green_ip[ip] then
				iptables_do4_command('-t filter -A ', CHAIN_SERVERS, ' -d ', ip, ' -j ACCEPT')
				iptables_do4_command('-t nat -A ', CHAIN_SERVERS, ' -d ', ip, ' -j ACCEPT')
				green_ip[ip] = true
			end
		end
		if old_iplist then
			for _, ip in pairs(old_iplist) do
				if not table.find(iplist, ip) and green_ip[ip] then
					iptables_do4_command_once('-t filter -D ', CHAIN_SERVERS, ' -d ', ip, ' -j ACCEPT')
					iptables_do4_command_once('-t nat -D ', CHAIN_SERVERS, ' -d ', ip, ' -j ACCEPT')
					green_ip[ip] = nil
				end
			end
		end
		servers[hostname] = iplist
		return iplist
	end
end
function chain_exsit(table_name,chain)
	local file = io.popen('iptables -v -n -x -t '..table_name..' -L ' .. chain .. ' 2>/dev/null', 'r')
	if not file then
		return false
	end
	
	local line = file:read('*line')
	file:close()

	if line then
		local data = line:match(chain)
		
		if data then
			log.error('table:'..table_name..' chain:' .. chain .. ' is exsit')
			return true
		end
	end
	log.error('table:'..table_name..' chain:' .. chain .. ' not exsit')
	return false
end
function fw.init(conf)
	local fs = require "nixio.fs"
	local uci = require "luci.model.uci".cursor()
	local portal = uci:get("luci", "main", "portal")
	if portal then
		log.error("support portal:"..portal)
	end
	fw_start = true
	-----------------------------------------------------------------------------------------------
	-- { MANGLE 	
	if not chain_exsit("mangle",CHAIN_TRUSTED) then		
		iptables_longdo_command('-t mangle -N ', CHAIN_TRUSTED)
	else
		iptables_do_command('-t mangle -F ', CHAIN_TRUSTED)
	end

	if not chain_exsit("mangle",CHAIN_LOCKED) then	
		iptables_longdo_command('-t mangle -N ', CHAIN_LOCKED)
	else
		iptables_do_command('-t mangle -F ', CHAIN_LOCKED)
	end
	if not chain_exsit("mangle",CHAIN_OUTGOING) then	
		iptables_longdo_command('-t mangle -N ', CHAIN_OUTGOING)
	else
		iptables_do_command('-t mangle -F ', CHAIN_OUTGOING)
	end
	if not chain_exsit("mangle",CHAIN_OUTGOING2) then	
		iptables_longdo_command('-t mangle -N ', CHAIN_OUTGOING2)
	else
		iptables_do_command('-t mangle -F ', CHAIN_OUTGOING2)	
	end
	if not chain_exsit("mangle",CHAIN_OUTGOING_SKIP) then	
		iptables_longdo_command('-t mangle -N ', CHAIN_OUTGOING_SKIP)
	else
		iptables_do_command('-t mangle -F ', CHAIN_OUTGOING_SKIP)
	end
	if not chain_exsit("mangle",CHAIN_INCOMING) then	
		iptables_longdo_command('-t mangle -N ', CHAIN_INCOMING)
	else
		iptables_do_command('-t mangle -F ', CHAIN_INCOMING)
	end
	if portal == "1" then
		iptables_do_command_once('-t mangle -D PREROUTING  -i ',conf.gw_interface,  ' -m mark --mark ', 0, ' -j RETURN')
		iptables_longdo_command('-t mangle -I PREROUTING  -i ',conf.gw_interface,  ' -m mark --mark ', 0, ' -j RETURN')
		local selfspeedlimit = uci:get("system", "basic", "speedlimit") or "1"
		if selfspeedlimit ~= "0" then
			iptables_do_command_once('-t mangle -D subnet_internet -i ',conf.gw_interface,' -m mark --mark 0 -j RETURN')
			iptables_do_command('-t mangle -I subnet_internet -i ',conf.gw_interface,' -m mark --mark 0 -j RETURN')
		else
			iptables_do_command_once('-t mangle -D FORWARD -i ',conf.gw_interface,' -m mark ! --mark 1 -j RETURN')
			iptables_do_command('-t mangle -I FORWARD -i ',conf.gw_interface,' -m mark ! --mark 1 -j RETURN')
		end
	end


	if fs.access("/tmp/wifiauth_close") then
		fw.allow_skip()
	end
	iptables_do_command_once('-t mangle -D PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING2)
	iptables_longdo_command('-t mangle -I PREROUTING 1 -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING2)

	iptables_do_command_once('-t mangle -D PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING_SKIP)
	iptables_longdo_command('-t mangle -I PREROUTING 1 -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING_SKIP)
	if not execute("ipset list hide-access-list",1) then
		os.execute("ipset create hide-access-list hash:ip")
	end
	if not execute("ipset list hide-access-list6",1) then
		os.execute("ipset create hide-access-list6 hash:ip family inet6")
	end
	iptables_do4_command('-t mangle -I ',CHAIN_OUTGOING2,' 1 -i ', conf.gw_interface, ' -m set --match-set hide-access-list dst -j MARK --set-mark 1')
	iptables_do6_command('-t mangle -I ',CHAIN_OUTGOING2,' 1 -i ', conf.gw_interface, ' -m set --match-set hide-access-list6 dst -j MARK --set-mark 1')
	iptables_longdo_command('-t mangle -I ',CHAIN_OUTGOING2,' -i ', conf.gw_interface, ' -p udp --dport 53 -j MARK --set-mark 1')
	iptables_longdo_command('-t mangle -I ',CHAIN_OUTGOING2,' -i ', conf.gw_interface, ' -p tcp --dport 53 -j MARK --set-mark 1')
	iptables_longdo_command('-t mangle -I ',CHAIN_OUTGOING2,' -i ', conf.gw_interface, ' -p tcp --dport 67 -j MARK --set-mark 1')
	iptables_longdo_command('-t mangle -I ',CHAIN_OUTGOING2,' -i ', conf.gw_interface, ' -p udp --dport 67 -j MARK --set-mark 1')
	-- 

	iptables_do_command_once('-t mangle -D PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING)
	iptables_do_command_once('-t mangle -D PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_TRUSTED)
	iptables_do_command_once('-t mangle -D PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_LOCKED)
	iptables_do_command_once('-t mangle -D POSTROUTING -o ', conf.gw_interface, ' -j ', CHAIN_INCOMING)

	iptables_longdo_command('-t mangle -I PREROUTING 1 -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING)
	iptables_longdo_command('-t mangle -I PREROUTING 1 -i ', conf.gw_interface, ' -j ', CHAIN_TRUSTED)
	iptables_longdo_command('-t mangle -I PREROUTING 1 -i ', conf.gw_interface, ' -j ', CHAIN_LOCKED)
	iptables_longdo_command('-t mangle -I POSTROUTING 1 -o ', conf.gw_interface, ' -j ', CHAIN_INCOMING)


	-- }
	-----------------------------------------------------------------------------------------------

	
	
	-----------------------------------------------------------------------------------------------
	-- { NAT
	if not chain_exsit("nat",CHAIN_OUTGOING) then	
		iptables_longdo_command('-t nat -N ', CHAIN_OUTGOING)
	else
		iptables_do_command('-t nat -F ', CHAIN_OUTGOING)
	end
	if not chain_exsit("nat",CHAIN_UNKNOWN) then	
		iptables_longdo_command('-t nat -N ', CHAIN_UNKNOWN)
	else
		iptables_do_command('-t nat -F ', CHAIN_UNKNOWN)
	end
	if not chain_exsit("nat",CHAIN_GLOBAL) then	
		iptables_longdo_command('-t nat -N ', CHAIN_GLOBAL)
	else
		iptables_do_command('-t nat -F ', CHAIN_GLOBAL)
	end
	if not chain_exsit("nat",CHAIN_SERVERS) then	
		iptables_longdo_command('-t nat -N ', CHAIN_SERVERS)
	else
		iptables_do_command('-t nat -F ', CHAIN_SERVERS)
	end
	
	iptables_do_command_once('-t nat -D PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING)
	iptables_longdo_command('-t nat -A PREROUTING -i ', conf.gw_interface, ' -j ', CHAIN_OUTGOING)

	iptables_do4_command('-t nat -A ', CHAIN_OUTGOING, ' -d ', conf.gw_address, ' -j ACCEPT')
	iptables_longdo_command('-t nat -A ', CHAIN_OUTGOING, ' -m mark --mark ', MARK_KNOWN, ' -j ACCEPT')
	if portal == "1" then
		iptables_longdo_command('-t nat -A ', CHAIN_OUTGOING, ' -m mark ! --mark ', 0, ' -j ACCEPT')
	end
	iptables_longdo_command('-t nat -A ', CHAIN_OUTGOING, ' -j ', CHAIN_UNKNOWN)
	iptables_longdo_command('-t nat -A ', CHAIN_UNKNOWN, ' -j ', CHAIN_SERVERS)
	iptables_longdo_command('-t nat -A ', CHAIN_UNKNOWN, ' -j ', CHAIN_GLOBAL)
	iptables_longdo_command('-t nat -A ', CHAIN_UNKNOWN, ' -p tcp --dport 80 -j REDIRECT --to-ports ', conf.gw_port)
	-- }
	-----------------------------------------------------------------------------------------------
	
	
	
	-----------------------------------------------------------------------------------------------
	-- { FILTER
	if not chain_exsit("filter",CHAIN_TO_INTERNET) then	
		iptables_longdo_command('-t filter -N ', CHAIN_TO_INTERNET)
	else
		iptables_do_command('-t filter -F ', CHAIN_TO_INTERNET)
	end

	if not chain_exsit("filter",CHAIN_SERVERS) then		
		iptables_longdo_command('-t filter -N ', CHAIN_SERVERS)
	else
		iptables_do_command('-t filter -F ', CHAIN_SERVERS)
	end
	if not chain_exsit("filter",CHAIN_LOCKED) then	
		iptables_longdo_command('-t filter -N ', CHAIN_LOCKED)
	else
		iptables_do_command('-t filter -F ', CHAIN_LOCKED)
	end

	if not chain_exsit("filter",CHAIN_GLOBAL) then	
		iptables_longdo_command('-t filter -N ', CHAIN_GLOBAL)
	else
		iptables_do_command('-t filter -F ', CHAIN_GLOBAL)
	end
	if not chain_exsit("filter",CHAIN_KNOWN) then
		iptables_longdo_command('-t filter -N ', CHAIN_KNOWN)
	else
		iptables_do_command('-t filter -F ', CHAIN_KNOWN)
	end

	if not chain_exsit("filter",CHAIN_UNKNOWN) then		
		iptables_longdo_command('-t filter -N ', CHAIN_UNKNOWN)
	else
		iptables_do_command('-t filter -F ', CHAIN_UNKNOWN)
	end
	iptables_do_command_once('-t filter -D forwarding_rule -i ', conf.gw_interface, ' -j ', CHAIN_TO_INTERNET)
	iptables_longdo_command('-t filter -A forwarding_rule -i ', conf.gw_interface, ' -j ', CHAIN_TO_INTERNET)
	iptables_longdo_command('-t filter -A ', CHAIN_TO_INTERNET, ' -m conntrack --ctstate INVALID -j DROP')

	iptables_longdo_command('-t filter -A ', CHAIN_TO_INTERNET, ' -j ', CHAIN_SERVERS)

	iptables_longdo_command('-t filter -A ', CHAIN_TO_INTERNET, ' -m mark --mark ', MARK_LOCKED, ' -j ', CHAIN_LOCKED)
	iptables_load_ruleset(conf, 'filter', 'locked-users', CHAIN_LOCKED)

	iptables_do_command('-t filter -A ', CHAIN_TO_INTERNET, ' -j ', CHAIN_GLOBAL)
	iptables_load_ruleset(conf, 'filter', 'global', CHAIN_GLOBAL)
	iptables_load_ruleset(conf, 'nat', 'global', CHAIN_GLOBAL)

	iptables_longdo_command('-t filter -A ', CHAIN_TO_INTERNET, ' -m mark --mark ', MARK_KNOWN, ' -j ', CHAIN_KNOWN)
	if portal == "1" then
		iptables_longdo_command('-t filter -A ', CHAIN_TO_INTERNET, ' -m mark ! --mark ', 0, ' -j ', CHAIN_KNOWN)
	end
	iptables_load_ruleset(conf, 'filter', 'known-users', CHAIN_KNOWN)
	iptables_do6_command('-t filter -A ', CHAIN_KNOWN, ' -j ACCEPT')


	iptables_longdo_command('-t filter -A ', CHAIN_TO_INTERNET, ' -j ', CHAIN_UNKNOWN)
	iptables_load_ruleset(conf, 'filter', 'unknown-users', CHAIN_UNKNOWN)
	
	iptables_do4_command('-t filter -A ', CHAIN_UNKNOWN, ' -j REJECT --reject-with icmp-port-unreachable')
	iptables_do6_command('-t filter -A ', CHAIN_UNKNOWN, ' -j REJECT')
	-- }
	-----------------------------------------------------------------------------------------------
end

local function destroy_common_mention(cmd,table, chain, mention)
	local file = io.popen(string.format('%s -t %s -L %s -n --line-numbers -v 2>/dev/null',cmd, table, chain), 'r')
	if not file then
		return
	end
	
	local deleted = false
	file:read('*line')
	file:read('*line')
	local line = file:read('*line')
	while line do 
		if line:find(mention) then
			local num = tonumber(line:match('%d+'))
			if num then
				if cmd == "iptables" then
					iptables_do4_command_once('-t ', table, ' -D ', chain, ' ', num)
				else
					iptables_do6_command_once('-t ', table, ' -D ', chain, ' ', num)
				end
				deleted = true
				break
			end
		end
		line = file:read('*line')
	end
	file:close()
	
	if deleted then
		destroy_common_mention(cmd, table, chain, mention)
	end
end

local function destroy_mention(table, chain, mention)
	destroy_common_mention('iptables',table, chain, mention)
	destroy_common_mention('ip6tables',table, chain, mention)
end
function clean_extra_rule()
	local uci = require "luci.model.uci".cursor()
	local selfspeedlimit = uci:get("system", "basic", "speedlimit") or "1"

	if selfspeedlimit == "0" then
		iptables_do_command_once('-t mangle -D FORWARD -i ',conf.gw_interface,' -m mark ! --mark 1 -j RETURN')
	else
		iptables_do_command_once('-t mangle -D subnet_internet -i ',conf.gw_interface,' -m mark ! --mark 1 -j RETURN')
	end
end
function fw.destroy(conf)
	clean_extra_rule()
	destroy_mention('mangle', 'PREROUTING', CHAIN_TRUSTED)
	destroy_mention('mangle', 'PREROUTING', CHAIN_LOCKED)
	destroy_mention('mangle', 'PREROUTING', CHAIN_OUTGOING)
	destroy_mention('mangle', 'POSTROUTING', CHAIN_INCOMING)
	iptables_do_command_once('-t mangle -F ', CHAIN_TRUSTED)
	iptables_do_command_once('-t mangle -F ', CHAIN_OUTGOING)
	iptables_do_command_once('-t mangle -F ', CHAIN_OUTGOING2)
	iptables_do_command_once('-t mangle -F ', CHAIN_OUTGOING_SKIP)	
	iptables_do_command_once('-t mangle -F ', CHAIN_LOCKED)
	iptables_do_command_once('-t mangle -F ', CHAIN_INCOMING)
	iptables_do_command_once('-t mangle -X ', CHAIN_TRUSTED)
	iptables_do_command_once('-t mangle -X ', CHAIN_OUTGOING)
	iptables_do_command_once('-t mangle -X ', CHAIN_OUTGOING2)
	iptables_do_command_once('-t mangle -X ', CHAIN_OUTGOING_SKIP)
	iptables_do_command_once('-t mangle -X ', CHAIN_LOCKED)
	iptables_do_command_once('-t mangle -X ', CHAIN_INCOMING)
	iptables_do_command_once('-t mangle -D PREROUTING  -i ',conf.gw_interface,  ' -m mark --mark ', 0, ' -j RETURN')
	destroy_mention('nat', 'PREROUTING', CHAIN_OUTGOING)
	iptables_do_command_once('-t nat -F ', CHAIN_SERVERS)
	iptables_do_command_once('-t nat -F ', CHAIN_OUTGOING)
	iptables_do_command_once('-t nat -F ', CHAIN_GLOBAL)
	iptables_do_command_once('-t nat -F ', CHAIN_UNKNOWN)
	iptables_do_command_once('-t nat -X ', CHAIN_SERVERS)
	iptables_do_command_once('-t nat -X ', CHAIN_OUTGOING)
	iptables_do_command_once('-t nat -X ', CHAIN_GLOBAL)
	iptables_do_command_once('-t nat -X ', CHAIN_UNKNOWN)

	destroy_mention('filter', 'forwarding_rule', CHAIN_TO_INTERNET)
	iptables_do_command_once('-t filter -F ', CHAIN_TO_INTERNET)
	iptables_do_command_once('-t filter -F ', CHAIN_SERVERS)
	iptables_do_command_once('-t filter -F ', CHAIN_LOCKED)
	iptables_do_command_once('-t filter -F ', CHAIN_GLOBAL)
	iptables_do_command_once('-t filter -F ', CHAIN_KNOWN)
	iptables_do_command_once('-t filter -F ', CHAIN_UNKNOWN)
	iptables_do_command_once('-t filter -X ', CHAIN_TO_INTERNET)
	iptables_do_command_once('-t filter -X ', CHAIN_SERVERS)
	iptables_do_command_once('-t filter -X ', CHAIN_LOCKED)
	iptables_do_command_once('-t filter -X ', CHAIN_GLOBAL)
	iptables_do_command_once('-t filter -X ', CHAIN_KNOWN)
	iptables_do_command_once('-t filter -X ', CHAIN_UNKNOWN)
end

function fw.update_counters(clients_bymac)

	local function update_bytes(chain, field, pattern)
		local file = io.popen('iptables -v -n -x -t mangle -L ' .. chain .. ' 2>/dev/null', 'r')
		if not file then
			return false
		end
		
		file:read('*line')
		file:read('*line')
		local line = file:read('*line')
		while line do 
			local bytes, mac,mac2 = line:match(pattern)
			if bytes and mac and mac2 then
				if mac ~= "MAC" then
					mac = mac:gsub("^MAC", "")
				else
					mac = mac2
				end
				if #mac == 17 then
					mac = mac:upper()
					--log.error('bytes: ',bytes," mac:", mac)
					local client = clients_bymac[mac]
					if client then
						client[field] = tonumber(bytes) or 0
					else
						log.error('update_counters(): ', mac, ' is missing in the clients, destroy mangle mention')
						destroy_mention("mangle", CHAIN_OUTGOING, mac)
					end
				end
			end
			line = file:read('*line')
		end
		file:close()
		return true
	end
	return update_bytes(CHAIN_OUTGOING, 'outgoing', '^%s*%d+%s+(%d+) %S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+(%S+)%s+(%S+)%s+(%S+)')
end
	
return fw

