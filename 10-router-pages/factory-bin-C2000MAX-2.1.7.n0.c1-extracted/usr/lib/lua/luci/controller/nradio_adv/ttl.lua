module("luci.controller.nradio_adv.ttl", package.seeall)

function index()
	if not pcall(require, "luci.nradio") then
		return
	end

	page = entry({"nradioadv", "network", "ttl"}, cbi("nradio_adv/ttl"), _("TTLTitle"), 45, true)
	page.icon = 'nradio-ttl'
	page.show = true
end
