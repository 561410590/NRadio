module("luci.controller.nradio_adv.passwd", package.seeall)

function index()
	if not pcall(require, "luci.nradio") then
		return
	end

	page = entry({"nradioadv", "system", "passwd"}, cbi("nradio_adv/passwd"), _("Account"), 20, true)
	page.icon = 'nradio-user'
	page.show = true
end
