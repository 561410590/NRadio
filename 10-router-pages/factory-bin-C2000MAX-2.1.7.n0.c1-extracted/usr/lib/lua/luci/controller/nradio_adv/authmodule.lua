module("luci.controller.nradio_adv.authmodule", package.seeall)

function index()
	local util = require "luci.util"
	local authmode = util.exec("bdinfo -g authmode")
	if not authmode or #authmode == 0 then
		return
	end
	page = entry({"nradioadv", "system", "authmodule"}, cbi("nradio_adv/authmodule"), _("Auth Module"), 3, true)
	page.show = true
	page.icon = 'nradio-authdebug'
end
