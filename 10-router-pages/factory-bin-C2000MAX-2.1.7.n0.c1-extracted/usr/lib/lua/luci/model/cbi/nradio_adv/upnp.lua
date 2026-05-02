-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.
local nr = require "luci.nradio"
local upnphelp_info = ""
m = Map("upnpd", luci.util.pcdata(translate("UPnPTitle")))

s = m:section(NamedSection, "config", "upnpd")
s.addremove = false

if nr.support_ipv6_relay() then
	local plat = nr.get_platform()
	if plat == "tdtech" or plat == "quectel"  then
		upnphelp_info =  translate("UPnPenableHelp1")
	else
		upnphelp_info =  translate("UPnPenableHelp")
	end
end

e = s:option(Flag, "enabled", translate("UPnPenable"),upnphelp_info)
e.rmempty  = false

sta = s:option(DummyValue, " ")
sta.template = "nradio_adv/upnp_status"

function e.write(self, section, value)
	if value == "1" then
		luci.sys.call("/etc/init.d/miniupnpd start >/dev/null")
	else
		luci.sys.call("/etc/init.d/miniupnpd stop >/dev/null")
	end

	return Flag.write(self, section, value)
end

return m
