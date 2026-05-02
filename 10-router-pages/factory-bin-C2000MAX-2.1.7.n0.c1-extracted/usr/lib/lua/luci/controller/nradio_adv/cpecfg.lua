-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.nradio_adv.cpecfg", package.seeall)

local nr = require "luci.nradio"

function index()
	local uci = require "luci.model.uci".cursor()
	local count_cpe = luci.nradio.count_cpe()

	if count_cpe <= 0 then
		return
	end
	entry({"nradio","cellular","cpelock","model"}, cbi("nradio_cpecfg/cpelock"), _("CellularLockTitle"), 40, true).leaf = true
	pagelock = entry({"nradio", "cellular", "cpelock"}, cbi("nradio_cpecfg/cpelock"), _("CellularLockTitle"), 30, true)
	pagelock.show = false
	pagelock.index = true
	entry({"nradio","cellular","cpecfg","model"}, cbi("nradio_cpecfg/cpecfg"), _("Cellular Setting"), 40, true).leaf = true
	page = entry({"nradio", "cellular", "cpecfg"}, cbi("nradio_cpecfg/cpecfg"), _("Cellular Setting"), 30, true)
	page.show = false
	page.index = true
	entry({"nradio","cellular","cpepin","model"}, cbi("nradio_cpecfg/cpepin"), _("Cellular Pin"), 40, true).leaf = true
	page = entry({"nradio", "cellular", "cpepin"}, cbi("nradio_cpecfg/cpepin"), _("Cellular Pin"), 30, true)
	page.show = false
	page.index = true
	page.icon = "podcast"
end
