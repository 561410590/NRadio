-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.wanchk", package.seeall)

function index()
	page = entry({"nradioadv", "network", "wanchk"}, cbi("nradio_adv/wanchk"), _("WAN Checker"), 20, true)
	entry({"nradioadv", "network","wanchk","model"}, cbi("nradio_adv/wanchk"), _("WAN Checker"), 40, true).leaf = true
	page.icon = 'nradio-wanchk'
	page.show = luci.nradio.has_nat()
end
