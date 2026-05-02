-- Copyright 2017 NRadio

module("luci.controller.nradio.hsimlock", package.seeall)
local uci = require "luci.model.uci".cursor()
local nr = require "luci.nradio"
local util = require "luci.util"
function index()
	local uci = require "luci.model.uci".cursor()
	local nr = require "luci.nradio"
	local util = require "luci.util"
	local sim_protect = util.exec("bdinfo -g sim_protect") or ""
	if not nr.has_cpe() then
		return
	end
	if sim_protect ~= "1" then
		return
	end
	entry({"nradio", "hsimlock"}, alias("nradio", "hsimlock","index"), _("HSimTitle"), 201, true).index = true
	entry({"nradio", "hsimlock","index"}, template("nradio_hsimlock/hsimlock"), _("HSimTitle"), 201, true).index = true
	entry({"nradio", "hsimlock", "simstatus"}, call("action_simstatus"), nil, nil, true).leaf = true
	entry({"nradio", "hsimlock", "lock"}, call("action_simlock"), nil, nil, true).leaf = true
	entry({"nradio", "hsimlock", "auth"}, call("action_simauth"), nil, nil, true).leaf = true
end

function action_simauth()
	local sim_security="43cfff8ee8513d86bb16e13636c143e3"
	local sim_pwd = luci.http.formvalue("sim_pwd")
	local token_sys = luci.dispatcher.context.authtoken
	local id = uci:get("oem", "board", "id"):gsub(":", "")
	local md5_data=util.exec("echo -n \""..token_sys..sim_pwd.."\"|md5sum|cut -b -32|xargs echo -n") or ""
	local pwd_md5=util.exec("nradio_crypto -t \""..id..sim_security.."\"") or ""

	if pwd_md5 == sim_pwd then
		if md5_data and #md5_data > 0 then
			luci.dispatcher.context.simtoken = md5_data
			util.ubus("session", "set", {
				ubus_rpc_session = luci.dispatcher.context.authsession,
				values = {
					simtoken = md5_data
				}
			})
			luci.nradio.luci_call_result({code=0})
			return
		end
	end
	luci.nradio.luci_call_result({code=-1})
end


function action_simlock()
	local token_tmp = luci.http.formvalue("simtoken")
	local session_data = luci.dispatcher.context.authsession or ""
	local simtoken=""
	local sdat = util.ubus("session", "get", {ubus_rpc_session=session_data, keys = {"simtoken"}})
	if sdat and sdat.values and sdat.values.simtoken then
		simtoken=sdat.values.simtoken
	end

	if simtoken and #simtoken > 0 and simtoken == token_tmp then
		local device_info = util.ubus("combo","simslot", { type="clear"} ) or { }
		luci.nradio.luci_call_result({code=0})
	else
		luci.nradio.luci_call_result({code=-1})
	end
end

function action_simstatus()
	local count_cpe = nr.count_cpe()
	local sim_data = {simstatus={}}
	local cpe_count = 0
	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" then
				cpe_count=cpe_count+1
			end
		end
	)
	local sims_alias = nr.get_sim_alias()
	for i = 0, count_cpe - 1 do

		local index = (i == 0 and "" or tostring(i))
		local sim_section="sim"..index
		local iccid_section="iccid"..index
		local stype = util.split(uci:get("cpesel", sim_section, "stype") or "0", ",")
		local max = tonumber(uci:get("cpesel", sim_section, "max") or 1)

		local inner_iccid = util.split(uci:get("oem", "board", iccid_section) or "", ",")
		local simslot_iccid = util.split(util.exec("bdinfo -g simslot") or "" or "", ",")
		local sim_alias = ""

		if sims_alias then
			sim_alias=sims_alias[i+1]
		end

		inner_sim_index=0
		simslot_index=0
		for j = 1, max do
			local iccid_info = {simalias="",iccid="",status=0,simslot=0}
			iccid_info.simalias = sim_alias[j]
			iccid_info.status = 0

			if stype[j] ~= "0" then
				inner_sim_index=inner_sim_index+1
				if inner_sim_index <= #inner_iccid and #inner_iccid[inner_sim_index] > 0 then
					iccid_info.iccid = inner_iccid[inner_sim_index]
					iccid_info.status = 1
				else
					iccid_info.iccid = ""
				end
			else
				simslot_index=simslot_index+1
				iccid_info.simslot = 1
				if simslot_index <= #simslot_iccid and #simslot_iccid[simslot_index] > 0 then
					iccid_info.iccid = simslot_iccid[simslot_index]
					iccid_info.status = 1
				else
					iccid_info.iccid = ""
				end
			end
			sim_data.simstatus[#sim_data.simstatus + 1] = iccid_info
		end
	end

	nr.luci_call_result(sim_data)
end
