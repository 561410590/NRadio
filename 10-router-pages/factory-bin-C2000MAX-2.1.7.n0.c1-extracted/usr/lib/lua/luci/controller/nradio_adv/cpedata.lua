-- Copyright 2018 NRadio
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.nradio_adv.cpedata", package.seeall)

local nr = require "luci.nradio"

function index()
	if not luci.nradio.support_self_speedlimit() then		
		return 
	end 
	local uci = require "luci.model.uci".cursor()
	local count_cpe = luci.nradio.count_cpe()
	if count_cpe <= 0 then
		return
	end
	
	page = entry({"nradioadv", "network", "cpedata"},alias("nradio", "cellular", "cpedata") , _("SwitchTitle"), 201, true)
	page.show = true
	page.icon = "nradio-cpedata"
	entry({"nradio", "cellular", "cpedata"}, template("nradio_cpedata/cpedata"), nil, nil, true)
	entry({"nradio", "cellular", "cpedata","refresh"}, call("cpedata_refresh_data"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpedata","save"}, call("cpedata_save"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpedata","clean"}, call("cpedata_clean"), nil, nil, true).leaf = true
	entry({"nradio","cellular","cpedata","model"}, call("get_cellular_template"), nil, nil, true).leaf = true
end

function get_cellular_template()
	luci.nradio.get_cellular_template()
end

function cpedata_clean()
	local util = require "luci.util"
	local channel = luci.http.formvalue("channel")
	local cur = luci.http.formvalue("cur")
	local threshold_type = luci.http.formvalue("type")
	local cleandata = {cur=cur,threshold_type=threshold_type,channel=channel}
	local result = util.ubus("combo", "threshold_clean", cleandata) or {code="2"}
	luci.nradio.luci_call_result(result)
end

function cpedata_refresh_data()
	local channel = luci.http.formvalue("channel")
	luci.nradio.luci_call_result(cpedata_refresh(channel))
	return
end
function cpedata_refresh(channel)
	local uci  = require "luci.model.uci".cursor()
	local nr = require "luci.nradio"
	local util = require "luci.util"	
	local sims_alias = nr.get_sim_alias()
	local simsdata_info = {}
	local simsdata_all = {}
	local net_prefer=uci:get("network","globals", "net_prefer") or ""
	simsdata_info.net_key = nr.get_nettype_nbcpe(net_prefer)
	local simsdata = {}
	local model_str,cpe_section,model_index = nr.get_cellular_last(channel)

	local sims_alias_item = nil
	if sims_alias then
		sims_alias_item=sims_alias[model_index]
	end

	local cpesel_section="sim"..model_str	
	local max = tonumber((uci:get("cpesel",cpesel_section, "max")) or 1)
	for i = 1, max do
		local simsdata_item = {}
		local cpesim_section=cpe_section.."sim"..i
		simsdata_item.index = i
		if not sims_alias_item then
			simsdata_item.alias = i
		else
			simsdata_item.alias = sims_alias_item[i]
		end

		local cpesim_info = uci:get_all("cpecfg",cpesim_section) or {}
		local mode = uci:get("network",cpe_section,"mode")
		simsdata_item.modelname = cpe_section
		simsdata_item.modelmode = mode
		simsdata_item.signal = cpesim_info.signal or ""
		simsdata_item.enabled = tonumber(cpesim_info.enabled or 1)
		simsdata_item.threshold_type = tonumber(cpesim_info.threshold_type or 0)
		simsdata_item.threshold_data = tonumber(cpesim_info.threshold_data or 0)
		simsdata_item.threshold_date = cpesim_info.threshold_date or ""
		simsdata_item.threshold_smds = tonumber(cpesim_info.threshold_smds or 0)
		simsdata_item.threshold_cds = tonumber(cpesim_info.threshold_cds or 0)
		simsdata_item.threshold_percent = tonumber(cpesim_info.threshold_percent or 100)
		simsdata_item.threshold_enabled = tonumber(cpesim_info.threshold_enabled or 0)
		simsdata_item.cross_datetime = tonumber(cpesim_info.cross_datetime or 0)
		simsdata_item.cross_flow = tonumber(cpesim_info.cross_flow or 0)
		simsdata_item.name = cpesim_info.name or ""
		simsdata[#simsdata+1] = simsdata_item
	end
	simsdata_all[#simsdata_all+1] = simsdata
	simsdata_info.data = simsdata_all
	return simsdata_info
end
function cpedata_save()
	local input_data = luci.http.formvalue() or nil
	local util = require "luci.util"
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	local exsit_commit = false
	local cpe_section = nil
	if input_data then
		for key,item in pairs(input_data) do
			
			local key_arr = util.split(key, '_')
			if key_arr and #key_arr >= 3 then				
				local modelname = key_arr[1]
				local simid = key_arr[2]
				local prefix_buffer = modelname.."_"..simid.."_"
				local targetname = key:sub(key:find(prefix_buffer)+#prefix_buffer)
				local section_key = modelname.."sim"..simid
				
				nixio.syslog("err","section_key:"..section_key..",targetname:"..targetname)
				uci:set("cpecfg",section_key,"cpesim")
				uci:set("cpecfg", section_key, targetname, item)
				uci:save("cpecfg")
				cpe_section = modelname
				exsit_commit = true
			end
		end
	end
	if exsit_commit then
		uci:commit("cpecfg")
		util.exec("/etc/init.d/combo restart")
		if cpe_section then
			cpe_section = cpe_section:gsub("[;'\\\"]", "")
		end
		nr.app_write_cpedata(cpe_section)
		nixio.nanosleep(2)
	end
end