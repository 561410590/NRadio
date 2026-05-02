-- Copyright 2017-2018 NRadio

local ipc = require "luci.ip"
local uci = require "luci.model.uci".cursor()
local nr = require "luci.nradio"

local lan_section = uci:get("network", "globals", "default_lan") or "lan"
local zone = arg[1] or lan_section

local ips = {}
local clients = {}
uci:foreach("cloudd_cli", client,
			function(s)
				if s.mac then
					clients[s.mac:lower()] = s.name or ""
				end
			end
)

m = Map("dhcp", translate("DHCP"))
s = m:section(TypedSection, "dhcp")
s.addremove = false
s.anonymous = true

function s.filter(self, section)
	return m.uci:get("dhcp", section, "interface") == zone
end

local ignore = s:option(Flag, "ignore",
	translate("DHCP"))
ignore.rmempty = false

function ignore.cfgvalue(self, section)
	local value = tonumber(m:get(section, "ignore") or "0")
	if value == 0 then
		return "1"
	else
		return "0"
	end
end

function ignore.write(self, section, value)
	if value == "1" then
		m:set(section, "ignore", "0")
	else
		m:set(section, "ignore", "1")
	end
end

local start = s:option(Value, "start", translate("Start"))

start.rmempty = true
start.datatype = "and(uinteger,range(1, 254))"
start.placeholder = "100"
start.default = 100

local limit = s:option(Value, "limit", translate("Number of Clients"),
	translate("*Note: The maximum number of clients is determined by the starting" ..
		" IP and intranet subnet mask. If you want to increase the number of users," ..
		" please go to the \"LAN Settings\" page to modify the subnet mask."))
limit.rmempty = true
limit.datatype = "and(uinteger,range(1, 65535))"
limit.placeholder = "150"
limit.default = "150"

local range = s:option(Value, "range", translate("IP Range"))
range.readonly = true
function range.cfgvalue(self, section)
	return ""
end

function range.write(self, section, value)
	return true
end

local ltime = s:option(Value, "leasetime", translate("Lease Time (min)"))
ltime.rmempty = true
ltime.datatype = "and(uinteger,range(2, 99999999))"
ltime.placeholder = "720"
function ltime.cfgvalue(self, section)
	local second = m:get(section, "leasetime") or 43200
	return tonumber(second) / 60
end

function ltime.write(self, section, value)
	local second = tonumber(value)*60
	return Value.write(self, section, second)
end

m:section(SimpleSection).template = "nradio_adv/lease_status"

s = m:section(TypedSection, "host", translate("Static Leases"))

s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection_nradio"

ip = s:option(Value, "ip", translate("IPv4 Address"))
ip.datatype = "or(ip4addr,'ignore')"

mac = s:option(Value, "mac", translate("MAC Address"))
mac.datatype = "list(macaddr)"
mac.rmempty  = true

name = s:option(Value, "name", translate("Hostname"))
name.template = "nradio_adv/cbi_evalue"

function name.cfgvalue(self, section)
	local mac = m:get(section, "mac")
	return clients[mac] or ""
end

function name.write(self, section, value)
	return true
end

function name.editvalue(self, section)
	return m:get(section, "mac") or ""
end

ipc.neighbors({ family = 4 }, function(n)
	if n.mac and n.dest then
		ip:value(n.dest:string())
		mac:value(n.mac, "%s (%s)" %{ n.mac:upper(), n.dest:string() })
	end
end)

function ip.validate(self, value, section)
	local m = mac:formvalue(section) or ""
	local n = name:formvalue(section) or ""

	if value and #n == 0 and #m == 0 then
		return nil, translate("One of hostname or mac address must be specified!")
	end

	if self.map:submitstate() then
		if ips[value] then
			return nil, translate("One of IP address is duplicate!")
		end
		ips[value] = true
	end
	return Value.validate(self, value, section)
end

return m
