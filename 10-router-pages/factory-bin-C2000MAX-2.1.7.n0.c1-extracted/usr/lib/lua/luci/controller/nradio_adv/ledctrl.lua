module("luci.controller.nradio_adv.ledctrl", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/ledctrl") then
		return
	end

	page = entry({"nradioadv", "system", "ledctrl"}, cbi("nradio_adv/ledctrl"), _("LED Control"), 90, true)
	page.show = true
	page.icon = 'nradio-led'
end
