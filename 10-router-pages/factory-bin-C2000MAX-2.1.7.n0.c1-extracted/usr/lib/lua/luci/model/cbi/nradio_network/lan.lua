-- Copyright 2017-2018 NRadio
local util = require "luci.util"
local sys = require "luci.sys"
local fs = require "nixio.fs"
local nr = require "luci.nradio"
local lock_flag=0

m = Map("network", translate("LAN Setting"))
local lan_section = m.uci:get("network", "globals", "default_lan") or "lan"
s = m:section(NamedSection, lan_section, "interface")
m:chain("dhcp")

function m.on_after_commit()
	local nr = require "luci.nradio"
	nr.save_lan_ip()
end
local function get_option_dns()
	local data = m.uci:get("dhcp","@dnsmasq[0]", "dhcp_option")
	if data then
		for key,val in pairs(data) do
			local option_array = util.split(val, ",")
			for i=1,#option_array do
				if option_array[1] == "6" and i > 1 then
					return val
				end
			end
		end
	end
	return ""
end
local function init_dhcp_dns(object,option)
	function object.parse(self, section, novld)
		if lock_flag == 1 then
			return
		end
		lock_flag=1
		local custom_option_dns1 = "cbid."..self.map.config.."."..section..".".."dns1"
		local custom_option_dns2 = "cbid."..self.map.config.."."..section..".".."dns2"
		local dhcp_option=""
		local custom_dns1 = luci.http.formvalue(custom_option_dns1)
		local custom_dns2 = luci.http.formvalue(custom_option_dns2)
		local data = get_option_dns()
		if custom_dns1 and #custom_dns1 > 0 and custom_dns2 and #custom_dns2 > 0 then
			dhcp_option = "6,"..custom_dns1..","..custom_dns2
		elseif custom_dns1 and #custom_dns1 > 0 then
			dhcp_option = "6,"..custom_dns1
		elseif custom_dns2 and #custom_dns2 > 0  then
			dhcp_option = "6,"..custom_dns2
		end
		dhcp_option = dhcp_option:gsub("[;'\\\"]", "")
		if data ~= dhcp_option then
			if data and #data > 0 then
				os.execute("uci del_list dhcp.@dnsmasq[0].dhcp_option="..data)
			end
			if dhcp_option and #dhcp_option > 0 then
				os.execute("uci add_list dhcp.@dnsmasq[0].dhcp_option="..dhcp_option)
			end
		end
	end
	function object.cfgvalue(self, section)
		local data = get_option_dns()

		local option_array = util.split(data, ",")
		for i=1,#option_array do
			if option == "dns1" then
				return option_array[2] or ""
			elseif option == "dns2" then
				return option_array[3] or ""
			end
		end

		return  ""
	end
end
local ipaddr, netmask, gateway, dns

ipaddr = s:option(Value, "ipaddr", translate("IPv4 address"))
ipaddr.datatype = "ip4addr"
ipaddr.optional = false
ipaddr.rmempty = false

netmask = s:option(Value, "netmask",translate("IPv4 netmask"))
netmask.datatype = "netmask"
netmask:value("255.255.255.0")
netmask:value("255.255.0.0")
netmask:value("255.0.0.0")
netmask.optional = false
netmask.rmempty = false

dns1 = s:option(Value, "dns1", translate("DNS1"))
dns1.datatype = "ip4addr"
dns1.rmempty = true
init_dhcp_dns(dns1,"dns1")
dns2 = s:option(Value, "dns2", translate("DNS2"))
dns2.datatype = "ip4addr"
dns2.rmempty = true
init_dhcp_dns(dns2,"dns2")
if not luci.nradio.has_ptype("rt", "cpe", "spy") then
	gateway = s:option(Value, "gateway", translate("IPv4 gateway"))
	gateway.datatype = "ip4addr"

	dns = s:option(DynamicList, "dns", translate("DNS servers"))
	dns.datatype = "ip4addr"
	dns.cast     = "string"
end

return m
