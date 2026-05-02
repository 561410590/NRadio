-- Copyright 2017-2018 nradio

module("luci.controller.nradio.network", package.seeall)

function index()
	local uci = require("luci.model.uci").cursor()

	if luci.nradio.has_wan_port() then
		entry({"nradio", "basic", "wan"}, cbi("nradio_network/wan"), _("InternetTitle"), 10, true).index = true
	end

	entry({"nradio", "basic", "lan"}, cbi("nradio_network/lan"), _("LanTitle"), 20, true).index = true
	entry({"nradio", "basic", "iface"}, call("action_net_status"), nil, nil, true).leaf = true
	local page
	page = entry({"nradioadv", "network", "lan"}, alias("nradio", "basic", "lan"), _("LanTitle"), 35, true)
	page.icon = 'nradio-lan'
	page.show = true
end

function action_net_status(ifaces)
	luci.nradio.luci_call_result(luci.nradio.get_net_status(ifaces))
end
