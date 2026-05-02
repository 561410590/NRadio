module("luci.controller.nradio_adv.restart", package.seeall)

function index()
	if not pcall(require, "luci.nradio") then
		return
	end

	page = entry({"nradioadv", "system", "restart"}, cbi("nradio_adv/restart", {hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("Reboot"), 30, true)
	page.icon = 'nradio-reset'
	page.show = true
end
