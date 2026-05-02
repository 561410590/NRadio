-- Copyright 2017 NRadio

local fs = require "nixio.fs"

m = Map("network", translate("Quick Setup"))
m:chain("wireless")
m.redirect = luci.dispatcher.build_url("nradio/status")

local uci = require("luci.model.uci").cursor()
local proto, username, password, ipaddr, netmask, gateway, peerdns, dns
local has_wan = false
local has_wifi = false
local wifi_cnt = 0

if uci:get("network", "wan") then
	has_wan = true
end

uci:foreach("wireless", "wifi-device",
	function(s)
		has_wifi = true
		return false
	end)

s = m:section(NamedSection, "wan", "interface", "")
s.anonymous = true
s.addremove = false

if has_wan then
	s:tab("wan",  translate("WAN Setting"))

	proto = s:taboption("wan", ListValue, "proto", translate("Protocol"))
	proto:value("pppoe", translate("PPPoE"))
	proto:value("dhcp", translate("DHCP client"))
	proto:value("static", translate("Static address"))

	username = s:taboption("wan", Value, "username", translate("Username"))
	username:depends({proto="pppoe"})

	password = s:taboption("wan", Value, "password", translate("Password"))
	password:depends({proto="pppoe"})
	password.password = true

	ipaddr = s:taboption("wan", Value, "ipaddr", translate("IPv4 address"))
	ipaddr.datatype = "ip4addr"
	ipaddr:depends({proto="static"})

	netmask = s:taboption("wan", Value, "netmask",translate("IPv4 netmask"))

	netmask.datatype = "netmask"
	netmask:value("255.255.255.0")
	netmask:value("255.255.0.0")
	netmask:value("255.0.0.0")
	netmask:depends({proto="static"})

	gateway = s:taboption("wan", Value, "gateway", translate("IPv4 gateway"))
	gateway.datatype = "ip4addr"
	gateway:depends({proto="static"})

	peerdns = s:taboption("wan", Flag, "peerdns",
		translate("Peer DNS"),
		translate("If unchecked, the advertised DNS server addresses are ignored"))

	peerdns.default = peerdns.enabled
	peerdns:depends("proto","dhcp")
	peerdns:depends("proto","pppoe")

	dns = s:taboption("wan", DynamicList, "dns",
		translate("DNS servers"))

	dns:depends("peerdns", "")
	dns.datatype = "ip4addr"
	dns.cast     = "string"
end

if has_wifi then
	s:tab("wifi",  translate("WLAN Setting"))

	local sameprof, bssid, encryption, key
	local wifiifaces = {}
	local curwifidev = ""
	local prefix = ""

	uci:foreach("wireless", "wifi-iface",
		function(s)
			if s["mode"] == "ap" and s["device"] ~= curwifidev then
				curwifidev = s["device"]
				table.insert(wifiifaces, s[".name"])
			end
		end)

	table.sort(wifiifaces)

	for i = 1, #(wifiifaces) do
		if i > 1 then
			prefix = "5G "
		end

		bssid = s:taboption("wifi", Value, "ssid-" .. wifiifaces[i], prefix .. translate("SSID"))

		function bssid.cfgvalue(...)
			return m.uci:get("wireless", wifiifaces[i], "ssid")
		end

		function bssid.write(self, section, value)
			if #(wifiifaces) > 1 and i == 1 then
				if sameprof:formvalue("wan") then
					-- set all config as the same as the first one
					for j = 2, #(wifiifaces) do
						m.uci:set("wireless", wifiifaces[j], "ssid", value)
					end
				end
			elseif #(wifiifaces) > 1 then
				-- skip if same profile used
				if sameprof:formvalue("wan") then
					return true
				end
			end

			m.uci:set("wireless", wifiifaces[i], "ssid", value)
		end

		encryption = s:taboption("wifi", ListValue, "enc-" .. wifiifaces[i], prefix .. translate("Encryption"))
		encryption:value("none", translate("No Encryption"))
		encryption:value("psk-mixed", translate("WPA2-Personal"))

		function encryption.cfgvalue(...)
			return m.uci:get("wireless", wifiifaces[i], "encryption")
		end

		function encryption.write(self, section, value)
			if #(wifiifaces) > 1 and i == 1 then
				if sameprof:formvalue("wan") then
					-- set all config as the same as the first one
					for j = 2, #(wifiifaces) do
						if value == "none" then
							m.uci:delete("wireless", wifiifaces[j], "key")
						end
						m.uci:set("wireless", wifiifaces[j], "encryption", value)
					end
				end
			elseif #(wifiifaces) > 1 then
				-- skip if same profile used
				if sameprof:formvalue("wan") then
					return true
				end
			end

			if value == "none" then
				m.uci:delete("wireless", wifiifaces[i], "key")
			end
			m.uci:set("wireless", wifiifaces[i], "encryption", value)
		end

		key = s:taboption("wifi", Value, "key-" .. wifiifaces[i], prefix .. translate("Password"))
		key:depends("enc-" .. wifiifaces[i], "psk-mixed")
		key.password = true
		key.rmempty = true
		key.datatype = "wpakey"

		function key.cfgvalue(...)
			return m.uci:get("wireless", wifiifaces[i], "key")
		end

		function key.write(self, section, value)
			if #(wifiifaces) > 1 and i == 1 then
				if sameprof:formvalue("wan") then
					-- set all config as the same as the first one
					for j = 2, #(wifiifaces) do
						m.uci:set("wireless", wifiifaces[j], "key", value)
					end
				end
			elseif #(wifiifaces) > 1 then
				-- skip if same profile used
				if sameprof:formvalue("wan") then
					return true
				end
			end
			m.uci:set("wireless", wifiifaces[i], "key", value)
		end

		if i == 1 and #(wifiifaces) > 1 then
			sameprof = s:taboption("wifi", Flag, "sameprof", translate("Use one profile"))
			sameprof.default = sameprof.enabled

			function sameprof.write(self, section, value)
			end
		elseif i > 1 then
			bssid:depends({sameprof=""});
			encryption:depends({sameprof=""});
			key:depends({sameprof="", encryption="psk-mixed"});
		end
	end
end

s:tab("admin", translate("Router Password"))

pw1 = s:taboption("admin", Value, "pw1", translate("Admin Password"))
pw1.password = true

function pw1.cfgvalue(...)
	return ""
end

function pw1.write(self, section, value)
end

function m.on_commit(map)
	local v1 = pw1:formvalue("wan")

	if v1 and #v1 > 0 then
		if luci.sys.user.setpasswd(luci.dispatcher.context.authuser, v1) == 0 then
			m.message = translate("Password successfully changed!")
		else
			m.message = translate("Unknown Error, password not changed!")
		end
	end

	if has_wan then
		if m.uci:get("network", "wan", "proto") ~= proto:formvalue("wan") then
			local k, v
			for k, v in pairs(m:get(net:name())) do
				if k:sub(1,1) ~= "." and
				   k ~= "type" and
				   k ~= "ifname" and
				   k ~= "_orig_ifname" and
				   k ~= "_orig_bridge"
				then
					m:del(net:name(), k)
				end
			end
		end
	end
end

m:append(Template("nradio_qsetup/wizard"))

m:append(Template("nradio_qsetup/validate"))

return m
