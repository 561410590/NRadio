module("luci.controller.nradio_adv.nbcpe", package.seeall)
local uci = require "luci.model.uci".cursor()
local util = require "luci.util"
function index()
	if not luci.nradio.has_nbcpe() then
		return
	end
	local count_cpe = luci.nradio.count_cpe()
	if tonumber(count_cpe) == 1 then
		return 
	end
	page = entry({"nradioadv", "network","nbcpe"}, call("get_cellular_template"), _("NBCPE Setting"), 200, true)
	page.show = true
	page.icon = 'nradio-nbcpe'
end



function get_cellular_template()
	luci.http.redirect(luci.dispatcher.build_url("nradio/cellular/cpedevice/model/"..luci.nradio.has_nbcpe()))
end
