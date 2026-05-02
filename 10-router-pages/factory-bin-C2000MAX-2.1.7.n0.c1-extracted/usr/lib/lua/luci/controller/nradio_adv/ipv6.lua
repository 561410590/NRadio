-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.ipv6", package.seeall)

function index()
	local nr = require "luci.nradio"
	if nr.support_wan_ipv6() or nr.has_cpe() then
		page = entry({"nradioadv", "network", "ipv6"}, cbi("nradio_adv/ipv6_basic"), _("IPv6Title"), 66, true)
		entry({"nradioadv", "network","ipv6","lan"}, cbi("nradio_adv/ipv6_lan"), _("IPv6LANTitle"), 67, true).leaf = true
	elseif nr.support_ipv6() then
		page = entry({"nradioadv", "network", "ipv6"}, alias("nradioadv", "network", "ipv6","lan"), _("IPv6Title"), 66, true)
		entry({"nradioadv", "network","ipv6","lan"}, cbi("nradio_adv/ipv6_lan"), _("IPv6LANTitle"), 67, true).leaf = true
	else
		return
	end

	page.icon = 'nradio-ipv6'
	page.show = true
end
