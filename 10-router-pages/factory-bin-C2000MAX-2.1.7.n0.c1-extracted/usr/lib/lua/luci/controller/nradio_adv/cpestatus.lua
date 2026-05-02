module("luci.controller.nradio_adv.cpestatus", package.seeall)

local util = require "luci.util"
local cjson = require "cjson.safe"
local lng = require "luci.i18n"

function index()
	local disp = require "luci.dispatcher"
	local nr = require "luci.nradio"
	local uci  = require "luci.model.uci"
	local request  = disp.context.requestpath
	local model_str,cpe_section = nr.get_cellular_last(request and request[5])
	local iface_odu_mode = uci.cursor():get("network",cpe_section, "mode") or ""

	if iface_odu_mode == "odu" then
		entry({"nradio", "cellular"}, template("nradio_adv/cpedevice"), _("NBCPE Device"), 20, true).index = true
	else
		entry({"nradio", "cellular"}, template("nradio_adv/cpestatus"), _("Cellular Status"), 20, true).index = true
	end	
	
	page = entry({"nradio", "cellular", "cpestatus"}, alias("nradio","cellular"), _("Cellular Status"), 20, true)
	page.index = true
	page.show = false
	page.icon = 'signal-4'
	entry({"nradio", "cellular", "cpedevice"}, template("nradio_adv/cpedevice"), _("NBCPE Device"), 21, true)
	entry({"nradio", "cellular", "cpedevice", "model"}, call("get_cellular_template"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpedevice", "info"}, call("action_kpcpeinfo"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpedevice", "port"}, call("action_portinfo"), nil, nil, true).leaf = true

	entry({"nradio", "cellular", "cpestatus", "model"}, call("get_cellular_template"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpestatus", "cellinfo"}, call("action_cellinfo"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpestatus", "earfcn_lock"}, call("lock_cellular_earfcn"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpestatus", "info"}, call("get_cellular_info"), nil, nil, true).leaf = true

	entry({"nradio", "cellular", "cpescan"}, template("nradio_adv/cpescan"), _("Scan Info"), 21, true)
	entry({"nradio", "cellular", "cpescan", "scaninfo"}, call("action_scaninfo"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpescan", "scan_check"}, call("action_scancheck"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "cpescan", "model"}, call("get_cellular_template"), nil, nil, true).leaf = true

	entry({"nradio", "cellular", "switch"}, cbi("nradio_cellular/switch"),nil, nil, true)	
	entry({"nradio", "cellular", "switch","model"}, cbi("nradio_cellular/switch"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "switch","save_sms"}, call("action_apn_save_sms"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "apn"}, template("nradio_adv/apn"), nil, nil, true)
	entry({"nradio", "cellular", "apn","model"}, call("get_cellular_template"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "apn","del"}, call("action_apn_del"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "apn","save"}, call("action_apn_save"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "apn","save_sim"}, call("action_apn_save_sim"), nil, nil, true).leaf = true
	entry({"nradio", "cellular", "apn","list"}, call("action_apn_http_list"),  nil, nil, true).leaf = true
	entry({"nradio", "cellular", "apn_simple"}, cbi("nradio_cellular/apn"), nil, nil, true)
	entry({"nradio", "cellular", "apn_simple", "model"}, cbi("nradio_cellular/apn"), nil, nil, true).leaf = true
end

function get_cellular_template()
	luci.nradio.get_cellular_template()
end

function action_apn_del()
	local fs = require "nixio.fs"
	local http = require "luci.http"
	local uci  = require "luci.model.uci"
	local name = http.formvalue("name")
	local modelname = http.formvalue("modelname")
	local filename = luci.nradio.get_apn_filename(modelname)
	local section = nil
	local cur = uci.cursor()

	if not name or #name == 0 then
		return
	end

	cur:delete(filename, name)
	cur:commit(filename)
	luci.nradio.reload_apn_used(name,"del")
	luci.nradio.luci_call_result({code=0})
end
function action_apn_save()
	local fs = require "nixio.fs"
	local http = require "luci.http"
	local uci  = require "luci.model.uci"
	local name = http.formvalue("name")
	local auth = http.formvalue("auth")
	local apn = http.formvalue("apn")
	local username = http.formvalue("username")
	local password = http.formvalue("password")
	local pdptype = http.formvalue("pdptype")
	local custom_apn = http.formvalue("custom_apn")
	local modelname = http.formvalue("modelname")

	local cur = uci.cursor()

	if not name or #name == 0 then
		return
	end

	local filename = luci.nradio.get_apn_filename(modelname)
	if not fs.access("/etc/config/"..filename) then
		util.exec("touch /etc/config/"..filename)
	end
	cur:set(filename,name, "rule")
	if auth and auth ~= "" then
		cur:set(filename, name, "auth", auth)
	else
		cur:delete(filename, name, "auth")
	end
	if apn and apn ~= "" then
		cur:set(filename, name, "apn", apn)
	else
		cur:delete(filename, name, "apn")
	end
	if username and username ~= "" then
		cur:set(filename, name, "username", username)
	else
		cur:delete(filename, name, "username")
	end
	if password and password ~= "" then
		cur:set(filename, name, "password", password)
	else
		cur:delete(filename, name, "password")
	end
	if pdptype and pdptype ~= "" then
		cur:set(filename, name, "pdptype", pdptype)
	else
		cur:delete(filename, name, "pdptype")
	end
	if custom_apn and custom_apn ~= "" then
		cur:set(filename, name, "custom_apn", custom_apn)
	else
		cur:delete(filename, name, "custom_apn")
	end
	cur:commit(filename)
	luci.nradio.reload_apn_used(name,"add")
	luci.nradio.luci_call_result({code=0})
end
function action_apn_save_sms()
	local input_data = luci.http.formvalue() or nil
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	local exsit_commit = false
	local name = ""
	local section_key = ""
	local simid = ""
	if input_data then
		for key,item in pairs(input_data) do			
			local key_arr = util.split(key, '_')
			if key_arr and #key_arr >= 3 then				
				local modelname = key_arr[1]
				simid = key_arr[2]		
				local prefix_buffer = modelname.."_"..simid.."_"
				local targetname = key:sub(key:find(prefix_buffer)+#prefix_buffer)
				
				section_key = modelname.."sim"..simid
				nixio.syslog("err","section_key:"..section_key..",targetname:"..targetname)
				uci:set("cpecfg",section_key,"cpesim")
				uci:set("cpecfg", section_key, targetname, item)
				uci:save("cpecfg")
				
				name = modelname
				exsit_commit = true
			end
		end
	end
	if exsit_commit then
		uci:commit("cpecfg")	
		util.exec("ifup "..name.." >/dev/null 2>&1")		
		luci.nradio.app_write_sms(name,simid,section_key)
	end
	luci.nradio.luci_call_result({code=0})
end
function action_apn_save_sim()
	local input_data = luci.http.formvalue() or nil
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()

	if input_data then
		for key,item in pairs(input_data) do
			local target_name = nil
			local target_action = nil
			local key_arr = util.split(key, '_')
			local cpecfg_section = nil
			if key_arr and #key_arr >= 3 then				
				local modelname = key_arr[1]
				local simid = key_arr[2]
				local prefix_buffer = modelname.."_"..simid.."_"
				local targetname = key:sub(key:find(prefix_buffer)+#prefix_buffer)
				local section_key = modelname.."sim"..simid
				nixio.syslog("err","section_key:"..section_key..",targetname:"..targetname)
				cpecfg_section = modelname.."sim"..simid
				cpecfg_section = cpecfg_section:gsub("[;'\\\"]", "")
				if targetname == "apn_cfg" then
					local apn_cfg = uci:get("cpecfg",cpecfg_section, "apn_cfg") or ""
					if apn_cfg ~= item then
						if item and #item > 0 then
							target_name = item
							target_action = "add"
							util.exec("rm  /tmp/"..cpecfg_section.."_remove_apn")
						else
							target_name = apn_cfg
							target_action = "del"
						end
					end
				elseif targetname == "apn_cfg2" then
					local apn_cfg2 = uci:get("cpecfg",cpecfg_section, "apn_cfg2") or ""
					if apn_cfg2 ~= item then
						if item and #item > 0 then
							target_name = item
							target_action = "add"
							util.exec("rm  /tmp/"..cpecfg_section.."_remove_apn2")
						else
							target_name = apn_cfg2
							target_action = "del"			
						end
					end
				end
				if item and #item > 0 then
					uci:set("cpecfg",section_key,"cpesim")
					uci:set("cpecfg", section_key, targetname, item)
					uci:save("cpecfg")
					uci:commit("cpecfg")
				end
			end
			luci.nradio.reload_apn_used(target_name,target_action,cpecfg_section)
		end
	end

	luci.nradio.luci_call_result({code=0})
end

function action_apn_list(cpe_section)
	local uci  = require "luci.model.uci"
	local cur = uci.cursor()
	local data = {}
	
	local filename = luci.nradio.get_apn_filename(cpe_section)
	cur:foreach(filename, "rule",
		function(s)
			local item_data = {}
			item_data.name = s[".name"] or ""
			item_data.auth = s.auth or ""
			item_data.apn = s.apn or ""
			item_data.username = s.username or ""
			item_data.password = s.password or ""
			item_data.pdptype = s.pdptype or ""
			item_data.custom_apn = s.custom_apn or ""
			data[#data+1] = item_data
		end
	)

	return data
end

function action_apn_http_list()
	local model = luci.http.formvalue("model")
	luci.nradio.luci_call_result(action_apn_list(model))
end

function action_cellinfo()
	local cellinfos = {}
	local cpestatus = util.ubus("infocd", "cpestatus")
	if cpestatus then
		if cpestatus.result and #cpestatus.result then
			for _,v in ipairs(cpestatus.result) do
				if v.status.isp and #v.status.isp > 0 then
					v.status.isp_ori = v.status.isp
					v.status.isp = luci.nradio.genarate_plmn_company(v.status.isp)
				end
				if v.status.imsi and #v.status.imsi > 0 then
					v.status.sim_isp = luci.nradio.genarate_plmn_company(v.status.imsi:sub(1,5))
				end
			end
		end
		luci.nradio.luci_call_result(cpestatus.result)
		return
	end

	luci.nradio.luci_call_result(cellinfos)
end

function action_kpcpeinfo()
	local rv = util.ubus("kpcped", "status") or {}
	luci.nradio.luci_call_result(rv)
end
function action_portinfo()
	local nr = require "luci.nradio"
	luci.nradio.luci_call_result(nr.get_nrswitch_info())
end

function action_scancheck()
	local nr = require "luci.nradio"
	local scan_result = {code=0,neighbour={}}
	local model = luci.http.formvalue("model")
	scan_result.neighbour,result = nr.check_cellular_neighbour(model)
	for _,v in ipairs(scan_result.neighbour) do
		for _,vs in ipairs(v) do
			if vs.ISP and #vs.ISP then
				local tmp_isp=""
				isp_array = util.split(vs.ISP, ":")
				max = #isp_array
				for i = 1, max do
					tmp_isp = tmp_isp..luci.nradio.genarate_plmn_company(isp_array[i]).." "
				end
				vs.ISP=tmp_isp
			end
		end
	end
	if not result then
		scan_result.code=-1
	end
	luci.nradio.luci_call_result(scan_result)
end


function get_simstatus(model)
	local uci  = require "luci.model.uci"
	local http = require "luci.http"
	local nr = require "luci.nradio"
	local uci = uci.cursor()


	local model_str,cpe_section,model_index = nr.get_cellular_last(model)
	local sim_section = "sim"..model_str
	local sims_alias = nr.get_sim_alias()
	if sims_alias then
		sims_alias=sims_alias[model_index]
	end

	local cur_now = uci:get("cpesel",sim_section,"cur") or "1"
	local rv = util.ubus("infocd", "cpeinfo",{name=cpe_section})
	local return_code = {cur=sims_alias[tonumber(cur_now)],status=0,register=0,net=0,pin=0}

	if rv and rv.SIM == "ready" then
		return_code.status = 1
	end
	if rv and rv.STAT == "register" then
		return_code.register = 1
		local cpestatus = util.ubus("infocd", "cpestatus") or {}
		if cpestatus then
			if cpestatus.result and #cpestatus.result then
				for _,v in ipairs(cpestatus.result) do
					if v.status.name == cpe_section then
						if v.up == 0 then
							return_code.net = 1
						end
						break
					end
				end
			end
		end

	end
	return return_code
end

function get_cellular_info()
	local http = require "luci.http"
	local nr = require "luci.nradio"
	local model = http.formvalue("model") or ""
	local sim_id = http.formvalue("sim_id")
	local earfcn = http.formvalue("earfcn")
	local sim = http.formvalue("sim")
	local company = nr.get_sim_company(model,sim_id) or ""
	local return_code = {}

	if model then
		model = model:gsub("[;'\\\"]", "")
	end

	if earfcn and earfcn == "1" then
		return_code = nr.get_cellular_earfcn(model,sim_id) or {}
	end
	if sim and sim == "1" then
		return_code.sim = get_simstatus(model) or {}
	end
	return_code.sim_company=company
	luci.nradio.luci_call_result(return_code)
end

function lock_cellular_earfcn()
	local uci  = require "luci.model.uci"
	local uci = uci.cursor()
	local http = require "luci.http"
	local nr = require "luci.nradio"
	local model = http.formvalue("model") or ""
	local sim_id = http.formvalue("sim_id")
	local action = http.formvalue("action") or ""

	local model_type = http.formvalue("model_type")
	local earfcn = http.formvalue("earfcn") or ""
	local pci = http.formvalue("pci")
	local band = http.formvalue("band")
	local custom_earfcn = "1"
	if action == "0" then
		earfcn = ""
		pci = ""
		band = ""
	end
	model = model:gsub("[;'\\\"]", "")
	local earfreq_work_mode = uci:get("network",model,"earfreq_mode")
	local cpecfg_section=model.."sim"..sim_id	
	local cpecfg_info = uci:get_all("cpecfg", cpecfg_section) or {}
	local diff = false

	if earfreq_work_mode == "one" then
		if cpecfg_info["earfreq_mode"] ~= "earfcn"..model_type then
			uci:set("cpecfg", cpecfg_section, "earfreq_mode","earfcn"..model_type)
			diff = true
		end
	else
		if cpecfg_info["earfreq_mode"] ~= "" then
			uci:set("cpecfg", cpecfg_section, "earfreq_mode","")
			diff = true
		end
	end
	if cpecfg_info["custom_freq"] ~= "" then
		uci:set("cpecfg", cpecfg_section, "custom_freq","")
		diff = true
	end	
	if cpecfg_info["freq"] ~= "" then
		uci:set("cpecfg", cpecfg_section, "freq","")
		diff = true
	end	
	if cpecfg_info["custom_earfcn"..model_type] ~= custom_earfcn then
		uci:set("cpecfg", cpecfg_section, "custom_earfcn"..model_type,custom_earfcn)
		diff = true
	end
	if cpecfg_info["earfcn"..model_type.."_mode" ] ~= "0" then
		uci:set("cpecfg", cpecfg_section, "earfcn"..model_type.."_mode","0")
		diff = true
	end
	if cpecfg_info["earfcn"..model_type] ~= earfcn then
		uci:set("cpecfg", cpecfg_section, "earfcn"..model_type,earfcn)
		diff = true
	end
	if cpecfg_info["pci"..model_type] ~= pci then
		uci:set("cpecfg", cpecfg_section, "pci"..model_type,pci)
		diff = true
	end
	if cpecfg_info["band"..model_type] ~= band then
		uci:set("cpecfg", cpecfg_section, "band"..model_type,band)
		diff = true
	end

	if diff then
		uci:commit("cpecfg")
		nr.set_n79_relate(model)
		nr.app_write_earfcn(model,sim_id,cpecfg_section)
		util.exec("ifup "..model)
	end
	local return_code ={code=0}
	luci.nradio.luci_call_result(return_code)
end
function action_scaninfo()
	local client_ip = luci.http.getenv("REMOTE_ADDR") or ""
	local model = luci.http.formvalue("model")
	local model_type = luci.http.formvalue("model_type")
	local force = luci.http.formvalue("force")
	nixio.syslog("err","WEB["..client_ip.."] cellular scan")
	local nr = require "luci.nradio"
	local scan_result = {code=0,neighbour={}}
	if model then
		model = model:gsub("[;'\\\"]", "")
	end
	scan_result.neighbour = nr.get_cellular_neighbour(model,model_type,force)
	for _,v in ipairs(scan_result.neighbour) do
		for _,vs in ipairs(v) do
			if vs.ISP and #vs.ISP then
				local tmp_isp=""
				isp_array = util.split(vs.ISP, ":")
				max = #isp_array
				for i = 1, max do
					tmp_isp = tmp_isp..luci.nradio.genarate_plmn_company(isp_array[i]).." "
				end
				vs.ISP=tmp_isp
			end
		end
	end
	luci.nradio.luci_call_result(scan_result)
end
