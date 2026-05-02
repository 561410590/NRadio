module("luci.controller.nradio_adv.firewall", package.seeall)

function index()
	local firmware = luci.nradio.get_firmware_type()
	page = entry({"nradioadv", "network", "firewall"}, cbi("nradio_adv/firewall"), _("Firewall"), 50, true)
	page.icon = 'nradio-firewall'
	if firmware == "stand" then
		page.show = true
	end
end
