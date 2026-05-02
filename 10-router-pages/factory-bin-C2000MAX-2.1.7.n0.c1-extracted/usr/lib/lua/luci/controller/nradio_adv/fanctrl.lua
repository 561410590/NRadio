module("luci.controller.nradio_adv.fanctrl", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/fanctrl") then
		return
	end

	page = entry({"nradioadv", "system", "fanctrl"}, cbi("nradio_adv/fanctrl"), _("FanControl"), 90, true)
	page.show = true
	page.icon = 'nradio-fanctrl'
	entry({"nradioadv", "system", "fanctrl", "temperature"}, call("action_get_temperature"), nil, nil, true).leaf = true
end

function action_get_temperature()
	local util = require "luci.util"
	local data = {}
	local result = util.ubus("infocd", "get",{name='temperature'}) or { }
	for _,item in pairs(result.list) do
		if item.name and item.name == "temperature" then
			data = item.parameter or {}
		end
	end

	luci.nradio.luci_call_result(data)
end