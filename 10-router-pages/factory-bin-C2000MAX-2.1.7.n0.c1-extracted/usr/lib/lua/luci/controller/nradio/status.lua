-- Copyright 2017 NRadio

module("luci.controller.nradio.status", package.seeall)
local nr = require "luci.nradio"

function index()
	entry({"nradio", "status"}, template("nradio_status/index"), _("Status"), 1, true).index = true
	entry({"nradio", "status", "runtime"}, call("action_runtime_info"), nil, nil, true).leaf = true
	entry({"nradio", "status", "speed"}, call("action_speed_info"), nil, nil, true).leaf = true
	entry({"nradio", "status", "update"}, call("action_status_update"), nil, nil, true).leaf = true
	entry({"nradio", "system", "overview"}, alias("nradio", "status"), _("Overview"), 10, true).index = true
	entry({"nradio", "system", "sim"}, template("nradio_status/sim"), nil, nil, true).index = true
	entry({"nradio", "system", "sim","model"}, call("get_cellular_template"), nil, nil, true).leaf = true
	entry({"nradio", "system", "sim","mode"}, call("action_sim_save"), nil, nil, true).leaf = true
	entry({"nradio", "system", "device"}, template("nradio_status/device"), nil, nil, true).leaf = true
	entry({"nradio", "system", "device","model"}, call("get_cellular_template"), nil, nil, true).leaf = true
	entry({"nradio", "system", "wifi"}, alias("nradio", "basic", "wifi"), nil, nil, true).index = true
	entry({"nradio", "system", "terminal"}, template("nradio_status/terminal"), nil, nil, true).leaf = true
	entry({"nradio", "system", "upgrade"}, template("nradio_status/upgrade"), nil, nil, true).leaf = true
	entry({"nradio", "system", "apn_simple"}, alias("nradio", "cellular", "apn_simple"), nil, nil, true).leaf= true
	entry({"nradio", "system", "cpeoptimizes"}, alias("nradioadv", "cellular", "cpeoptimizes"), nil, nil, true).leaf = true
end
function get_cellular_template()
	luci.nradio.get_cellular_template()
end

-- Get runtime info
-- @return runtime info result
-- {
--   "result": {
--     "ac": {
--       "online": 0,
--       "offline": 0
--     }
--     "wlan": {
--       "txrate": 0,
--       "rxrate": 0
--       "realtime": {
--          "sta2": 0,
--          "sta5": 0
--       },
--       "history": {
--          "sta2": 0,
--          "sta5": 0
--       },
--     },
--     "wan": {
--       "ulrate": 0,
--       "dlrate": 0,
--       "upload": 0,
--       "download": 0,
--       "cellular": 0
--     },
--   }
-- }
function action_runtime_info(ifaces)
	nr.luci_call_result(nr.get_runtime_info(ifaces))
end
function action_speed_info(ifaces)
	nr.luci_call_result(nr.get_speed_info(ifaces))
end

-- Update status
function action_status_update()
	local cld = require "luci.model.cloudd".init()
	cld.cloudd_update()
end

function action_sim_save()
	local http = require "luci.http"
	local uci  = require "luci.model.uci".cursor()
	local mode = http.formvalue("mode")
	local cpe_section = http.formvalue("cpe_section")
	local sim_section = http.formvalue("sim_section")
	local sim = http.formvalue("sim")
	local sim_change = 0
	local mode_change = 0
	
	if not sim_section or not cpe_section then
		nr.luci_call_result({code=-1})
		return
	end
	cpe_section = cpe_section:gsub("[;'\\\"]", "")
	local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"
	local cur_mode = uci:get("cpesel", sim_section, "mode") or "1"

	if sim and cur_sim ~= sim then
		sim_change = 1
		uci:set("cpesel", sim_section, "cur",sim)
	end
	if mode and cur_mode ~= mode then
		mode_change = 1
		uci:set("cpesel", sim_section, "mode",mode)
	end
	if sim_change == 1 or mode_change == 1 then
		uci:commit("cpesel")
	end
	nr.switch_sim(sim_change,mode_change,0,cpe_section,sim_section)
	nr.luci_call_result({code=0})
end
