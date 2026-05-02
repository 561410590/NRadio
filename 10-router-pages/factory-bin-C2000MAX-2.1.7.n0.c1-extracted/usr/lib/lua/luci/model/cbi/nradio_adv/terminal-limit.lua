-- Copyright 2017-2018 NRadio
-- Licensed to the public under the Apache License 2.0.

local nr = require "luci.nradio"
local util = require "luci.util"
m = Map("terminal", translate("QoS"))

s = m:section(NamedSection, "config", "terminal")
local function init_specaildata(object,option)
	function object.parse(self, section, novld)
		local enabled_key = "cbid."..self.map.config.."."..section..".".."enabled"
		local enabled_data = luci.http.formvalue(enabled_key)
		local fvalue = self:formvalue(section)
		if fvalue and #fvalue > 0 then
			return Value.parse(self, section, novld)
		else
			if enabled_data == "1" then
				return Value.parse(self, section, novld)
			end
		end
	end
end
limit = s:option(Flag, "enabled", translate("QoS"))
limit.default = "0"

download = s:option(Value, "download", translate("Downlink bandwidth Maximum(Kbps)"))
download.datatype = "range(0,1048576)"
download.rmempty = false
download:depends("enabled","1")
init_specaildata(download,"download")
upload = s:option(Value, "upload", translate("Uplink bandwidth Maximum(Kbps)"))
upload.datatype = "range(0,1048576)"
upload.rmempty = false
upload:depends("enabled","1")
init_specaildata(upload,"upload")
des_v = s:option(DummyValue,"   ","   ",translate("*Upon Enabling QoS, bandwidth is regulated for all clients. To exclude specific clients from throttling, <br>configure exceptions in the \"<a href='/cgi-bin/luci/nradio/system/client'>Clients Info</a>\" settings."))
return m
