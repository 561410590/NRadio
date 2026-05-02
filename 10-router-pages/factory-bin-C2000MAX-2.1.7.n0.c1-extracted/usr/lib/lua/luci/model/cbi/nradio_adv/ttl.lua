-- Copyright 2017-2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local nr = require "luci.nradio"
local util = require "luci.util"
m = Map("ttl", translate("TTLTitle"),translate("TTLDes"))

s = m:section(TypedSection, "ttl")
s.addremove = false
s.anonymous = true

ipv4_ttl = s:option(Value, "ipv4", translate("TTLIPv4Lable"))
ipv4_ttl.password = false
ipv4_ttl.datatype ="range(1, 255)"
ipv4_ttl.placeholder = translate("TTLplaceholder")
ipv4_ttl.rmempty = true
ipv4_ttl.description = translate("TTLIPv4Help")

local support_ipv6 = m.uci:get("luci", "main", "ipv6") or "1"
local country = m.uci:get("oem","board","country")
if country and #country > 1 and country ~= "CN" and support_ipv6 and support_ipv6 == "1" then
	ipv6_ttl = s:option(Value, "ipv6", translate("TTLIPv6Lable"))
	ipv6_ttl.password = false
	ipv6_ttl.datatype ="range(0, 255)"
	ipv6_ttl.placeholder = translate("TTLplaceholder")
	ipv6_ttl.rmempty = true
	ipv6_ttl.description = translate("TTLIPv6Help")

	function ipv6_ttl.write(self, section, value)
		self.map:set(  "ttl", nil,"config")
		return Value.write(self, section, value) 
	end
end

function s.cfgsections()
	return { "ttl" }
end

function ipv4_ttl.write(self, section, value)
	self.map:set("ttl", nil,"config")
	return Value.write(self, section, value) 
end

function m.on_after_commit()
    if m:submitstate() then
		local uci  = require "luci.model.uci"
		local cur = uci.cursor()
		cur:foreach("network", "interface",
			function(s)
				if s.proto == "wwan" or s.proto == "tdmi" then
					if s.disabled and s.disabled == "1" then
						return
					end
					util.exec("ifup "..s[".name"])
				end
			end
		)
    end
end

return m
