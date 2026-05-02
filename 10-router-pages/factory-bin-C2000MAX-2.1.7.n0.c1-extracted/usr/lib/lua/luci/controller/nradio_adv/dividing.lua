module("luci.controller.nradio_adv.dividing", package.seeall)

function index()
	local uci  = require "luci.model.uci".cursor()	
	local fs = require "nixio.fs"

	local overlap_dividing = uci:get("luci","main", "overlap_dividing")
	if not fs.access("/usr/sbin/mwan3") or overlap_dividing == "0" then
		return
	end

	page = entry({"nradioadv", "network", "dividing"}, template("nradio_dividing/index"), _("Traffic Dist"), 45, true)
	page.icon = 'nradio-dividing'
	page.show = true
	entry({"nradioadv", "network", "dividing","save"}, call("outwan_save"), nil, nil, true).leaf = true
	entry({"nradioadv", "network", "dividing","protocol"}, template("nradio_dividing/protocol"), nil, 46, true)
	entry({"nradioadv", "network", "dividing","protocol","save"}, call("protocol_save"), nil, nil, true).leaf = true
	
end

function get_outwan_info()
	local nr = require "luci.nradio"
	local lng  = require "luci.i18n"
	local uci  = require "luci.model.uci".cursor()	
	local wired_info = {translate=lng.translate("DividingWired"),value="wan"}
	local info_arr = {}
	local count_cpe = nr.count_cpe()
	local cellular_count=0
	local nbcpe_index=0
	local cellular_prefix,cellular_default = nr.get_cellular_prefix()
	info_arr[#info_arr+1] = wired_info

	local has_nbcpe_only = nr.has_nbcpe_only()
	if has_nbcpe_only then
		dividing_nbcpe_lng = lng.translate("DividingNBCPE1")	
	else
		dividing_nbcpe_lng = lng.translate("DividingNBCPE")
	end

	for i = 0, count_cpe - 1 do
		local celluar_info = {translate="",value=""}
		local dividing_type = ""
		local last_info = ""
		local iface = (i == 0 and cellular_default or cellular_prefix..i)		
		local iface_odu_mode = uci:get("network",iface, "mode") or ""
		local isnbcpe = false
		if iface_odu_mode == "odu" then
			nbcpe_index=nbcpe_index+1
			if nbcpe_index > 1 then
				last_info = nbcpe_index
			end
			dividing_type = dividing_nbcpe_lng..last_info
			isnbcpe = true
		else
			cellular_count=cellular_count+1
			if cellular_count > 1 then
				last_info = cellular_count
			end
			dividing_type = lng.translate("DividingCellular")..last_info
		end
		celluar_info.translate = dividing_type
		celluar_info.value = iface
		celluar_info.isnbcpe = isnbcpe
		info_arr[#info_arr+1] = celluar_info
	end
	return info_arr
end
function get_outwan_data()
	local data_arr = {globals="",client={}}
	local uci = require "luci.model.uci".cursor()
	data_arr.globals  = uci:get("network","globals", "dividing_default") or ""
	uci:foreach("dividing", "client",
		function(s)
			local mac = s[".name"]:gsub("_", ":")
			data_arr["client"][mac] = s["dividing_default"]
		end
	)
	return data_arr
end
function check_nettype_match()
	local uci = require "luci.model.uci".cursor()
	local net_prefer=uci:get("network","globals", "net_prefer") or ""
	local net_key = luci.nradio.get_nettype_nbcpe(net_prefer)
	if net_key and net_key:match("Dividing") then
		return true
	end
	return false
end
function check_nbcpe_match()
	local uci = require "luci.model.uci".cursor()
	local net_prefer=uci:get("network","globals", "net_prefer") or ""
	local net_key = luci.nradio.get_nettype_nbcpe(net_prefer)
	if net_key and net_key:match("NBCPE") then
		return true
	end
	return false
end

function outwan_save()
	local input_data = luci.http.formvalue() or nil
	local util = require "luci.util"
	local nixio = require "nixio"
	local fs = require "nixio.fs"
	local uci = require "luci.model.uci".cursor()
	local exsit_commit = false
	if not check_nettype_match() then
		luci.nradio.luci_call_result({code = -1})
		return
	end

	if input_data then
		for key,item in pairs(input_data) do			
			local key_arr = util.split(key, '_')
			if key_arr and #key_arr == 6 then
				uci:set("dividing",key,"client")
				uci:set("dividing",key,"dividing_default" ,item)
			end
		end
	end
	uci:commit("dividing")
	util.exec("access_ctl.sh -r 2")
	if fs.access("/usr/sbin/mwan3") then
		util.exec("mwan3 restart >/dev/null 2>&1")
	end
end

function protocol_save()
	local input_data = luci.http.formvalue() or nil
	local util = require "luci.util"
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	local fs = require "nixio.fs"
	local change = false
	if not check_nettype_match() then
		luci.nradio.luci_call_result({code = -1})
		return
	end
	if input_data then
		for key,item in pairs(input_data) do
			if key:match("^model_") then
				local key_arr = util.split(key, '_')
				local item_arr = util.split(item, '\n')
				key_arr[2] = key_arr[2]:gsub("[;'\\\"]", "")
				util.exec("uci -q delete dividing."..key_arr[2])
				util.exec("uci -q set dividing."..key_arr[2].."=protocol")
				for i = 1, #item_arr do	
					if item_arr[i] and #item_arr[i] > 0 then
						item_arr[i] = item_arr[i]:gsub("[;'\\\"]", "")
						util.exec("uci -q add_list dividing."..key_arr[2]..".address="..item_arr[i])
					end
				end
				change = true
			end
		end
		if change then
			util.exec("uci commit dividing")
			util.exec("access_ctl.sh -r 2")
		end
	end
end
function get_protocol_data()
	local data_arr = {}
	local uci = require "luci.model.uci".cursor()
	uci:foreach("dividing", "protocol",
		function(s)
			if not data_arr[s[".name"]] then
				data_arr[s[".name"]] = {}
			end
			data_arr[s[".name"]] = s["address"]
		end
	)
	return data_arr
end