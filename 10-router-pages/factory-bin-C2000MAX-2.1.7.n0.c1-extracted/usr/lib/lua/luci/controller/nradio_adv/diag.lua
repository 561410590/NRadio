-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.diag", package.seeall)

function index()
	page = entry({"nradioadv", "network", "diag"}, template("nradio_adv/diag"), _("Diagnostics"), 20, true)

	page.icon = 'nradio-diag'
	page.show = luci.nradio.has_nat()
end
