-- Copyright 2017-2018 NRadio
local util = require "luci.util"
local sys = require "luci.sys"
local nr = require "luci.nradio"
local fs = require "nixio.fs"
local uci  = require "luci.model.uci"
local proto, username, password, ipaddr, netmask, gateway, peerdns, dns, mtu, mac, protov
local support_nat = nr.support_ipv6_nat()
local support_relay = nr.support_ipv6_relay()
local support_relay_local = nr.support_ipv6_relay_local()
local plat = nr.get_platform()
m = Map("network", "")
local lan_section = m.uci:get("network", "globals", "default_lan") or "lan"
local wan6_section = m.uci:get("network", "globals", "default_wan6") or "wan6"

ipv6_tmpt=Template("nradio_ipv6/template")
function ipv6_tmpt.render(self)
	luci.template.render(self.template,{model="basic"})
end
m:append(ipv6_tmpt)
m:chain("luci")
m:chain("dhcp")
s = m:section(NamedSection, "globals", "globals")

function set_relay_relate()
	local cur = uci.cursor()
	local relay_on = cur:get("firewall","@defaults[0]","ipv6_nat") or "1"
	local ipv6_ctl_val = cur:get("network", "globals", "ipv6") or "0"
	
	if ipv6_ctl_val == "1" then
		ipv6_ctl_val = true
	else
		ipv6_ctl_val = false
	end

	if ipv6_ctl_val then
		cur:set("dhcp",lan_section,"ndp","server")
		cur:set("dhcp",lan_section,"dhcpv6","server")
		cur:set("dhcp",lan_section,"ra","server")
		cur:set("dhcp",lan_section,"ra_default","1")
		cur:set("dhcp",lan_section,"ra_management","0")
	else
		cur:delete("dhcp",lan_section,"ndp")
		cur:delete("dhcp",lan_section,"dhcpv6")
		cur:delete("dhcp",lan_section,"ra")
		cur:delete("dhcp",lan_section,"ra_default")
		cur:delete("dhcp",lan_section,"ra_management")
	end
	if plat ~= "tdtech" and plat ~= "quectel" and not support_relay_local then
		if relay_on == "0" and ipv6_ctl_val then
			cur:foreach("network", "interface",
				function(s)
					if s.proto == "wwan" or s.proto == "tdmi" then
						cur:set("dhcp",s[".name"],"dhcp")
						cur:set("dhcp",s[".name"],"ignore","1")
						cur:set("dhcp",s[".name"],"interface",s[".name"])
						cur:set("dhcp",s[".name"],"master","1")
						cur:set("dhcp",s[".name"],"ra","relay")
						cur:set("dhcp",s[".name"],"dhcpv6","relay")
						cur:set("dhcp",s[".name"],"ndp","relay")
					end
				end
			)
			cur:set("dhcp",lan_section,"ra","relay")
			cur:set("dhcp",lan_section,"dhcpv6","relay")
			cur:set("dhcp",lan_section,"ndp","relay")
			cur:set("dhcp","wan","ra","relay")
			cur:set("dhcp","wan","dhcpv6","relay")
			cur:set("dhcp","wan","ndp","relay")
			cur:set("dhcp","wan","master","1")
		else
			cur:foreach("network", "interface",
				function(s)
					if s.proto == "wwan" or s.proto == "tdmi" then
						cur:delete("dhcp",s[".name"])
					end
				end
			)
			cur:delete("dhcp","wan","ra")
			cur:delete("dhcp","wan","dhcpv6")
			cur:delete("dhcp","wan","ndp")
			cur:delete("dhcp","wan","master")
		end
	end
	cur:commit("dhcp")
	if not support_nat or (relay_on == "0" and ipv6_ctl_val) then
		nr.ip6class_set(false,true)				
	else
		nr.ip6class_set(true,true)	
	end	
end

ipv6_ctl = s:option(Flag, "ipv6_ctl",
translate("IPv6Switch"),translate("IPv6SwitchHelp"))
ipv6_ctl.default = "0"
ipv6_ctl.rmempty = false

function ipv6_ctl.cfgvalue(self, section)
	if m.uci:get("network",section, "ipv6") == "1" then
		return "1"
	else
		return "0"
	end
end

function ipv6_ctl.write(self, section, value)
	if value == "1" then
		if m.uci:get("network",wan6_section) then
			m.uci:set("network",wan6_section,"ipv6","1")
		end
		m.uci:set("network",section,"ipv6","1")	
	else
		if m.uci:get("network",wan6_section) then
			m.uci:set("network",wan6_section,"ipv6","0")
		end
		m.uci:set("network",section,"ipv6","0")
	end
end

if support_relay then
	if plat ~= "tdtech" and plat ~= "quectel" then
		ipv6_relay = s:option(Flag, "ipv6_relay",
			translate("IPv6Relay"),translate("IPv6RelayHelp"))
		ipv6_relay.default = "0"
		ipv6_relay:depends({ipv6_ctl="1"})
		function ipv6_relay.cfgvalue(self, section)
			local cur = uci.cursor()
			if cur:get("firewall","@defaults[0]", "ipv6_nat") == "1" then
				return "0"
			else
				return "1"
			end
		end

		function ipv6_relay.remove(self, section)
			local cur = uci.cursor()
			cur:set("firewall","@defaults[0]","ipv6_nat","1")
			cur:commit("firewall")
		end

		function ipv6_relay.write(self, section, value)
			local ipv6_ctl_val = luci.http.formvalue("cbid.network.globals.ipv6_ctl")
			local cur = uci.cursor()

			if value == "1" and ipv6_ctl_val == "1" then
				cur:set("firewall","@defaults[0]","ipv6_nat","0")
			else
				cur:set("firewall","@defaults[0]","ipv6_nat","1")
			end
			cur:commit("firewall")
		end
	end
end

if nr.support_wan_ipv6() then
	proto = s:option(ListValue, "proto", translate("WiredType"))
	proto.default = "dhcpv6"
	proto:value("pppoe", translate("PPPoE"))
	proto:value("dhcpv6", translate("DHCPv6Client"))
	proto:value("slaac", translate("SLAAC"))
	proto:value("static", translate("Static IP"))
	proto:depends({ipv6_ctl="1"})

	function proto.cfgvalue(self, section)
		local proto_v = m.uci:get("network",wan6_section, "proto")
		local reqprefix_v = m.uci:get("network",wan6_section, "reqprefix")
		if proto_v == "dhcpv6" and reqprefix_v == "no" then
			return "slaac"
		end
		return proto_v
	end

	function proto.write(self, section, value)
		protov = value
		if value == "pppoe" then
			m.uci:set("network",wan6_section,"ipv6","auto")
		else
			m.uci:delete("network",wan6_section,"ipv6")
		end
		if value == "slaac" then
			m.uci:set("network",wan6_section,"reqprefix","no")
			m.uci:set("network",wan6_section,"reqaddress","none")
			return Value.write(self, wan6_section, "dhcpv6")
		end
		m.uci:delete("network",wan6_section,"reqprefix")
		m.uci:delete("network",wan6_section,"reqaddress")
		return Value.write(self, wan6_section, value)
	end


	function proto_tplparse(object, depend,option)
		if not protov then
			protov = m.uci:get("network",wan6_section, "proto")
		end
		
		local depends_table = {proto=depend,ipv6_ctl="1"}
		object:depends(depends_table)
		function object.parse(self, section, novld)
			local fvalue = self:formvalue(section)
			local cvalue = self:cfgvalue(section)
			if cvalue and ((not fvalue or #fvalue == 0 ) and protov ~= depend) then
				m:del(wan6_section,option)
				return
			end
			return Value.parse(self, section, novld)
		end
		function object.write(self, section, value)
			m:set(wan6_section,option,value)			
		end
        function object.cfgvalue(self, section)
            return m:get(wan6_section, option)
        end
	end
	function gerneral_tplparse(object,option)
		function object.parse(self, section, novld)
			local fvalue = self:formvalue(section)
			local cvalue = self:cfgvalue(section)
			if cvalue and (not fvalue or #fvalue == 0 )then
				if option == "peerdns" then
					m:set(wan6_section,option,"0")
				else
					m:del(wan6_section,option)
				end
				return
			end
			return Value.parse(self, section, novld)
		end
		function object.write(self, section, value)
			return m:set(wan6_section,option,value)			
		end
        function object.cfgvalue(self, section)
			if option == "peerdns" then
				return m:get(wan6_section, option) or "1"
			else
				return m:get(wan6_section, option)
			end
        end
	end

	username = s:option(Value, "username", translate("Username"))
	username.datatype = "minlength(1)"
	proto_tplparse(username, "pppoe","username")

	password = s:option(Value, "password", translate("Password"))
	password.password = true
	password.datatype = "minlength(1)"
	proto_tplparse(password, "pppoe","password")

	ipaddr = s:option(Value, "ip6addr", translate("IPv6Address"))
	ipaddr.datatype = "ip6addr"
	proto_tplparse(ipaddr, "static","ip6addr")

	--[[netmask = s:option(Value, "ip6assign",translate("IPv6Prefix"))
	netmask.default = "64"
	netmask.datatype = "range(0,64)"
	proto_tplparse(netmask, "static","ip6assign")--]]

	gateway = s:option(Value, "ip6gw", translate("IPv6Gateway"))
	gateway.datatype = "ip6addr"
	proto_tplparse(gateway, "static","ip6gw")

	peerdns = s:option(Flag, "peerdns",
		translate("Use Default DNS"))
	peerdns.default = 1
	peerdns:depends({proto="dhcpv6",ipv6_ctl="1"})
	peerdns:depends({proto="slaac",ipv6_ctl="1"})
	peerdns:depends({proto="pppoe",ipv6_ctl="1"})
	gerneral_tplparse(peerdns,"peerdns")
	dns = s:option(DynamicList, "dns", translate("DNS Server"))
	dns:depends({proto="pppoe", peerdns="",ipv6_ctl="1"})
	dns:depends({proto="dhcpv6", peerdns="",ipv6_ctl="1"})
	dns:depends({proto="slaac", peerdns="",ipv6_ctl="1"})
	dns:depends({proto="static", peerdns="",ipv6_ctl="1"})
	dns.datatype = "ip6addr"
	dns.cast     = "string"
	gerneral_tplparse(dns,"dns")
end

function m.on_after_commit(map)
	if fs.access("/etc/config/mtkhnat") then
		sys.exec("/etc/init.d/mtkhnat restart")
	end

	if fs.access("/usr/bin/wanswd.sh") then
		sys.exec("/etc/init.d/wanswd restart >/dev/null 2>&1")
	end
	set_relay_relate()
	if support_relay then
		sys.exec("fw3 reload >/dev/null 2>&1")
		sys.exec("/etc/init.d/odhcpd restart >/dev/null 2>&1")
		sys.exec("killall odhcp6c >/dev/null 2>&1")		
	end
	nr.fork_exec(function ()
		nixio.nanosleep(2)
		sys.exec("ifup "..lan_section.." >/dev/null 2>&1")
	end)
end

return m
