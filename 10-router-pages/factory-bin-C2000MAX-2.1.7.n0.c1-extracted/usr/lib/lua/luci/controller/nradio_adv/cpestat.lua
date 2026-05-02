-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.nradio_adv.cpestat", package.seeall)

local nr = require "luci.nradio"
local uci = require "luci.model.uci".cursor()
local utl = require "luci.util"

function index()
	if not nixio.fs.access("/etc/config/tcsd") then
		return
	end

	entry({"nradio", "cpestat"}, cbi("nradio_cpestat/cpestat"), _("Cellular Traffic"), 40, true).index = true
	entry({"nradio", "cpestat", "reset"}, call("action_reset"), nil, nil, true)

	page = entry({"nradioadv", "cellular", "cpestat"}, alias("nradio", "cpestat"), _("Cellular Traffic"), 10, true)
	page.show = luci.nradio.has_cpe()
	page.icon = "chart-bar"
end

function action_reset()
	local iface = luci.http.formvalue("iface") or "cpe"
	local slot = luci.http.formvalue("slot") or "0"
	local cur = uci:get("cpesel", "sim", "cur") or "0"
	local max = tonumber(uci:get("cpesel", "sim", "max") or "1")

	if cur == slot or max == 1 then
		os.execute("kill -USR1 $(cat /var/run/tcsd-"..iface..".pid)")
	else
		uci:set("tcsd", iface, "tx"..slot, 0)
		uci:set("tcsd", iface, "rx"..slot, 0)
		uci:commit("tcsd")
		utl.ubus("tcsd", "set", {name = "cpe"..slot, tc = "0,0"})
	end
end
