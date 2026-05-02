-- Copyright 2017 NRadio

module("luci.controller.nradio.adv", package.seeall)

function index()
	local page = entry({"nradio", "advanced"}, template("nradio_adv/index"), _("Advanced"), 40, true)
	page.index = true
	page.show = true
	page.icon = 'cogs'

	local page   = node("nradioadv")
	page.target  = firstchild()
	page.title   = _("Administration")
	page.order   = 40
	page.sysauth = "root"
	page.sysauth_authenticator = "htmlauth"
	page.ucidata = true
	page.index = true

	entry({"nradioadv", "network"}, alias("nradio", "advanced"), _("Network"), 10, true)
	entry({"nradioadv", "wireless"}, alias("nradio", "advanced"), _("Wireless"), 20, true)
	entry({"nradioadv", "cellular"}, alias("nradio", "advanced"), _("Cellular"), 30, true)
	entry({"nradioadv", "vpn"}, alias("nradio", "advanced"), _("VPN"), 35, true)
	entry({"nradioadv", "ac"}, alias("nradio", "advanced"), _("AC"), 40, true)
	entry({"nradioadv", "system"}, alias("nradio", "advanced"), _("System"), 50, true)
end
