local string, tonumber, pairs, type, os, ipairs, require, io = string, tonumber, pairs, type, os, ipairs, require, io
local util = require "luci.util"
local c_debug = require "cloudd.debug"
local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()
local md5 = require "md5"
local cjson = require "cjson"
local ntm = require "luci.model.network".init()

local c_default_group = "g0"
local c_config_sync_array = {"radio", "wlan"}

module ("cloudd.api")

local function cloudd_unused()
	-- function to avoid unused warning...
end

local function cloudd_get_group(d_id)
	local g_name = c_default_group

	uci:foreach("cloudd", "group",
					function(s)
						if s.device and type(s.device) == "table" then
							for i = 1, #s.device do
								if s.device[i] == d_id then
									g_name = s[".name"]
									return false
								end
							end
						end
					end)

	return g_name
end

function cloudd_get_self_id()
	local c_info = util.ubus("cloudd", "info") or { }
	return c_info.mac
end

local function cloudd_create_device_config(id)
	local dname
	local section

	-- detect and create cloudd device
	uci:foreach("cloudd", "device",
				function(s)
					if s.id == id then
						dname = s[".name"]
						return false
					end
				end
	)

	if dname then
		c_debug.syslog("info", "device "..id.." config exists "..dname)
	else
		local next_dev_idx = uci:get("cloudd", "config", "next_dev_idx") or 0
		section = "d" .. next_dev_idx

		while uci:get("cloudd", section) do
			next_dev_idx = next_dev_idx + 1
			section = "d" .. next_dev_idx
		end

		uci:set("cloudd", section, "device")
		uci:set("cloudd", section, "id", id)
		uci:set("cloudd", section, "name", id)
		uci:set("cloudd", section, "next_cb_idx", 0)

		uci:set("cloudd", "config", "next_dev_idx", next_dev_idx + 1)

		uci:commit("cloudd")
		dname = section
	end

	return dname
end

local function cloudd_create_cboard_config(dname, id, rcnt, pos)
	local section = nil
	local device_config = {}
	local oid = uci:get("cloudd", dname, "id")
	local need_commit = false

	if not oid then
		return false, section
	end

	-- Find exist device and delete them
	if oid ~= id then
		uci:delete_all("cloudd", "device",
					   function(s)
						   if s.id == id then
							   device_config[#device_config + 1] = s[".name"]
							   return true
						   end
					   end
		)
		for i = 1, #device_config do
			uci:delete_all("cloudd", "cboard",
						   function(s)
							   if s.id == id then
								   if s[".name"]:match("^"..device_config[i].."cboard") then
									   return true
								   end
							   end
						   end
			)
			uci:commit("cloudd")
		end
	end

	-- delete redundant cboard config
	uci:delete_all("cloudd", "cboard",
				   function(s)
					   if s.id == id then
						   if s[".name"]:match("^"..dname.."cboard") then
							   section = s[".name"]
						   else
							   need_commit = true
							   return true
						   end
					   end
				   end
	)

	if need_commit then
		uci:commit("cloudd")
	end

	-- detect and create cboard device
	if section then
		local r2cnt = tonumber(uci:get("cloudd", section, "r2cnt") or 1)
		local r5cnt = tonumber(uci:get("cloudd", section, "r5cnt") or 1)
		local p2cnt = tonumber(uci:get("cloudd", section, "p2cnt") or 1)
		local p5cnt = tonumber(uci:get("cloudd", section, "p5cnt") or 1)

		if rcnt then
			need_commit = false
			if r2cnt ~= tonumber(rcnt.band2) then
				uci:set("cloudd", section, "r2cnt", rcnt.band2)
				need_commit = true
			end

			if r5cnt ~= tonumber(rcnt.band5) then
				uci:set("cloudd", section, "r5cnt", rcnt.band5)
				need_commit = true
			end

			if p2cnt ~= tonumber(rcnt.phy2 or 1) then
				uci:set("cloudd", section, "p2cnt", rcnt.phy2 or 1)
				need_commit = true
			end

			if p5cnt ~= tonumber(rcnt.phy5 or 1) then
				uci:set("cloudd", section, "p5cnt", rcnt.phy5 or 1)
				need_commit = true
			end

			if need_commit then
				uci:commit("cloudd")
			end
		end

		c_debug.syslog("info", "device "..id.." cboard config exists "..section)

		return false, section
	end

	local next_cb_idx = 0
	section = dname.."cboard"..next_cb_idx
	while uci:get("cloudd", section) do
		next_cb_idx = next_cb_idx + 1
		section = dname .. "cboard" .. next_cb_idx
	end

	uci:set("cloudd", section, "cboard")
	uci:set("cloudd", section, "pos", pos or 0)
	uci:set("cloudd", section, "name", id .. " #" .. next_cb_idx .. " AP")
	uci:set("cloudd", section, "id", id)
	uci:set("cloudd", section, "r2cnt", rcnt and rcnt.band2 or 1)
	uci:set("cloudd", section, "r5cnt", rcnt and rcnt.band5 or 1)
	uci:set("cloudd", section, "p2cnt", rcnt and rcnt.phy2 or 1)
	uci:set("cloudd", section, "p5cnt", rcnt and rcnt.phy5 or 1)
	uci:set("cloudd", dname, "next_cb_idx", next_cb_idx + 1)

	uci:commit("cloudd")

	return true, section
end

local function cloudd_create_config(id, oid, rcnt, pos)
	local gid
	local ret
	local dname
	local dcboard
	local self_id = cloudd_get_self_id()

	dname = cloudd_create_device_config(oid)
	if dname then
		ret, dcboard = cloudd_create_cboard_config(dname, id, rcnt, pos)

		if self_id == oid then
			gid = "g"..(tonumber(pos)+2)
		end

		if ret and cloudd_create_group_config(id, gid) then
			return true
		end
	end

	cloudd_unused(dcboard)
	return false
end

local function cloudd_set_custom_config(id, section)
	local cfg
	local tmp
	local len

	-- generate custom ssid
	cfg = uci:get_all("cloudd", section) or {}
	for k,v in pairs(cfg) do
		if k:match("ssid_wlan%d*$") then
			len = tonumber(v:match("${MAC(%d+)}") or 0)
			if len > 0 then
				tmp = v:gsub("${MAC%d+}", id:sub(12-len+1))
				uci:set("cloudd", section, k, tmp)
			end
		end
	end
end

function cloudd_create_group_config(id, gid)
	local section = cloudd_get_group(id)

	-- create a group from g0
	if section == c_default_group then
		local g0wlan = uci:get_all("cloudd", c_default_group.."wlan") or {}
		local g0radio = uci:get_all("cloudd", c_default_group.."radio") or {}
		local g0 = uci:get_all("cloudd", c_default_group) or {}
		local next_gid = uci:get("cloudd", "config", "next_group_idx") or 10

		if gid and not uci:get("cloudd", gid) then
			section = gid
		end

		if section == c_default_group then
			section = "g" .. next_gid
			while uci:get("cloudd", section) do
				next_gid = next_gid + 1
				section = "g" .. next_gid
			end
		end

		uci:set("cloudd", section, "group")
		for k,v in pairs(g0) do
			if not k:match("^%.") then
				uci:set("cloudd", section, k, v)
			end
		end
		uci:set_list("cloudd", section, "device", id)

		uci:set("cloudd", section.."wlan", "interface")
		for k,v in pairs(g0wlan) do
			if not k:match("^%.") then
				uci:set("cloudd", section.."wlan", k, v)
			end
		end

		if not uci:get("cloudd", section.."radio") then
			uci:set("cloudd", section.."radio", "radio")
			for k,v in pairs(g0radio) do
				if not k:match("^%.") then
					uci:set("cloudd", section.."radio", k, v)
				end
			end
		end

		cloudd_set_custom_config(id, section.."wlan")

		uci:set("cloudd", "config", "next_group_idx", next_gid + 1)

		uci:commit("cloudd")
	end

	return section
end

local function os_cmd_execute(os_cmd)
	local i_find
	i_find = string.find(os_cmd, ";")

	if i_find ~= nil then
		return
	end

	i_find = string.find(os_cmd, "&&")

	if i_find ~= nil then
		return
	end

	i_find = string.find(os_cmd, "||")

	if i_find ~= nil then
		return
	end

	os.execute(os_cmd)
end

local function cloudd_set_custom_config(id, section)
	local cfg
	local tmp
	local len

	-- generate custom ssid
	cfg = uci:get_all("cloudd", section) or {}
	for k,v in pairs(cfg) do
		if k:match("ssid_wlan%d*$") then
			len = tonumber(v:match("${MAC(%d+)}") or 0)
			if len > 0 then
				tmp = v:gsub("${MAC%d+}", id:sub(12-len+1))
				uci:set("cloudd", section, k, tmp)
			end
		end
	end
end

local function cloudd_get_device(id)
	local _device

	uci:foreach("cloudd", "device",
				function(s)
					if s.id == id then
						_device = { id = id, slave_count = 0, slave = {}, section = s['.name'] }
						return false
					end
				end
	)

	if _device then
		uci:foreach("cloudd", "cboard",
					function(s)
						if s['.name']:match(_device.section .. "cboard") then
							_device.slave_count = _device.slave_count + 1
							_device.slave[_device.slave_count] = { id = s.id, pos = s.pos, dir = false }
						end
					end
		)
	else
		uci:foreach("cloudd", "cboard",
					function(s)
						if s.id == id then
							local _section = s['.name']:match("d%d+")
							local _oid
							local _clients = cloudd_ubus_cloudd_client(1)
							local _directly = true

							-- check if ac can manage cboard directly or not
							for i = 1, _clients.count do
								if _clients.client[i].dir and _clients.client[i].dir == "0" then
									_directly = false
								end
							end

							if _section then
								_oid = uci:get("cloudd", _section, "id")

								if _oid then
									_device = { id = _oid, slave_count = 0, slave = {}, section = s['.name'] }
									_device.slave_count = _device.slave_count + 1
									_device.slave[_device.slave_count] = { id = s.id, pos = s.pos, dir = _directly }
									return false
								end
							end
						end
					end
		)
	end

	return _device or {}
end

local function cloudd_get_cboard(id)
	local cboard
	uci:foreach("cloudd", "cboard",
				function(s)
					if s.id == id then
						cboard = s['.name']
						return
					end
				end
	)

	return cboard
end

local function cloudd_gen_conf_set(index, key, val, tab, prefix)
	for i = 1, #(c_config_sync_array) do
		local c_prefix

		if prefix then
			c_prefix = prefix..c_config_sync_array[i].."#"
		else
			c_prefix = ""
		end

		local option, times = string.gsub(key, c_config_sync_array[i], c_config_sync_array[i]..index)
		if times > 0 then
			local section,_ = string.match(option, "("..c_config_sync_array[i].."%C+)")
			local value
			option = (string.gsub(key, "_"..c_config_sync_array[i].."(%C*)", ""))
			if type(val) ~= "table" then
				value = string.format(
					"wireless.%s.%s=%s",
					section,
					option,
					val
				)
			else
				value = {}

				for j = 1, #val do
					value[j] = string.format(
						"wireless.%s.%s=%s",
						section,
						option,
						val[j]
					)
				end
			end
			tab[c_prefix..option.."_"..section] = value
			break
		end
	end
end

local function cloudd_gen_conf_by_tpl(id, group, tab, prefix)
	local rcnt = { 1, 1 }
	local cboard = id and cloudd_get_cboard(id) or nil
	local tpl
	local config
	local have_config = 0
	local rcnt_start = 0
	local ctpl
	local wlansuffix = {"", "_0", "_1", "_2"}

	if cboard then
		rcnt[1] = tonumber(uci:get("cloudd", cboard, "r2cnt") or 1)
		rcnt[2] = tonumber(uci:get("cloudd", cboard, "r5cnt") or 1)
	end

	-- if no 2.4G, start from 1
	if rcnt[1] == 0 then
		rcnt_start = 1
	end

	-- generate config from template
	tpl = uci:get_list("cloudd", group, "template")
	if tpl and #tpl > 0 then
		for i = rcnt_start, (rcnt[1] + rcnt[2] + rcnt_start - 1)  do
			if i < #tpl then
				config = uci:get_all("cloudd", tpl[i+1])
				ctpl = tpl[i+1]
			else
				config = uci:get_all("cloudd", tpl[1])
				ctpl = tpl[1]
			end

			if config then
				have_config = 1

				-- default bandwidth setting
				if i < rcnt[1] then
					cloudd_gen_conf_set(i, "htmode_radio", "HT20", tab, prefix)
				else
					cloudd_gen_conf_set(i, "htmode_radio", "VHT20", tab, prefix)
				end

				for k,v in pairs(config) do
					if k ~= "name" and not k:match("diff_2_4") and k ~= "suffix" then
						local k1 = string.sub(k, 1, 1)
						local acllist
						if k1 ~= "." then
							if not k:match("acllist") then
								cloudd_gen_conf_set(i, k, v:sub(2), tab, prefix)
							else
								k = k:gsub("acllist", "maclist")
								acllist = uci:get("cloudd_acl", v:sub(2), "nicid") or { "" }
								cloudd_gen_conf_set(i, k, acllist, tab, prefix)
							end
						end
					end
				end

				-- distinguish 2.4G from 5G
				for j = 1, #wlansuffix do
					local diff_opt = "diff_2_4_wlan"..wlansuffix[j]
					-- fixup for wlan.diff_2_4 option
					if config["diff_2_4"] and config["diff_2_4"] == "1" then
						if (config[diff_opt] and config[diff_opt] ~= "X1") or (not config[diff_opt]) then
							config[diff_opt] = "X1"
							uci:set("cloudd", ctpl, diff_opt, "X1")
						end
					end

					if config[diff_opt] and config[diff_opt] == "X1" then
						if i < rcnt[1] then
							-- dependent 2.4G ssid
							local option = "ssid_wlan"..wlansuffix[j]
							local option2 = "diff_2_4_ssid_wlan"..wlansuffix[j]
							if config[option2] and config[option2] ~= "X" then
								cloudd_gen_conf_set(i, option, string.sub(config[option2], 2), tab, prefix)
							else
								local suffix = config["suffix"] or "-2.4G"
								if config[option] and config[option] ~= "X" then
									cloudd_gen_conf_set(i, option, string.sub(config[option], 2)..suffix, tab, prefix)
								end
							end

							-- dependent 2.4G key
							option = "key_wlan"..wlansuffix[j]
							option2 = "diff_2_4_key_wlan"..wlansuffix[j]
							if config[option2] and config[option2] ~= "X" then
								cloudd_gen_conf_set(i, option, string.sub(config[option2], 2), tab, prefix)
							end
						end
					end
				end

				-- delete obsolete uci option
				if config["diff_2_4"] then
					uci:delete("cloudd", ctpl, "diff_2_4")
					uci:commit("cloudd")
				end
			end
		end
	end

	return have_config
end

local function cloudd_get_config_v2(tab, prefix, id)
	local action
	local debug_string
	local c_group
	local have_config

	c_group = cloudd_get_group(id)

	action = uci:get("cloudd", c_group, "action")

	if not action then
		debug_string = c_group .. "don't have action, skip sync config"
		c_debug.syslog("info", debug_string, 1)
		return tab
	end

	tab[prefix] = "group"
	tab[prefix.."#action"] = action

	tab[prefix.."#device"] = {}
	tab[prefix.."#device"][1] = id

	-- generate config from template
	have_config = cloudd_gen_conf_by_tpl(id, c_group, tab, prefix)

	for i=1, #(c_config_sync_array) do
		local config_name = c_group .. c_config_sync_array[i]
		local c_prefix = prefix..c_config_sync_array[i].."#"

		local id_config = uci:get_all("cloudd", config_name)

		if id_config then
			tab[prefix..c_config_sync_array[i]] = id_config[".type"]

			for k,v in pairs(id_config) do
				local k1 = string.sub(k, 1, 1)
				if k1 ~= "." then
					have_config = 1
					if not k:match("acllist") then
						tab[c_prefix..k] = v
					else
						cloudd_generate_acl_maclist(c_prefix..k, v, tab)
					end
				end
			end
		end
	end

	if have_config == 0 then
		return nil
	end

	return tab
end

local function cloudd_device_get_config(id, force)
	local device = cloudd_get_device(id)
	local c_tab = {}
	local sid = cloudd_get_self_id()
	local did = id

	-- check if it's a stand-alone AP device or a compound AP device
	if id ~= sid or force then
		if device and device.slave and (device.id ~= sid or force) then
			for i=1, device.slave_count do
				local slave = device.slave[i]
				local prefix

				-- check if ac can manage device directly
				if not slave.dir then
					if slave.id == device.id then
						prefix = "cloudd#g1"
					else
						prefix = "cloudd#g"..(tonumber(slave.pos) + 2)
					end

					c_tab["version"] = "2"

					c_tab = cloudd_get_config_v2(c_tab, prefix, slave.id)

					c_tab["cloudd#g0wlan"] = "interface"

					if not c_tab["cloudd#g0wlan#ssid_wlan0"] and c_tab[prefix.."wlan#ssid_wlan0"] then
						c_tab["cloudd#g0wlan#ssid_wlan0"] = c_tab[prefix.."wlan#ssid_wlan0"]
					end

					if not c_tab["cloudd#g0wlan#ssid_wlan1"] and c_tab[prefix.."wlan#ssid_wlan1"] then
						c_tab["cloudd#g0wlan#ssid_wlan1"] = c_tab[prefix.."wlan#ssid_wlan1"]
					end

					did = device.id
				else
					if device.slave_count == 1 then
						c_tab = cloudd_get_config(id)
					end
				end
			end
		else
			c_tab = cloudd_get_config(id)
		end
	end

	return c_tab, did
end


local function cloudd_generate_acl_maclist(option, value, tab)
	local maclist = uci:get("cloudd_acl", value, "nicid") or {""}
	local key = (option:gsub("acllist", "maclist"))
	local ifname = option:match("_(wlan%C+)")

	if not maclist then
		return
	end

	if type(maclist) ~= "table" then
		return
	end

	for i = 1, #maclist do
		maclist[i] = "wireless."..ifname..".maclist="..maclist[i]
	end

	if tab then
		tab[key] = maclist
	else
		local cmd = "uci delete wireless."..ifname..".maclist"
		os_cmd_execute(cmd)

		for i = 1, #maclist do
			cmd = "uci add_list '"..maclist[i].."'"
			os_cmd_execute(cmd)
		end
	end
end

local function cloudd_get_config(id, no_tpl)
	local c_tab = {}
	local action
	local debug_string
	local have_config = 0
	local c_group

	c_group = cloudd_get_group(id)

	action = uci:get("cloudd", c_group, "action")

	if action == nil then
		debug_string = c_group .. "don't have action, skip sync config"
		c_debug.syslog("info", debug_string, 1)
		return nil
	end

	c_tab["action"] = action

	-- generate config from template
	if not no_tpl then
		have_config = cloudd_gen_conf_by_tpl(id, c_group, c_tab, nil)
	end

	for i=1, #(c_config_sync_array) do
		local config_name = c_group .. c_config_sync_array[i]

		local id_config = uci:get_all("cloudd", config_name)

		if id_config ~= nil then
			for k,v in pairs(id_config) do
				local k1 = string.sub(k, 1, 1)
				if k1 ~= "." then
					have_config = 1
					if not k:match("acllist") then
						c_tab[k] = v
					else
						cloudd_generate_acl_maclist(k, v, c_tab)
					end
				end
			end
		end
	end

	if have_config == 0 then
		return nil
	end

	return c_tab
end

local function cloudd_calc_table_md5(ctab)
	local md5_val = ""

	for _, v in pairs(ctab)
	do
		if type(v) ~= "table" then
			md5_val = md5_val .. v
		else
			for _, w in pairs(v)
			do
				md5_val = md5_val .. w
			end
		end
	end

	return md5.sumhexa(md5_val)
end

local function cloudd_apply_config(p_data)
	if p_data ~= nil then
		local cmd = nil
		local action_cmd = nil
		local md5_cmd = nil
		local ver = "1"
		local need_restart
		local disabled_radio = {}

		if p_data["version"] then
			ver = p_data["version"]
		end

		if ver == "1" then
			if p_data["md5"] == nil then
				return
			end
			local c_md5 = uci:get("cloudd", "config", "md5")

			if c_md5 ~= nil then
				if c_md5 == p_data["md5"] then
					c_debug.syslog("info", "config md5 is the same", 1)
					return
				end
			end

			for k, v in pairs(p_data)
			do
				if k == "md5" then
					md5_cmd = "uci set cloudd.config.md5=" .. v
				elseif k == "action" then
					action_cmd = v
				else
					if type(v) ~= "table" then
						cmd = "uci -q set " .. cjson.encode(v)
						os_cmd_execute(cmd:gsub("\\/", "/"):gsub("%$", "\\%$"))

						if v:match("wireless.radio%d.channel=%-1") or v:match("wireless.radio%d.disall=1") then
							local radio_name = v:match("radio%d")
							disabled_radio[radio_name] = true
						end
					else
						cmd = nil
						for _, w in pairs(v)
						do
							if cmd == nil then
								local uci_list = w:match("([^=]+)=")
								local uci_item = util.split(uci_list, ".", 3)
								local cur_list
								local cur_md5
								local new_md5

								if #uci_item == 3 then
									cur_list = uci:get(uci_item[1], uci_item[2], uci_item[3]) or {""}

									for i = 1, #cur_list
									do
										cur_list[i] = uci_list.."="..cur_list[i]
									end
									cur_md5 = cloudd_calc_table_md5(cur_list)
									new_md5 = cloudd_calc_table_md5(v)

									if cur_md5 == new_md5 then
										c_debug.syslog("info", uci_list.." md5 is the same, skip.")
										break
									end
								end

								cmd = "uci del " .. uci_list
								os_cmd_execute(cmd)
							end

							cmd = "uci add_list " .. w
							os_cmd_execute(cmd)
						end
					end
				end
			end

			-- disabled wireless interface if radio channel is -1
			for k, _ in pairs(disabled_radio)
			do
				uci:foreach("wireless", "wifi-iface",
							function(s)
								if s.device == k then
									cmd = "uci set wireless." .. s[".name"] .. ".disabled=1"
									os_cmd_execute(cmd)
								end
							end
				)
			end
		elseif ver == "2" then
			if p_data["md5"] == nil then
				return
			end
			local c_md5 = uci:get("cloudd", "config", "md5_v2")

			if c_md5 ~= nil then
				if c_md5 == p_data["md5"] then
					c_debug.syslog("info", "config md5 v2 is the same", 1)
					return
				end
			end

			cloudd_device_apply_config(p_data)
			return
		else
			c_debug.syslog("info", "unknown ver: "..ver, 1)
			return
		end

		if md5_cmd ~= nil then
			os.execute(md5_cmd)
		end

		-- commit config
		os.execute("uci commit")

		os.execute("wifi")
	end
end

function cloudd_self_apply(apply_tpl)
	local self_id = cloudd_get_self_id()
	local c_tab, c_tmp
	local c_md5

	c_tab = cloudd_get_config(self_id, not apply_tpl)

	if c_tab == nil then
		return
	end

	c_tmp = cloudd_device_get_config(self_id, true)

	c_md5 = cloudd_calc_table_md5(c_tmp)

	c_tab["md5"] = c_md5

	return cloudd_apply_config(c_tab)
end

function cloudd_sync_config()
	local sid = cloudd_get_self_id()
	local rcnt = {band2 = 1, band5 = 0, phy2 = 1, phy5 = 0}
	local dummy

	if not fs.access("/etc/config/wireless") then
		c_debug.syslog("info", "don't have wireless config", 1)
		return
	end

	if cloudd_create_config(sid, sid, rcnt, -1) then
		-- custom template config
		cloudd_set_custom_config(sid, "t0")
		uci:commit("cloudd")

		cloudd_self_apply(true)

		-- update radio count
		cloudd_create_config(sid, sid, rcnt, -1)
	end

	cloudd_unused(dummy)
end

local function cloudd_rt_mesh_disable()
	local ptype = uci:get("oem", "board", "ptype") or ""
	local enabled = uci:get("mesh", "config", "enabled") or "1"

	if ptype ~= "rt" then
		return
	end

	if fs.access("/etc/config/mesh") and enabled == "1" then
		return
	end

	uci:foreach("wireless", "wifi-device",
				function(s)
					uci:set("wireless", s['.name'], "nrctrl_mode", "0")
					uci:set("cloudd", "g1radio", "nrctrl_mode_"..s[".name"], "wireless."..s[".name"]..".nrctrl_mode=0")
				end
	)

	local changes = uci:changes()
	if changes then
		if changes.wireless then
			uci:commit("wireless")
			uci:commit("cloudd")
			os.execute("wifi >/dev/null 2>/dev/null")
		end
	end
end

function cloudd_luci_action()
	cloudd_rt_mesh_disable()
end

function cloudd_ubus_cloudd_client(brief)
	local options = {brief = brief and brief or 0, start = 0}
	local clients = {count = 0, client = {}}
	local tmp

	while true do
		tmp = util.ubus("cloudd", "client", options)
		if not tmp then
			print("break")
			break
		end

		if tmp.client then
			for i = 1, #tmp.client do
				clients.count = clients.count + 1
				clients.client[clients.count] = tmp.client[i]
			end
		end

		if tmp.start + tmp.count >= tmp.tcount then
			break
		end

		options.start = tmp.start + tmp.count
	end

	return clients
end

function cloudd_enum_device_status(status)
	local status_tbl = {
		status_offline            = 0,
		status_connecting         = 1,
		status_connected          = 2,
		status_upgrade_preparing  = 3,
		status_upgrading          = 4,
		status_upgrade_error      = 5,
		status_rebooting          = 6,
		status_resetting          = 7
	}

	return status_tbl[status] or status_tbl.status_offline
end

function cloudd_generate_local_radio()
	local rv = { }
	local rcnt = { band2 = 0, band5 = 0, phy2 = 0, phy5 = 0, chlist = {} , skip_channels = {}}
	for _, dev in ipairs(ntm:get_wifidevs()) do
		local band = uci:get("wireless", dev:name(), "band") or nil
		local disabled = tonumber(uci:get("wireless", dev:name(), "disabled") or 0)
		local chlist = uci:get_list("wireless", dev:name(), "chlist")
		local skip_channels = uci:get_list("wireless", dev:name(), "skip_channels")
		local channel = uci:get("wireless", dev:name(), "channel")

		if band then
			if band == "5g" then
				if disabled == 0 then
					rcnt.band5 = rcnt.band5 + 1
				end

				rcnt.phy5 = rcnt.phy5 + 1
			elseif band == "2g" then
				if disabled == 0 then
					rcnt.band2 = rcnt.band2 + 1
				end

				rcnt.phy2 = rcnt.phy2 + 1
			end
			rcnt.chlist[dev:name()] = {chlist = chlist, channel = channel,skip_channels = skip_channels}
		end

		for _, net in ipairs(dev:get_wifinets()) do
			local status = util.ubus("wireless", "status", {device = net:ifname()})
			if status and (status.up == true) then
				local iface = ntm:get_interface(net:ifname())
				local assoclist
				local encr = uci:get("wireless", net:name(), "encryption") or "none"
				local ppsk_cfg = uci:get("wireless", net:name(), "ppsk_cfg") or nil
				local nrdev = uci:get("wireless", net:name(), "nrdev") or "0"

				if not ppsk_cfg and encr == "ppsk" then
					ppsk_cfg = "p0_ac"
				end

				rv[#rv+1] = {
					name       = net:name(),
					mode       = net:active_mode(),
					ssid       = net:active_ssid(),
					bssid      = net:active_bssid(),
					encryption = net:active_encryption(),
					frequency  = net:frequency(),
					channel    = net:channel(),
					quality    = net:signal_percent(),
					bitrate    = net:bitrate(),
					assoclist  = net:assoclist(),
					txbytes    = iface:tx_bytes(),
					rxbytes    = iface:rx_bytes(),
					ppsk_cfg   = ppsk_cfg,
					nrdev      = nrdev,
				}

				assoclist = rv[#rv].assoclist or {}
				for mac,info in pairs(assoclist) do
					if clinfo[mac] then
						info.hostname = clinfo[mac].hostname
						info.ipaddr = clinfo[mac].ipaddr
					end
				end
			end
		end
	end

	return rv, rcnt
end

local function cloudd_send_self_config(proto)
	local sid = cloudd_get_self_id()
	local section = nil
	local cboard_num = 0

	-- send config to cboards
	uci:foreach("cloudd", "device",
				function(s)
					if s.id == sid then
						section = s[".name"]
						cboard_num = tonumber(s.next_cb_idx and s.next_cb_idx or 0)
						return false
					end
				end
	)

	if section then
		for i = 0, cboard_num - 1 do
			local id = uci:get("cloudd", section.."cboard"..i, "id")

			if id and id ~= sid then
				cloudd_send_config(id, proto)
			end
		end
	end

	-- apply to own board
	cloudd_self_apply(true)
end

function cloudd_send_config(d_id, proto)
	local c_tab
	local c_md5
	local r_topic = "config"
	local id
	local sid = cloudd_get_self_id()

	-- update uci cursor
	uci = require "luci.model.uci".cursor()

	if sid == d_id then
		cloudd_send_self_config(proto)
		return
	end

	c_debug.syslog("err", "not support send config to other device", 1)
end

-- g_id: group id
-- sync config to group
function cloudd_send_config_group(g_id, proto)
	-- do nothing
end

function cloudd_get_local_sversion()
	local file = io.open("/etc/openwrt_version", "r")
	local f_data = nil

	if file ~= nil then
		f_data = file:read("*l")
		file:close()
	end

	return f_data
end

-- send status to all group
function cloudd_send_status_all_group(proto)
	-- do nothing
end
