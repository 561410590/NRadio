-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.dmz", package.seeall)

function index()
	page = entry({"nradioadv", "network", "dmz"}, cbi("nradio_adv/dmz"), _("DMZTitle"), 20, true)

	page.icon = 'nradio-dmz'
	page.show = luci.nradio.has_nat()
end
