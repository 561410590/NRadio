
module("luci.controller.nradio_adv.simpleroutes", package.seeall)

function index()
	local nr = require "luci.nradio"
	local page
	page = entry({"nradioadv", "network", "simpleroutes"}, cbi("nradio_adv/simpleroutes"), _("Static Routes"), 66, true)
	page.icon = 'nradio-routes'
	page.show = true	
end
