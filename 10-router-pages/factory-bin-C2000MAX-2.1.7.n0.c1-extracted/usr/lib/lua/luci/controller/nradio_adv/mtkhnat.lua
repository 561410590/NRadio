module("luci.controller.nradio_adv.mtkhnat", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/mtkhnat") then
		return
	end
	if nixio.fs.access("/usr/lib/lua/luci/controller/nradio_adv/modeselect.lua") then
		return
	end
	page = entry({"nradioadv", "network", "mtkhnat"}, cbi("nradio_adv/mtkhnat"), _("HNAT"), 37, true)
	page.show = luci.nradio.has_wan() or luci.nradio.has_phy()
	page.icon = 'nradio-hnat'
end
