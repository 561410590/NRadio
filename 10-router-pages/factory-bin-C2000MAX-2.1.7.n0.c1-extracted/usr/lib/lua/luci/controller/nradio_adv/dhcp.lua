module("luci.controller.nradio_adv.dhcp", package.seeall)

local uci = require "luci.model.uci".cursor()
local nr = require "luci.nradio"

function index()
	if not nixio.fs.access("/etc/config/dhcp") then
		return
	end

	page = entry({"nradioadv", "network", "dhcp"}, cbi("nradio_adv/dhcp"), _("DHCP"), 10, true)
	page.index = true
	page.icon = 'nradio-server'
	page.show = luci.nradio.has_nat()

	entry({"nradioadv", "network", "dhcp", "add"}, call("action_add_static"), nil, nil, true).leaf = true
end

function action_add_static()
	local ip = luci.http.formvalue("ip")
	local mac = luci.http.formvalue("mac")
	local hn = luci.http.formvalue("hn")
	if not ip or not mac or not hn then
		return false
	end

	section = uci:add("dhcp", "host")

	if not section then
		return false
	end

	uci:set("dhcp", section, "ip", ip)
	uci:set("dhcp", section, "mac", mac)

	uci:save("dhcp")

	nr.set_client_name(mac, hn)
end
