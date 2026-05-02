module("luci.controller.nradio_adv.modeselect", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/mtkhnat") then
		return
	end

	page = entry({"nradioadv", "network", "modeselect"}, cbi("nradio_adv/modeselect"), _("ModeSelect"), 37, true)
	page.show = true
	page.icon = 'nradio-modeselect'
end
