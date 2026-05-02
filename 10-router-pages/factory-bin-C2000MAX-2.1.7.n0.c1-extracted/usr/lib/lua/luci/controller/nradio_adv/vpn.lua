module("luci.controller.nradio_adv.vpn", package.seeall)

function index()
	page = entry({"nradioadv", "vpn", "vpn"}, cbi("nradio_adv/vpn"), _("VPDN"), 10, true)
	page.show = luci.nradio.has_nat()
	page.icon = 'paper-plane'
end
