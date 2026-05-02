-- Copyright 2017 NRadio
-- Licensed to the public under the Apache License 2.0.

local ut = require "luci.util"
local nr = require "luci.nradio"
local cl = require "luci.model.cloudd".init()
local ca = require "cloudd.api"
local fs = require "nixio.fs"

local id = ca.cloudd_get_self_id()
local cdev = cl.get_device(id, "slave")
local radio_cnt = {band2 = 1, band5 = 1}

local has_2g = false
local has_5g = false

m = Map("wireless", translate("Wireless Bridge"))

s = m:section(NamedSection, "apcli", "wifi-iface")

if cdev then
	radio_cnt = cdev:get_radiocnt()
	if radio_cnt.band2 > 0 then
		has_2g = true
	end
	if radio_cnt.band5 > 0 then
		has_5g = true
	end
end

local net, freq, ssid, bssid, encryption, key

en = s:option(Flag, "disabled", translate("Enable"))
en.rmempty = false
function en.cfgvalue(self, section)
	local value = tonumber(m:get(section, "disabled") or "0")

	if value == 0 then
		return "1"
	else
		return "0"
	end
end
function en.write(self, section, value)
	if value == "1" then
		value = "0"
	else
		value = "1"
	end
	return m:set(section, "disabled", value)
end

net = s:option(ListValue, "network", translate("Network"))
net:value("lan", "lan")
net.default = "lan"
if fs.access("/etc/config/dhcp") then
    net:value("wisp", "wan")
end

freq = s:option(ListValue, "workfreq", translate("Freq"))
if has_2g == true then
	freq:value("1", translate("2.4GHz"))
end
if has_5g == true then
	freq:value("2", translate("5GHz"))
end

ssid = s:option(Value, "ssid", translate("SSID"))
ssid.datatype = "maxlength(32)"

bssid = s:option(Value, "bssid", translate("BSSID"))
bssid.datatype = "macaddr"

encryption = s:option(ListValue, "encryption", translate("Encryption"))
encryption:value("none", translate("No Encryption"))
encryption:value("psk-mixed", translate("WPA2-Personal"))

key = s:option(Value, "key", translate("Password"))
key:depends("encryption", "psk-mixed")
key.password = true
key.rmempty = true
key.datatype = "wpakey"

function m.parse(map)
	Map.parse(map)
	if m:submitstate() then
		os.execute("/usr/bin/apcli.sh")
	end
end

submit = Template("nradio_plugin/confirm_submit")
function submit.render(self)
	luci.template.render(self.template, {noppsk = true})
end
m:append(submit)

return m
