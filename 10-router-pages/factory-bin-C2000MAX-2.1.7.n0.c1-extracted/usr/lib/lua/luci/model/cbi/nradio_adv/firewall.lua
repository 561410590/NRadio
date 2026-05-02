-- Copyright 2017-2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local util = require "luci.util"

m = Map("firewall", translate("Firewall"))
s = m:section(NamedSection, "@defaults[0]", "defaults")
firewall = s:option(Flag, "enabled", translate("Firewall"))
firewall.rmempty = false

function firewall.cfgvalue(self, section)
	local enabled = true
	local defaults = m.uci:get("firewall", "@defaults[0]", "forward") or "REJECT"
	if defaults == "ACCEPT" then
		enabled = false
	end

	m.uci:foreach("firewall", "zone", function(s)
		if s.name == "wan" then
			if s.input == "ACCEPT" or s.forward == "ACCEPT" then
				enabled = false
			end
			return
		end
	end)

    return enabled and "1" or "0"
end

des_v = s:option(DummyValue,"   ","   ",translate("*Warning: Disabling the firewall exposes the device to security risks. Proceed with caution. Keep enabled for security."))

function firewall.write(self, section, value)
	local type = value == "1" and "REJECT" or "ACCEPT"
	m.uci:foreach("firewall", "zone",
		function(s)
			if s.name == "wan" then
				m.uci:set("firewall", s[".name"], "input", type)
				m.uci:set("firewall", s[".name"], "forward", type)
			end
		end)
	m.uci:set("firewall", "@defaults[0]", "forward", type)
	util.exec("/etc/init.d/firewall reload")
end

return m
