-- Copyright 2017-2019 NRadio

local util = require "luci.util"
local sys = require "luci.sys"
local fs = require "nixio.fs"

local support_ipsec = false

if fs.access("/usr/sbin/ipsec") then
	support_ipsec = true
end

m = Map("network", translate("VPDN"))

local proto, server, username, password, en, mppe_en

m:append(Template("nradio_adv/vpn"))

if support_ipsec then
	m:chain("ipsec")
end

s = m:section(NamedSection, "vpn", "interface")

en = s:option(Flag, "disabled", translate("Enable"))
en.rmempty = false

function en.cfgvalue(...)
	local v = Value.cfgvalue(...)
	if v and v == "1" then
		return "0"
	end
	return "1"
end

function en.write(self, section, value)
	if not value or value == "0" then
		value = 1
	else
		value = 0
	end

	return Flag.write(self, section, value)
end

proto = s:option(ListValue, "proto", translate("Protocol"))
proto.default = "pptp"
proto:value("pptp", translate("PPTP"))
proto:value("l2tp", translate("L2TP"))

pptp_mppe_en = s:option(Flag, "pptp_mppe_disabled", translate("MPPE Encryption Enable"))
pptp_mppe_en.rmempty = false
pptp_mppe_en:depends("proto", "pptp")

function pptp_mppe_en.cfgvalue(...)
	local v = Value.cfgvalue(...)
	if v and v == "1" then
		return "0"
	end
	return "1"
end

function pptp_mppe_en.write(self, section, value)
	if not value or value == "0" then
		value = 1
	else
		value = 0
	end

	return Flag.write(self, section, value)
end

if support_ipsec then
	ipsec_encr_en = s:option(Flag, "ipsec_enabled", translate("IPSec Encryption Enable"))
	ipsec_encr_en:depends("proto", "l2tp")
	ipsec_encr_en.rmempty = false
	function ipsec_encr_en.cfgvalue(...)
		return m.uci:get("ipsec", "l2tp_remote", "enabled") or "0"
	end
	function ipsec_encr_en.write(self, section, value)
		return m.uci:set("ipsec", "l2tp_remote", "enabled", value or "0")
	end

	ipsec_psk = s:option(Value, "ipsec_psk", translate("Pre-shared Key"))
	ipsec_psk:depends("ipsec_enabled", true)
	ipsec_psk.datatype = "rangelength(1,128)"
	function ipsec_psk.cfgvalue(...)
		return m.uci:get("ipsec", "l2tp_remote", "pre_shared_key") or ""
	end
	function ipsec_psk.write(self, section, value)
		return m.uci:set("ipsec", "l2tp_remote", "pre_shared_key", value or "0")
	end
end

server = s:option(Value, "server", translate("VPN Server"))
function server.write(self, section, value)
	if support_ipsec then
		m.uci:set("ipsec", "l2tp_remote", "gateway", value)
		m.uci:set("ipsec", "l2tp_conn", "remote_subnet", value.."[17/1701]")
	end

	return Value.write(self, section, value)
end

username = s:option(Value, "username", translate("Username"))

password = s:option(Value, "password", translate("Password"))
password.password = true

function m.on_after_commit(map)
	if support_ipsec then
		sys.exec("/etc/init.d/ipsec restart")
	end
	sys.exec("ifup vpn")
end

return m
