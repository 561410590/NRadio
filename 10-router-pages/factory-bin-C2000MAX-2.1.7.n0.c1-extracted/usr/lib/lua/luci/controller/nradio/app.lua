-- Copyright 2017 NRadio

module("luci.controller.nradio.app", package.seeall)

local uci = require "luci.model.uci".cursor()
local fs = require "nixio.fs"
local nr = require "luci.nradio"
local util = require "luci.util"
local cjson = require "cjson.safe"
local cellular_prefix,cellular_default = nr.get_cellular_prefix()

function app_htmlauth(validator, accs, default, template)
	luci.http.prepare_content("application/json")
	luci.http.write('{ "code":"1"}') 
	return false
end

function index()
	local page = entry({"nradio", "app"}, alias("nradio", "app","heartbeat"), nil, nil, true)

	entry({"nradio", "app", "heartbeat"}, call("action_heartbeat"), nil, nil, true).leaf = true
	entry({"nradio", "app", "signal"}, call("action_get_signal"), nil, nil, true).leaf = true
	entry({"nradio", "app", "cmd"}, call("action_system_cmd"), nil, nil, true).leaf = true
	entry({"nradio", "app", "info"}, call("action_get_info"), nil, nil, true).leaf = true
	entry({"nradio", "app", "wifi"}, call("action_system_wifi"), nil, nil, true).leaf = true
	entry({"nradio", "app", "cpesel"}, call("action_system_cpesel"), nil, nil, true).leaf = true
	entry({"nradio", "app", "client"}, call("action_system_client"), nil, nil, true).leaf = true
	entry({"nradio", "app", "combo"}, call("action_system_combo"), nil, nil, true).leaf = true
	entry({"nradio", "app", "neighbour"}, call("action_neighbour_cellular"), nil, nil, true).leaf = true
	entry({"nradio", "app", "earfcn"}, call("action_earfcn"), nil, nil, true).leaf = true
	entry({"nradio", "app", "sms"}, call("action_sms"), nil, nil, true).leaf = true
	entry({"nradio", "app", "apn"}, call("action_apn"), nil, nil, true).leaf = true
	entry({"nradio", "app", "sync"}, call("action_sync"), nil, nil, true).leaf = true
	entry({"nradio", "app", "lan"}, call("action_lan"), nil, nil, true).leaf = true
	entry({"nradio", "app", "status"}, call("action_status"), nil, nil, true).leaf = true
	entry({"nradio", "app", "speed"}, call("action_speed_info"), nil, nil, true).leaf = true
	entry({"nradio", "app", "password"}, call("action_set_password"), nil, nil, true).leaf = true
	entry({"nradio", "app", "wifiauth"}, call("action_set_wifiauth"), nil, nil, true).leaf = true
end


function action_heartbeat()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp then
		nixio.syslog("err","action_heartbeat :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = "0"
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
	end
end

function action_get_signal()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp then
		--nixio.syslog("err","action_signal :"..cjson.encode(data))
		local cpestatus_result = util.ubus("infocd","cpestatus") or { }
		local cur = uci
		local cpe_count = 0
		local using_exsit = 0;
		local cpeindex = data.index or "1"
		local cpecfg_name = cellular_default
		local at_signal = data.at_signal or false
		uci:foreach("network", "interface",
			function(s)
				if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
					cpe_count=cpe_count+1
					if tonumber(cpeindex) == cpe_count then
						cpecfg_name = s[".name"]
					end
					if at_signal ~= 1 then
						if not json_data.signal then
							json_data.signal = {}
						end
						json_data.signal[cpe_count] = {using=false,signal=-999}
					end
				end
			end
		)
		if at_signal == 1 then
			json_data.at_signal={}
			local at_signal_info = util.exec("cpetools.sh -i "..cpecfg_name.." -c signal")
			if at_signal_info and #at_signal_info > 0 then
				 local at_signal_obj = cjson.decode(at_signal_info) or {}
				 if at_signal_obj.MODE then
					local at_signal_detail = at_signal_obj[at_signal_obj.MODE] or {}
					for key,v in pairs(at_signal_detail) do
						json_data.at_signal[key:lower()] = tostring(v)
					end
				 end				 
			end
		else
			if cpestatus_result.result and #cpestatus_result.result > 0 then
				local last_using_index = 1
				for _,item in pairs(cpestatus_result.result) do
					cpestatus = item.status
					local index = cpestatus.name:match(cellular_prefix.."(%d*)")
					if (index == nil) or (index == "") or (tonumber(index) == 0 ) then
						index=1
					else
						index=tonumber(index)+1
					end
					if index <= cpe_count then
						json_data.signal[index] = cpestatus
						if item.up and tonumber(item.up) == 1 then
							if using_exsit ~= 1 then
								using_exsit=1;
								last_using_index = index
								json_data.signal[index].using = true;
							elseif last_using_index > index then
								json_data.signal[index].using = true;
								json_data.signal[last_using_index].using = false;
								last_using_index=index
							end
						end
						
						json_data.signal[index].netlink = get_net_link(cpestatus.name)
						json_data.signal[index].cpeno = index
						json_data.signal[index].cellid = cpestatus.cell or "-"			

						if cpestatus.mode == "LTE" or cpestatus.mode:match("NR") then
							if cpestatus.rsrp and (#cpestatus.rsrp > 0) and tonumber(cpestatus.rsrp) < 0 then
								json_data.signal[index].signal=tonumber(cpestatus.rsrp)
							end
						elseif cpestatus.mode == "WCDMA" or cpestatus.mode == "TD-SCDMA" or cpestatus.mode == "GSM" or cpestatus.mode == "CDMA" then
							if cpestatus.rssi and (#cpestatus.rssi > 0) and tonumber(cpestatus.rssi) < 0 then
								json_data.signal[index].signal=tonumber(cpestatus.rssi)
							end
						end
						if cpe_count == 1 then
							json_data.signal[index].using = true;
							using_exsit = 1;
						end
					end
				end
				if using_exsit == 0 then
					json_data.signal[1].using = true;
				end
			end
			if #json_data.signal == 0 then
				json_data.signal[1] = {}
			end
		end

		json_data.trans_id = data.trans_id
		json_data.code = "0"
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
	end	
end

function action_system_cmd()
	local data = luci.nradio.app_decrypto()
	local json_data = {code=0,trans_id=""}
	if data and data.trans_id and data.timestamp and data.cmd then		
		if data.cmd == "reboot" then
			json_data.trans_id = data.trans_id
			nixio.syslog("err","action_cmd :"..cjson.encode(data))			
			json_data.code = "0"
			luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
			luci.nradio.fork_exec("sleep 1;reboot")
		elseif data.cmd == "service" then			
			nixio.syslog("err","action_cmd service:"..cjson.encode(data))
			json_data = luci.nradio.deal_service(data)
			json_data.trans_id = data.trans_id
			luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
		end
	end
end

local function gettval(value)
	return value and value:sub(2) or ""
end
local function splitval(value)
	if value then
		local arr = util.split(value, "=", 2)
		return arr[2]
	end

	return nil
end

local function get_wifi_cnt()
	local id = uci:get("oem", "board", "id")
	if id then
		id = id:gsub(":", "")
	end
	local cl = require "luci.model.cloudd".init()
	local cdev = cl.get_device(id, "master")
	local slaves = cdev:slaves_sort()
	local count = 0
	for i = 1, #slaves do
		local slave = slaves[i]
		local radio_cnt = slave:get_radiocnt()
		local radio_band2 = (radio_cnt.band2 or 1)
		local radio_band5 = (radio_cnt.band5 or 1)
		count = count + radio_band2 + radio_band5
	end
	return count
end

local function get_wifi_info()
	local wifi_array = {}
	local diff_2_4_wlan = uci:get("cloudd", "t0", "diff_2_4_wlan") or "X0"
	if diff_2_4_wlan == "X1" then --关闭合一
		local id = uci:get("oem", "board", "id")
		if id then
			id = id:gsub(":", "")
		end
		local cl = require "luci.model.cloudd".init()
		local cdev = cl.get_device(id, "master")
		local slaves = cdev:slaves_sort()
		for i = 1, #slaves do
			local slave = slaves[i]
			local radio_cnt = slave:get_radiocnt()
			local group = slave:group()
			local tpl_list = uci:get_all("cloudd",group, "template") or {}
			local radio_band2 = (radio_cnt.band2 or 1)
			local radio_band5 = (radio_cnt.band5 or 1)

			for j = 1, radio_band2 + radio_band5 do
				local band5 = true
				local index = j - 1
				local tabname = "5G"
				local wlan
				local radio
				local tX = tpl_list[index + 1] or "t0"
				local tcfg = uci:get_all("cloudd",tX) or {}
				local ssid_tpl_val
				local wifi_item = {rule_name=""}
				local hidden_val = false
				local max_link = 0
				if radio_band2 ~= 0 then
					wlan = "wlan"..index
					radio = "radio"..index
				else
					wlan = "wlan"..(index + 1)
					radio = "radio"..index
				end

				ssid = uci:get("cloudd", group.."wlan", "ssid_"..wlan) or ""
				ssid_tpl_val = gettval(tcfg["ssid_wlan"])

				local wifi_5g_label = "-5G"
				local wifi_24g_label = "-2.4G"
				local wifi_label = wifi_24g_label
				local wifi_reverse_label = wifi_5g_label
				if index < radio_band2 then
					wifi_label=wifi_5g_label
					wifi_reverse_label=wifi_24g_label
				end
				if (#ssid_tpl_val > (#wifi_label + 1) and string.sub(ssid_tpl_val, -#wifi_label) == wifi_label) then
					ssid_tpl_val = string.sub(ssid_tpl_val, 1,-(#wifi_label+1))..wifi_reverse_label
				elseif (#ssid_tpl_val > (#wifi_reverse_label + 1) and string.sub(ssid_tpl_val, -#wifi_reverse_label) == wifi_reverse_label) then

				else
					ssid_tpl_val = ssid_tpl_val..wifi_reverse_label
				end

				if #ssid > 0 then
					ssid = splitval(ssid)
				else
					ssid = ssid_tpl_val
				end

				wpakey = uci:get("cloudd", group.."wlan", "key_"..wlan) or ""
				wpakey_tpl_val = gettval(tcfg["key_wlan"])
				if #wpakey > 0 then
					wpakey = splitval(wpakey)
				else
					wpakey = wpakey_tpl_val
				end

				channel = uci:get("cloudd", group.."radio", "channel_"..radio) or ""
				channel_tpl_val = 'auto'
				if #channel > 0 then
					channel = splitval(channel)
				else
					channel = channel_tpl_val
				end

				encryption = uci:get("cloudd", group.."wlan", "encryption_"..wlan) or ""
				encryption_tpl_val = gettval(tcfg["encryption_wlan"])
				if #encryption > 0 then
					encryption = splitval(encryption)
				else
					encryption = encryption_tpl_val
				end

				disabled = uci:get("cloudd", group.."wlan", "disabled_"..wlan) or ""
				disabled_tpl_val = gettval(tcfg["disabled_wlan"])
				if #disabled > 0 then
					disabled = splitval(disabled)
				else
					disabled = disabled_tpl_val
				end

				maxstanum = uci:get("cloudd", group.."wlan", "maxstanum_"..wlan) or ""
				maxstanum_tpl_val = gettval(tcfg["maxstanum_wlan"])
				if #maxstanum > 0 then
					maxstanum = splitval(maxstanum)
				else
					maxstanum = maxstanum_tpl_val
				end

				if type(maxstanum) == "string" and #maxstanum > 0 then
					max_link = tonumber(maxstanum)
				elseif type(maxstanum) == "number" then
					max_link = maxstanum
				end

				hidden_wlan_val = uci:get("cloudd", group.."wlan", "hidden_"..wlan) or ""
				hidden_tpl_val = gettval(tcfg["hidden_wlan"])
				if #hidden_wlan_val > 0 then
					hidden_wlan_val = splitval(hidden_wlan_val)
				else
					hidden_wlan_val = hidden_tpl_val
				end
				if hidden_wlan_val and hidden_wlan_val == "1" then
					hidden_val = "1"
				else
					hidden_val = "0"
				end

				wifi_item.max_link=max_link
				wifi_item.hidden=hidden_val
				wifi_item.ssid = ssid
				wifi_item.password = wpakey
				wifi_item.encryption = encryption
				wifi_item.channel = channel
				wifi_item.disabled = disabled
				wifi_item.rule_name = wlan

				wifi_array[#wifi_array+1]=wifi_item

			end
		end
	else
		cnt = get_wifi_cnt()
		if cnt == 1 then
			channel = uci:get("cloudd", "g1radio", "channel_radio0") or ""
			channel_tpl_val = 'auto'
			if #channel > 0 then
				channel = splitval(channel)
			else
				channel = channel_tpl_val
			end
		end

		local wifi_item = {ssid="",password="",rule_name="t0",hidden="",encryption="",channel="",disabled=""}
		un_ssid = uci:get("cloudd", "t0", "ssid_wlan") or ""
		if #un_ssid > 1 then
			un_ssid = string.sub(un_ssid, 2)
			wifi_item.ssid=un_ssid
		end

		encryption_wlan = uci:get("cloudd", "t0", "encryption_wlan") or ""
		if #encryption_wlan > 1 then
			encryption_wlan = string.sub(encryption_wlan, 2)
			wifi_item.encryption=encryption_wlan
		end

		key_wlan = uci:get("cloudd", "t0", "key_wlan") or ""
		if #key_wlan > 1 then
			key_wlan = string.sub(key_wlan, 2)
			wifi_item.password=key_wlan
		end

		disabled_wlan = uci:get("cloudd", "t0", "disabled_wlan") or ""
		if #disabled_wlan > 1 then
			disabled_wlan = string.sub(disabled_wlan, 2)
			wifi_item.disabled=disabled_wlan
		end

		maxstanum_wlan = uci:get("cloudd", "t0", "maxstanum_wlan") or ""
		if #maxstanum_wlan > 1 then
			maxstanum_wlan = string.sub(maxstanum_wlan, 2)
			if type(maxstanum_wlan) == "string" and #maxstanum_wlan > 0 then
				wifi_item.max_link = tonumber(maxstanum_wlan)
			elseif type(maxstanum_wlan) == "number" then
				wifi_item.max_link = maxstanum_wlan
			end
		end

		hidden_wlan_val = uci:get("cloudd", "t0", "hidden_wlan") or ""
		if #hidden_wlan_val > 1 then
			hidden_wlan_val = string.sub(hidden_wlan_val, 2)
		end
		if hidden_wlan_val and hidden_wlan_val == "1" then
			wifi_item.hidden="1"
		else
			wifi_item.hidden="0"
		end
		if channel and #channel > 0 then
			wifi_item.channel = channel
		end
		wifi_array[#wifi_array+1]=wifi_item
	end
	if #wifi_array == 0 then
		wifi_array[1] = {}
	end
	return wifi_array
end
function action_neighbour_cellular()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={neighbour={}}}
	if data and data.trans_id and data.timestamp then
		json_data.trans_id = data.trans_id
		json_data.code = "0"

		json_data.result.neighbour = nr.get_cellular_neighbour(nil,data.type,data.force)
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end
end


function action_earfcn()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={index=""}}

	if data and data.trans_id and data.timestamp then
		nixio.syslog("err","earfcn :"..cjson.encode(data))
		local mode_reload = 0
		local earfcn_reload = 0
		local band_reload = 0
		local cpe_name=""
		local freq_result
		local base_data = nr.get_base_data(data)
		local adv_reload = false
		cpe_name = base_data.cpe_name
		json_data.trans_id = data.trans_id
		json_data.code = "0"
		json_data.result.index = base_data.index
		if data.action then
			json_data.result.action = tonumber(data.action)
		end
		
		base_data.support_band = false
		json_data.result.sim = tonumber(data.sim or base_data.now_sim)

		if nr.support_lock_freq(cpe_name) then
			base_data.support_band = true
		end
		base_data.earfreq_work_mode = uci:get(base_data.network_file,cpe_name,"earfreq_mode") or ""
		base_data.support_earfcn5 = uci:get(base_data.network_file,cpe_name,"earfcn5") or false
		base_data.support_earfcn4 = uci:get(base_data.network_file,cpe_name,"earfcn4") or false

		if data.type == "all" then
			adv_reload = nr.do_cellular_adv_cpedata(base_data,data.adv)
		else
			adv_reload = nr.do_cellular_adv(base_data,data.adv)
		end
		local mode_reload = nr.do_cellular_mode(base_data,data.mode)
		local earfreq_mode_reload = nr.do_cellular_earfreq_mode(base_data,data.earfreq_mode)
		if data.band then
			band_reload = nr.do_cellular_band(base_data,data.band)
		end
		if data.earfcns and #data.earfcns > 0 then
			earfcn_reload=nr.do_cellular_earfcns(base_data,data.earfcns)
		else
			if json_data.result.action and ((json_data.result.action == 0) or (json_data.result.action == 1)) then
				earfcn_reload=nr.do_cellular_earfcn(tonumber(data.action),base_data,data.earfcn)
			end
		end

		if mode_reload or earfcn_reload or band_reload or earfreq_mode_reload or adv_reload then			
			if base_data.sim_diff == 0 and not base_data.only_save then
				util.exec("ifup "..cpe_name.." >/dev/null")
			end
		end

		freq_result = nr.get_earfcn_data(base_data)
		if freq_result.earfcn then
			json_data.result.earfcn = freq_result.earfcn
		end
		if freq_result.band then
			json_data.result.band = freq_result.band
		end
		if freq_result.mode then
			json_data.result.mode = freq_result.mode
		end
		if data.from ~= "NRFAMILY" and data.from ~= "LOCAL" then
			local model_str,cpe_section = nr.get_cellular_last(cpe_name)
			local sim_section="sim"..model_str
			local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"
			 local simcfg_section = cpe_section.."sim"..cur_sim
            nr.app_write_earfcn(cpe_section,cur_sim,simcfg_section)
            nr.set_n79_relate(cpe_section)
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end
end

function action_apn()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={}}

	if data and data.trans_id and data.timestamp then
		 nixio.syslog("err","apn :"..cjson.encode(data))
		local base_data = nr.get_base_data(data)
		json_data.trans_id = data.trans_id
		json_data.code = "0"
		json_data.result.index = base_data.index
		if data.action then
			json_data.result.action = tonumber(data.action)
		end

		json_data.result.sim = tonumber(data.sim or base_data.now_sim)
		
		local apn_reload = nr.do_cellular_apn(base_data,data)
		if apn_reload then
			if base_data.sim_diff == 0 then
				if tonumber(data.action) == 0 or (data.sim_profile and #data.sim_profile == 0) then
					nr.reload_apn_used(data.profile or "app","del",base_data.cpecfg_name,data.from)
				else
					nr.reload_apn_used(data.profile or "app","add",base_data.cpecfg_name,data.from)
				end
			end
		end

		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end
end

function get_cellular_info()
	local cellular_array = {}
	
	local cpestatus_result = util.ubus("infocd","cpestatus") or { }
	local cpe_count = 0
	
	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"] ) then
				local cellular = {earfcn="",pci=""}
				cpe_count=cpe_count+1
				cellular.freq_val = s.freq_val or ""
				cellular.freq_multi = s.freq_multi or ""
				cellular.earfreq_mode = s.earfreq_mode or ""
				cellular.nrcap = s.nrcap and tonumber(s.nrcap) or 0
				cellular.nrrc = s.nrrc and tonumber(s.nrrc) or 0
				if nr.support_cellular_ippass(s[".name"]) then
					cellular.ippass = s.ippass and tonumber(s.ippass) or 0
				end
				cellular.blacklist_band = s.blacklist_band or ""
				cellular.compatibility = s.compatibility and tonumber(s.compatibility) or 0
				cellular.automatic = s.automatic and tonumber(s.automatic) or 0
				cellular.sms = s.sms and tonumber(s.sms) or 0
				cellular.command_equal = s.command_equal and tonumber(s.command_equal) or 0
				cellular.mobility = s.mobility and tonumber(s.mobility) or 0
				cellular.freq_text = s.freq_text and tonumber(s.freq_text) or ""

				cellular.simisolate = 1
				if s.earfcn5 then
					local earfcn5_array = util.split(s.earfcn5, ",") or {"0","0","0"}
					local earfcn5_obj = {band="0",pci="0",mode="0"}
					earfcn5_obj.band = earfcn5_array[1] or "0"
					earfcn5_obj.pci = earfcn5_array[2] or "0"
					earfcn5_obj.mode = earfcn5_array[3] or "0"
					cellular.earfcn5 = earfcn5_obj
				end
				if s.earfcn4 then
					local earfcn4_array = util.split(s.earfcn4, ",") or {"0","0","0"}
					local earfcn4_obj = {band="0",pci="0",mode="0"}
					earfcn4_obj.band = earfcn4_array[1] or "0"
					earfcn4_obj.pci = earfcn4_array[2] or "0"
					earfcn4_obj.mode = earfcn4_array[3] or "0"
					cellular.earfcn4 = earfcn4_obj
				end
				
				cellular_array[cpe_count] = cellular

			end
		end
	)
	if cpestatus_result.result and #cpestatus_result.result > 0 then
		for _,item in pairs(cpestatus_result.result) do
			cpestatus = item.status
			local index = cpestatus.name:match(cellular_prefix.."(%d*)")
			if (index == nil) or (index == "") or (tonumber(index) == 0 ) then
				index=1
			else
				index=tonumber(index)+1
			end
			
			if index <= cpe_count then
				cellular_array[index].earfcn=cpestatus.earfcn
				cellular_array[index].pci=cpestatus.pci				
			end
			nixio.syslog("err",cjson.encode(cellular_array[index]))
		end
	end
	if #cellular_array == 0 then
		cellular_array[1] = {earfcn="",pci=""}
	end

	return cellular_array
end

function get_bat_info()
	local value = {percent="-1",charging=false}
	return value
end

function get_cpecfg_info()
	local cpecfg = {}
	local cpe_count = 0

	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
				cpe_count=cpe_count+1
				cpecfg[cpe_count] = {}
			end
		end
	)
	uci:foreach("cpesel", "cpesel",
		function(s)
			local inner_index = 1
			local index = s[".name"]:match("sim(%d*)")
			local cpepre = ""
			local max = s["max"] or "1"
			if (index == nil) or (index == "") or (tonumber(index) == 0 ) then
				index=1
			else
				index=tonumber(index)+1
			end

			local cpe_section=(index == 1 and cellular_default or cellular_prefix..index)
			if index <= cpe_count then
				for i = 1, tonumber(max) do
					local simcfg = uci:get_all("cpecfg", cpe_section.."sim"..i) or {}
					local item = {}
					item.roaming = simcfg.roaming or ""			
					item.ippass = simcfg.ippass or ""
					item.mobility = simcfg.mobility or ""
					item.freq_time = simcfg.freq_time or ""
					item.endtime = simcfg.endtime or ""
					item.starttime = simcfg.starttime or ""				
					item.peak_hour = simcfg.peak_hour or "0"
					item.peaktime = simcfg.peaktime or ""

					item.freqmode = simcfg.mode or "auto"
					item.earfreq_mode = simcfg.earfreq_mode or ""
					item.freq5 = {}
					item.freq5.enabled = simcfg.custom_earfcn5 or "0"
					item.freq5.earfcn = simcfg.earfcn5 or ""
					item.freq5.pci = simcfg.pci5 or ""
					item.freq5.band = simcfg.band5 or ""
					item.freq4 = {}
					item.freq4.enabled = simcfg.custom_earfcn4 or "0"
					item.freq4.earfcn = simcfg.earfcn4 or ""
					item.freq4.pci = simcfg.pci4 or ""
					item.band = {}
					item.band.enabled = simcfg.custom_freq or "0"
					item.band.freq = simcfg.freq or ""
					item.apn_cfg = simcfg.apn_cfg or ""
					item.force_ims = simcfg.force_ims or ""
					item.compatibility = simcfg.compatibility or ""
					item.nrrc = simcfg.nrrc or ""
					item.compatible_nr = simcfg.compatible_nr or ""
					item.fallbackToR16 = simcfg.fallbackToR16 or ""
					item.fallbackToLTE = simcfg.fallbackToLTE or ""


					if simcfg.threshold_enabled then
						item.threshold_enabled = simcfg.threshold_enabled
					end
					if simcfg.threshold_type then
						item.threshold_type = simcfg.threshold_type
					end
					if simcfg.threshold_data then
						item.threshold_data = simcfg.threshold_data
					end
					if simcfg.threshold_percent then
						item.threshold_percent = simcfg.threshold_percent
					end
					if simcfg.threshold_date then
						item.threshold_date = simcfg.threshold_date
					end
					if simcfg.signal then
						item.signal = simcfg.signal
					end
					if simcfg.enabled then
						item.enabled = simcfg.enabled
					end
					cpecfg[index][tostring(i)] = item
				end
			end
		end
	)

	if #cpecfg == 0 then
		cpecfg[1] = {}
	end
	return cpecfg
end	
function get_cpesel_info()
	local cpesel = {}
	local cpe_count = 0
	local inner_iccid_arr = {}
	local oem_data = uci:get_all("oem", "board") or {}
	for k,v in pairs(oem_data) do
		if k:match("iccid(%d*)") then
			local iccid_array = util.split(v, ",")
			local iccid_item = {}
			if iccid_array and #iccid_array >= 1 then
				for _,iccid_v in pairs(iccid_array) do
					iccid_item[#iccid_item+1] = iccid_v
				end
				inner_iccid_arr[#inner_iccid_arr+1] = iccid_item
			end
		end
	end

	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
				cpe_count=cpe_count+1
				cpesel[cpe_count] = {cur=1,type=""}
			end
		end
	)
	uci:foreach("cpesel", "cpesel",
		function(s)
			local inner_index = 1
			local index = s[".name"]:match("sim(%d*)")
			local cpepre = ""
			
			if (index == nil) or (index == "") or (tonumber(index) == 0 ) then
				index=1
			else
				index=tonumber(index)+1
			end

			local cpe_section=(index == 1 and cellular_default or cellular_prefix..index)
			if index <= cpe_count then
				cpesel[index].cur = s.cur or 1
				cpesel[index].cur = tonumber(cpesel[index].cur)
				cpesel[index].type = s.stype or "0"
				cpesel[index].default = s.default or "1"
				cpesel[index].gval = s.gval or ""
				cpesel[index].stype = s.stype or ""
				cpesel[index].adv_sim = s.adv_sim or "0"
				if s.max then
					cpesel[index].max = s.max or ""
				end
				cpesel[index].iccid = inner_iccid_arr[index] or {""}
				local simcfg = uci:get_all("cpecfg", cpe_section.."sim"..cpesel[index].cur) or {}
				if s.mode and #s.mode > 0 then
					cpesel[index].mode = tonumber(s.mode)
				else
					cpesel[index].mode = 0
				end

				cpesel[index].roaming = simcfg.roaming or ""
				cpesel[index].apn_cfg = simcfg.apn_cfg or ""				
				cpesel[index].ippass = simcfg.ippass or ""
				cpesel[index].mobility = simcfg.mobility or ""
				cpesel[index].freq_time = simcfg.freq_time or ""
				cpesel[index].endtime = simcfg.endtime or ""
				cpesel[index].starttime = simcfg.starttime or ""				
				cpesel[index].peak_hour = simcfg.peak_hour or "0"
				cpesel[index].peaktime = simcfg.peaktime or ""

				cpesel[index].freqmode = simcfg.mode or "auto"
				cpesel[index].earfreq_mode = simcfg.earfreq_mode or ""
				cpesel[index].freq5 = {}
				cpesel[index].freq5.enabled = simcfg.custom_earfcn5 or "0"
				cpesel[index].freq5.earfcn = simcfg.earfcn5 or ""
				cpesel[index].freq5.pci = simcfg.pci5 or ""
				cpesel[index].freq5.band = simcfg.band5 or ""
				cpesel[index].freq4 = {}
				cpesel[index].freq4.enabled = simcfg.custom_earfcn4 or "0"
				cpesel[index].freq4.earfcn = simcfg.earfcn4 or ""
				cpesel[index].freq4.pci = simcfg.pci4 or ""
				cpesel[index].band = {}
				cpesel[index].band.enabled = simcfg.custom_freq or "0"
				cpesel[index].band.freq = simcfg.freq or ""
				cpesel[index].apn = {}
				if simcfg.apn_cfg and #simcfg.apn_cfg > 0 then
					local simapncfg = uci:get_all("apn", simcfg.apn_cfg) or {}
					cpesel[index].apn.enabled = simapncfg.custom_apn or "0"
					cpesel[index].apn.name = simapncfg.apn or ""
					cpesel[index].apn.username = simapncfg.username or ""
					cpesel[index].apn.password = simapncfg.password or ""
					cpesel[index].apn.auth = simapncfg.auth or ""
					cpesel[index].apn.pdptype = simapncfg.pdptype or ""
				else
					cpesel[index].apn.enabled = simcfg.custom_apn or "0"
					cpesel[index].apn.name = simcfg.apn or ""
					cpesel[index].apn.username = simcfg.username or ""
					cpesel[index].apn.password = simcfg.password or ""
					cpesel[index].apn.auth = simcfg.auth or ""
					cpesel[index].apn.pdptype = simcfg.pdptype or ""
				end
			end
		end
	)

	if #cpesel == 0 then
		cpesel[1] = {}
	end
	return cpesel
end
function get_apn_info()
	local apnlist = {}
	local filename = nr.get_apn_filename(cellular_default)
	uci:foreach(filename, "rule",
		function(s)
			s[".anonymous"] = nil
			s[".type"] = nil
			s[".index"] = nil
			apnlist[#apnlist+1] = s
		end
	)

	return apnlist
end
function get_net_link(ifaces)
	local base_path="/var/run/wanchk/iface_state/"
	local netlink = 0
	local iface_array = util.split(ifaces, " ")

	for i = 1, #iface_array do
		local net_name=iface_array[i]
		local net_result = fs.readfile(base_path..net_name)
		
		if net_result and #net_result then
			if net_result == "up" then
				netlink = 1
			end
		end
	end

	return netlink
end

function get_diagnosis()
	local json_data = {speedlimit=0,list={}}
	local cpestatus_result = util.ubus("infocd","cpestatus") or { }
	local cpe_count = 0
	local using_exsit = 0;
	local speedlimit_info = util.ubus("infocd", "get", { name = "speedevent" }) or {list={}}

	for _,item in pairs(speedlimit_info.list) do
		local speed_data = item.parameter.speedevent_record or {}
		if speed_data and speed_data.happend == true then
			json_data.speedlimit = 1
		end
		break		
	end

	local wans_name = "wan".." "..cellular_default

	json_data.netlink = get_net_link(wans_name)
	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
				cpe_count=cpe_count+1
				json_data.list[cpe_count] = {using=false,nosignal=1,model=1,register=1,sim=1,isp=""}
			end
		end
	)
	if cpestatus_result.result and #cpestatus_result.result > 0 then
		local last_using_index = 1
		for _,item in pairs(cpestatus_result.result) do
			cpestatus = item.status
			local index = cpestatus.name:match(cellular_prefix.."(%d*)")
			if (index == nil) or (index == "") or (tonumber(index) == 0 ) then
				index=1
			else
				index=tonumber(index)+1
			end
			if index <= cpe_count then
				if item.up and tonumber(item.up) == 1 then
					if using_exsit ~= 1 then
						using_exsit=1;
						last_using_index = index
						json_data.list[index].using = true;
					elseif last_using_index > index then
						json_data.list[index].using = true;
						json_data.list[last_using_index].using = false;
						last_using_index=index
					end
				end
				if cpestatus.iccid and #cpestatus.iccid > 0 and (cpestatus.iccid ~= "none") then
					json_data.list[index].sim=0
				end
				if cpestatus.model and #cpestatus.model > 0 then
					json_data.list[index].model=0
				end
				if cpestatus.isp and #cpestatus.isp > 0 and (json_data.list[index].sim==0) then
					json_data.list[index].isp=cpestatus.isp
					json_data.list[index].register=0
				end
				if cpestatus.mode == "LTE" or cpestatus.mode:match("NR") then
					if cpestatus.rsrp  and (#cpestatus.rsrp > 0) and tonumber(cpestatus.rsrp) < 0 then
						json_data.list[index].nosignal=0
					end
				elseif cpestatus.mode == "WCDMA" or cpestatus.mode == "TD-SCDMA" or cpestatus.mode == "GSM" or cpestatus.mode == "CDMA" then
					if cpestatus.rssi and (#cpestatus.rssi > 0) and tonumber(cpestatus.rssi) < 0 then
						json_data.list[index].nosignal=0
					end
				end
				if cpe_count == 1 then
					json_data.list[index].using = true;
					using_exsit = 1;
				end
			end
		end
		if using_exsit == 0 then
			json_data.list[1].using = true;
		end

	end
	if #json_data.list == 0 then
		json_data.list[1] = {}
	end
	return json_data
end

function action_get_info()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={}}
	local count_cpe = nr.count_cpe()
	if not data then
		return 
	end

	if data and data.trans_id and data.timestamp and data.type then
		--nixio.syslog("err","action_info :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = "0"

		json_data.result.runtime = luci.nradio.get_combo_info()
		local version_data = util.exec("cat /etc/openwrt_version")
		version_data=version_data:gsub("\n","")
		json_data.result.basic={version="",mac="",name=""}
		json_data.result.basic.name = uci:get("oem", "board", "pname")
		json_data.result.basic.net_prefer = uci:get("network", "globals", "net_prefer")
		json_data.result.basic.version = version_data
		
		
		if count_cpe >= 1 then
			json_data.result.basic.active_modem = {}
			json_data.result.basic.modem_cnt = count_cpe
			for i = 0, count_cpe - 1 do
				local iface = (i == 0 and cellular_default or cellular_prefix..i)
				local module_disabled = uci:get("network",iface,"disabled") or ""
				if module_disabled ~= "1" then
					json_data.result.basic.active_modem[#json_data.result.basic.active_modem+1] = i+1
				end
			end
		end

		local id = uci:get("oem", "board", "id")
		if id then
			id = id:gsub(":", "")
			json_data.result.basic.mac=id
		end

		json_data.result.diagnosis = get_diagnosis()
		json_data.result.cpesel = get_cpesel_info()
		json_data.result.cpecfg = get_cpecfg_info()
		json_data.result.apn = get_apn_info()
		json_data.result.client = nr.get_terminal_list()
		json_data.result.wifi= get_wifi_info()
		json_data.result.bat= get_bat_info()
		json_data.result.cellular= get_cellular_info()
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
	end
end

function action_system_wifi()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={}}
	if data and data.trans_id and data.timestamp and data.list then
		nixio.syslog("err","system_wifi :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = "0"
		local change=0
		local wifi_cnt=0
		local diff_wlan=0
		for _,item in pairs (data.list) do
			local target = item.rule_name
			ssid = item.ssid
			key = item.password
			hide = item.hidden
			encryption = item.encryption
			disabled = item.disabled
			channel = item.channel
			maxstanum = item.max_link
			diff_wlan=0
			if not target or target == "" then
				target = "t0"
				diff_wlan=1
			end

			if target == "t0" then
				if wifi_cnt == 0 then
					wifi_cnt = get_wifi_cnt()
				end
				if ssid and #ssid > 0 then
					uci:set("cloudd",target,"ssid_wlan","X"..ssid)
					change=1
				end

				if key and #key > 0 then
					uci:set("cloudd",target,"key_wlan","X"..key)
					change=1
				end
				if encryption and #encryption > 0 then
					uci:set("cloudd",target,"encryption_wlan","X"..encryption)
					change=1
				end
				if disabled and #disabled > 0 then
					uci:set("cloudd",target,"disabled_wlan","X"..disabled)
					change=1
				end
				if hide and hide=="1" then
					uci:set("cloudd",target,"hidden_wlan","X1")
					change=1
				end
				if hide and hide=="0" then
					uci:set("cloudd",target,"hidden_wlan","X")
					change=1
				end

				if maxstanum and (type(maxstanum) == "string" or type(maxstanum) == "number") then
					if tonumber(maxstanum) == 0 then
						uci:set("cloudd",target,"maxstanum_wlan","X")
					else
						uci:set("cloudd",target,"maxstanum_wlan","X"..maxstanum)
					end
					change=1
				end

				if wifi_cnt == 1 then
					if channel and #channel > 0 then
						change=1
						uci:set("cloudd","g1radio","channel_radio0","wireless.radio0.channel="..channel)
					end
				end

				if change == 1 then
					if diff_wlan == 1 then
						uci:set("cloudd", "t0", "diff_2_4_wlan","X1")
						uci:set("cloudd","t0","diff_2_4_ssid_wlan","X"..ssid.."-2.4G")
						uci:set("cloudd","t0","ssid_wlan","X"..ssid.."-5G")
					else
						uci:set("cloudd", "t0", "diff_2_4_wlan","X0")
					end
					uci:delete("cloudd", "g1wlan")
					uci:set("cloudd", "g1wlan","interface")
				end
			else
				uci:set("cloudd", "t0", "diff_2_4_wlan","X1")
				uci:set("cloudd", "g1wlan","interface")
				radiokey = target:match("%d$") or "0"
				if encryption and #encryption > 0 then
					change=1
					uci:set("cloudd","g1wlan","encryption_"..target,"wireless."..target..".encryption="..encryption)
				end
				if disabled and #disabled > 0 then
					change=1
					uci:set("cloudd","g1wlan","disabled_"..target,"wireless."..target..".disabled="..disabled)
				end
				if channel and #channel > 0 then
					change=1
					uci:set("cloudd","g1radio","channel_radio"..radiokey,"wireless.radio"..radiokey..".channel="..channel)
				end
				if hide and hide=="1" then
					change=1
					uci:set("cloudd","g1wlan","hidden_"..target,"wireless."..target..".hidden=1")
				end
				if hide and hide=="0" then
					change=1
					uci:set("cloudd","g1wlan","hidden_"..target,"wireless."..target..".hidden=0")
				end

				if maxstanum and (type(maxstanum) == "string" or type(maxstanum) == "number") then
					if tonumber(maxstanum) == 0 then
						uci:delete("cloudd","g1wlan","maxstanum_"..target)
					else
						uci:set("cloudd","g1wlan","maxstanum_"..target,"wireless."..target..".maxstanum="..maxstanum)
					end
					change=1
				end

				if ssid and #ssid > 0 then
					change=1
					uci:set("cloudd","g1wlan","ssid_"..target,"wireless."..target..".ssid="..ssid)
				end
				if key and #key > 0 then
					uci:set("cloudd","g1wlan","key_"..target,"wireless."..target..".key="..key)
					change=1
				end
			end
		end
		if change == 1 then
			uci:commit("cloudd")
		end

		json_data.result.list = get_wifi_info()
		
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
		if change == 1 then			
			luci.nradio.fork_exec(function()
				local cl = require "luci.model.cloudd".init()
				local ca = require "cloudd.api"
				local id = ca.cloudd_get_self_id()
				local cdev = cl.get_device(id, "master")
				if nr.support_mesh() then
					ca.sync_wifi_config()
				end
				cdev:send_config()
			end)
		end
	end
end

function action_system_cpesel()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={cpesel={}}}
	if data and data.trans_id and data.timestamp and data.cur then
		nixio.syslog("err","system_cpesel :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = "0"
		local name = ""
		local cpesel_filename = "cpesel"
		local only_save = false
		if data.from == "LOCAL" and data.device_id then
			cpesel_filename="kpcpe_"..data.device_id.."_"..cpesel_filename
			only_save = true
			if not fs.access("/etc/config/".. cpesel_filename) then
				util.exec("touch /etc/config/".. cpesel_filename)
			end
		end

		local cpe_count=0
		local cur = uci
		uci:foreach("network", "interface",
			function(s)
				if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
					cpe_count=cpe_count+1
					if cpe_count == 1 then
						name = s[".name"]
					end
				end
			end
		)		
		local change=0
		if type(data.cur) == "table" and (#data.cur > 0) then			
			for i = 1, #data.cur do
				local prefix = ""
				if i > 1 then
					prefix=i-1
				end
				if i <= cpe_count then
					local cur_now = uci:get(cpesel_filename,"sim"..prefix,"cur") or ""
					local mode_now = uci:get(cpesel_filename,"sim"..prefix,"mode") or "0"
					local adv_sim_now = uci:get(cpesel_filename,"sim"..prefix,"adv_sim") or "0"
					local gval_now = uci:get(cpesel_filename,"sim"..prefix,"gval") or ""
					local max_now = uci:get(cpesel_filename,"sim"..prefix,"max") or ""
					local default_now = uci:get(cpesel_filename,"sim"..prefix,"default") or cur_now
					local stype_now = uci:get(cpesel_filename,"sim"..prefix,"stype") or ""

					local mode = (data.mode and data.mode[i]) or "1"
					local adv_sim = (data.adv_sim and data.adv_sim[i]) or "0"					
					local gval = uci:get("cpesel","sim"..prefix,"gval") or ""
					local max = uci:get("cpesel","sim"..prefix,"max") or ""
					local default = (data.default and data.default[i]) or default_now
					local stype = uci:get("cpesel","sim"..prefix,"stype") or ""

					if tonumber(cur_now) ~= data.cur[i] or tonumber(mode_now) ~= tonumber(mode) 
						or tonumber(adv_sim_now) ~= tonumber(adv_sim) 
						or (gval_now) ~= (gval)
						or (max_now) ~= (max) 
						or tonumber(default_now) ~= tonumber(default)
						or (stype_now) ~= (stype) then
						uci:set(cpesel_filename,"sim"..prefix,"cpesel")
						uci:set(cpesel_filename,"sim"..prefix,"cur",tostring(data.cur[i]))
						uci:set(cpesel_filename,"sim"..prefix,"mode",tostring(mode))
						uci:set(cpesel_filename,"sim"..prefix,"default",tostring(default))
						uci:set(cpesel_filename,"sim"..prefix,"adv_sim",tostring(adv_sim))
						uci:set(cpesel_filename,"sim"..prefix,"gval",tostring(gval))
						uci:set(cpesel_filename,"sim"..prefix,"max",tostring(max))
						uci:set(cpesel_filename,"sim"..prefix,"stype",tostring(stype))
						change=1
					end
				end
			end
		end
		if change == 1 then
			uci:commit(cpesel_filename)
			if not only_save then
				luci.nradio.fork_exec(function()
					util.exec("/etc/init.d/cpesel restart")
					util.exec("/etc/init.d/wanchk restart")
					util.exec("/etc/init.d/tcsd restart") 
				end)
			end
		end

		if data.from ~= "NRFAMILY" and data.from ~= "LOCAL" then
			local model_str,cpe_section = nr.get_cellular_last(name)
			local sim_section="sim"..model_str
			local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"
			nr.app_write_cpesel(cpe_section,sim_section)
			nr.app_write_cpecfg(cpe_section,cur_sim,cpe_section.."sim"..cur_sim)
		end

		uci:foreach("cpesel", "cpesel",
			function(s)
				local curdata = s["cur"] or 1
				local curmode = s["mode"] or 0
				local curdefault = s["default"] or curdata
				local curgval = s["gval"] or ""
				curdata = tonumber(curdata)
				curmode = tonumber(curmode)
				curdefault = tonumber(curdefault)
				json_data.result.cpesel[#json_data.result.cpesel+1] = {cur=curdata,mode=curmode,default=curdefault,gval=curgval}
			end
		)			
		if #json_data.result.cpesel == 0 then
			json_data.result.cpesel[1] = {}
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
	end
end

function action_system_client()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id="",result={}}
	if data and data.trans_id and data.timestamp  then
		nixio.syslog("err","system_client :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = "0"
		if data.client and (data.switch or data.hostname) then
			json_data.result.client={}
			json_data.result.client.client = data.client
			if data.switch then
				local switch = luci.nradio.get_client_switch(data.client)
				if tonumber(data.switch) ~= switch then
					luci.nradio.set_client_switch(data.client,data.switch)
				end

				switch = luci.nradio.get_client_switch(data.client)
				json_data.result.client.switch = tonumber(switch)				
			end

			if data.hostname then
				luci.nradio.set_client_name(data.client,data.hostname)
				json_data.result.client.hostname = data.hostname
			end
		else
			json_data.result.list = nr.get_terminal_list()
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
	end
end

function action_system_combo()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp and data.combo then
		nixio.syslog("err","system_combo :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = "0"

		local combo_array = {}
		local update_info = {code="2"}
		if data.combo then
			combo_array = data.combo
		end
	
		if #combo_array == 0 then
			json_data.code = "2"
		end
	
		if json_data.code == "0" then
			update_info = util.ubus("combo", "update", { trans_id = data.trans_id ,from="app",combo=combo_array}) or {code="2"}
			json_data.code = update_info.code
		end
		json_data.list = update_info.list or {{}}
		luci.nradio.app_response(luci.nradio.app_encrypto(cjson.encode(json_data)))
	end
end

function action_sms()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp then
		nixio.syslog("err","sms :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = -4

		if data.action == "read" then
			local read_result = luci.nradio.sms_list(data.type)
			json_data.result = read_result
			json_data.code = read_result.code
		elseif data.action == "del" then
			local del_result = luci.nradio.sms_del(data.ids,data.type) or {}
			json_data.smsdel =  del_result.smsdel or {}
			json_data.code =  del_result.code or 1
		elseif data.action == "send" then
			if data.msg and data.phone_num then
				local send_result = luci.nradio.sms_send(data.msg,data.phone_num) or {}
				json_data.code = send_result.code or -1
				json_data.item = send_result.item or {}
			elseif data.index then
				local send_result = luci.nradio.sms_resend(data.index) or {}
				json_data.code = send_result.code or -1
			else
				json_data.code = -1
				json_data.item = {}
			end		
		else
			local base_data = nr.get_base_data(data)
			json_data.code = 0
			json_data.result = {}
			json_data.result.index = base_data.index
			if data.action then
				json_data.result.action = data.action
			end
			json_data.result.sim = tonumber(data.sim or base_data.now_sim)
			if data.action == "modify" then
				local apn_reload = nr.do_cellular_sms(base_data,data)
				if apn_reload then
					if base_data.sim_diff == 0 then
						util.exec("ifup "..base_data.cpe_name.." >/dev/null 2>&1")
					end
				end
			end
			json_data.result.enabled = uci:get("cpecfg", base_data.cpecfg_name,"force_ims") or "0"
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end
function action_lan()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp and data.ip then
		nixio.syslog("err","lan :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = 0
		if data.ip then
			luci.nradio.save_lan_ip(data.ip)
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end

function action_status()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp then
		json_data.trans_id = data.trans_id
		json_data.code = 0
		json_data.result = util.ubus("infocd", "runtime") or { }
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end
function action_speed_info()	
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp then
		json_data.trans_id = data.trans_id
		json_data.code = 0
		json_data.result = {}
		if data.name then
			json_data.result = nr.get_speed_info(data.name)
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end

function action_set_password()	
	local data = luci.nradio.app_decrypto()
	local json_data = {code=3,trans_id=""}
	if data and data.trans_id and data.timestamp and data.password then
		json_data.trans_id = data.trans_id
		json_data.code = nr.set_password_info(data.password)
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end

function action_set_wifiauth()	
	local data = luci.nradio.app_decrypto()
	local json_data = {wifiauth=-1,trans_id=""}
	if data and data.trans_id and data.timestamp then
		json_data.trans_id = data.trans_id
		nr.set_wifiauth(data.wifiauth)
		json_data.wifiauth = nr.support_wifiauth()
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end

function action_sync()
	local data = luci.nradio.app_decrypto()
	local json_data = {code="",trans_id=""}
	if data and data.trans_id and data.timestamp then
		nixio.syslog("err","sync :"..cjson.encode(data))
		json_data.trans_id = data.trans_id
		json_data.code = 0
		local family = false
		cellular_prefix,cellular_default = nr.get_cellular_prefix()
		if nr.check_nrfamily_if(cellular_default) then
			family = true
		end
		if data.result then
			for key,item in pairs(data.result) do
				local file_name = key
				if key == "apn" and family then
					local kpcpe_id = nr.get_nrfamily_id(cellular_default)
					file_name = "kpcpe_"..kpcpe_id.."_apn"
				end
				if key == "apn" then
					util.exec("rm /etc/config/"..file_name)
					util.exec("touch /etc/config/"..file_name)
				end
				if item then
					for _,item_sub in pairs(item) do
						local rule_name = item_sub.name
						local rule_type = item_sub.type
						local rule_data = item_sub.data
						if key == "cpecfg" then
							local sim_id = rule_name:match("sim(%d*)")
							rule_name = cellular_default.."sim"..sim_id
						end
						uci:delete(file_name,rule_name)
						uci:set(file_name,rule_name,rule_type)
						for key_2,item_2_sub in pairs(rule_data) do
							uci:set(file_name,rule_name,key_2,item_2_sub)
							nixio.syslog("err","sync file:"..file_name..",rule_name:"..rule_name..",option:"..key_2..",value:"..item_2_sub)
						end
					end
				end
				uci:commit(file_name)
				util.exec("ifup "..cellular_default.." >/dev/null")
				util.exec("/etc/init.d/cpesel restart >/dev/null")
			end
		end
		luci.nradio.app_response(luci.nradio.app_encrypto(util.serialize_json(json_data,nil)))
	end	
end