local os, io, string, debug = os, io, string, debug
local pairs, ipairs, type, tonumber, unpack ,tostring = pairs, ipairs, type, tonumber, unpack, tostring
local print, table = print, table
local require = require
local nixio = require "nixio"
local md5 = require "md5"
local c_debug = require "cloudd.debug"
local util = require "luci.util"
local uci = require "uci".cursor()
local ntm = require "luci.model.network".init()
local cjson = require "cjson"
local cloudd = require "cloudd.cloudd"
local c_lock = require "cloudd.lock"
local c_firmware = require "cloudd.firmware"
local c_default_group = "g0"
local c_config_sync_array = {"radio", "wlan"}
local c_default_firmware_dir = "/opt/firmware/"
local c_md5file = require "cloudd.md5file"
local l_sys = require "luci.sys"
local fs = require "nixio.fs"
local socket = require "socket"
local redis

if pcall(require, "redis") then
	redis = require "redis"
end

local redis_cli = nil
local expire = uci:get("report-status-daemon", "station", "expire") or 86400

module ("cloudd.api")

local lock_file = nil

local function cloudd_get_platform()
	if fs.access("/sbin/swconfig")then
		return "qca"
	else
		return "mtk"
	end
end

local cloudd_platform = cloudd_get_platform()

local function cloudd_unused()
	-- function to avoid unused warning...
end

local function cloudd_vlan_remove(br_list)

	-- delete redundant network
	uci:delete_all("network", "interface",
		function(s)
			if s[".name"]:match("^lan%d+") and not br_list[s[".name"]] and s["no_wifi_check"] ~= "1" then
				c_debug.syslog("info", "delete "..s[".name"], 1)
				return true
			end
		end
	)
end

local function cloudd_vlan_set(br_list)
	local igmp_snooping

	igmp_snooping = uci:get("network", "lan", "igmp_snooping") or 0
	for k, v in pairs(br_list) do
		local ifname = "eth0"

		if k:match("^lan[0-9]+$") then
			if not uci:get_all("network", k) then
				-- create lan device
				c_debug.syslog("info", "create network "..k, 1)

				uci:set("network", k, "interface")
				uci:set("network", k, "type", "bridge")
				uci:set("network", k, "proto", "static")
				uci:set("network", k, "igmp_snooping", igmp_snooping)
			end

			if v ~= "0" then
				ifname = ifname.."."..v
			end

			uci:set("network", k, "ifname", ifname)
		end
	end

end

function connect_redis(host, port)
	if not redis then
		return redis_cli
	end

	local client = redis.connect(host and host or '127.0.0.1', port and port or 6379)
	local response = client:ping()

	if response then
		redis_cli = client
	end

	return redis_cli
end

local function cloudd_lock()
	c_debug.syslog("info", "try get cloudd lock", 1)
	if lock_file then
		c_debug.syslog("info", "already get cloudd lock", 1)
		return
	end
	lock_file = c_lock.flock("cloudd_lock")
	c_debug.syslog("info", "get cloudd lock", 1)
end

local function cloudd_unlock()
	if lock_file then
		c_debug.syslog("info", "release cloudd lock", 1)
		c_lock.unlock(lock_file)
		lock_file = nil
	end
end

function cloudd_script_lock(script)
	local lockfile = nil
	c_debug.syslog("info", "try get "..script.." cloudd lock", 1)
	lockfile = c_lock.trylock("cloudd_lock_"..script)
	if not lockfile then
		c_debug.syslog("info", "failed to get "..script.." cloudd lock", 1)
	end
	return lockfile
end

function cloudd_script_unlock(script)
	c_debug.syslog("info", "release "..script.." cloudd lock", 1)
	c_lock.unlock("cloudd_lock_"..script)
end

local function cloudd_reload_mosq()
	l_sys.call("/etc/init.d/mosquitto reload")
	l_sys.call("sleep 1")
	l_sys.call("pidof mosquitto|xargs kill -SIGHUP")
end

function cloudd_reload_mosq_safe()
	cloudd_lock()
	cloudd_reload_mosq()
	cloudd_unlock()
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

local function cloudd_execute_command(cmd)
	local ret = "1"
	local output = ""
	local t = io.popen(cmd..';echo -n "ret=$?"')
	local a

	if not t then
		return ret, output
	end

	a = t:read("*all")

	ret = a:match("ret=(%d+)") or "0"
	output = a:gsub("ret="..ret, "")

	t:close()
	return ret, output
end

function cloudd_get_client_info()
	local clinfo = {}

	if not fs.access("/etc/config/cimd") then
		return clinfo
	end

	clinfo = util.ubus("cimd", "status") or {}

	return clinfo
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

local function cloudd_create_device_config(id, cloud)
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
		uci:set("cloudd", section, "cloud", cloud and "1" or "0")

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

local function cloudd_set_map_config(id, section)
	local map = uci:get("mesh", "config", "enabled") or "0"

	if map ~= "1" then
		return
	end

	uci:set("cloudd", section, "disabled_wlan0_2", "wireless.wlan0_2.disabled=0")
	uci:set("cloudd", section, "disabled_wlan1_2", "wireless.wlan1_2.disabled=0")
	uci:set("cloudd", section, "disabled_wlan2_2", "wireless.wlan2_2.disabled=0")
	uci:set("cloudd", section, "hidden_wlan0_2", "wireless.wlan0_2.hidden=1")
	uci:set("cloudd", section, "hidden_wlan1_2", "wireless.wlan1_2.hidden=1")
	uci:set("cloudd", section, "hidden_wlan2_2", "wireless.wlan2_2.hidden=1")
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

function cloudd_sync_action(cb)
	clients = util.ubus("cloudd", "client") or {}

	if not clients.client then
		return
	end

	for i = 1, #clients.client do
		local client = clients.client[i]
		if (not client.dir or client.dir == "1") and client.id then
			cb(client.id, "mqtt")
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

		cloudd_set_map_config(id, section.."wlan")

		cloudd_set_custom_config(id, section.."wlan")

		uci:set("cloudd", "config", "next_group_idx", next_gid + 1)

		uci:commit("cloudd")
	end

	return section
end

function cloudd_get_all_group(group_array)
	group_array = group_array or {}

	uci:foreach("cloudd", "group",
					function(s)
						local g_tmp_name = s['.name']
						table.insert(group_array, g_tmp_name)
					end)

	return group_array
end

function cloudd_get_self_id()
	local id = uci:get("oem", "board", "id") or ""
	local c_info = util.ubus("cloudd", "info") or { mac = id:gsub(":", "") }
	return c_info.mac
end

function cloudd_get_report_id()
	local c_info = util.ubus("cloudd", "info") or { }
	return c_info.id
end

local function cloudd_get_owner_id()
	local oid = uci:get("cloudd", "config", "oid") or cloudd_get_self_id()

	return oid
end

local function cloudd_get_position()
	local pos = uci:get("oem", "board", "pos") or nil

	return pos
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

local function cloudd_gen_sniff_conf(id, tab, prefix)
	local rcnt = { 1, 1 }
	local cboard = id and cloudd_get_cboard(id) or nil
	local sniffer_enable = uci:get("sniffer", "config", "enable") or 0
	local rcnt_end

	if cboard then
		rcnt[1] = tonumber(uci:get("cloudd", cboard, "r2cnt") or 1)
		rcnt[2] = tonumber(uci:get("cloudd", cboard, "r5cnt") or 1)
	end

	-- if no 2.4G, start from 1
	if rcnt[1] == 0 then
		rcnt_end = rcnt[2] + 1
	else
		rcnt_end = rcnt[1] + rcnt[2]
	end

	for i = 0, rcnt_end do
		cloudd_gen_conf_set(i, "sniffer_radio", sniffer_enable, tab, prefix)
	end
end

local function cloudd_gen_mcast_conf(id, tab, prefix)
	local rcnt = { 1, 1 }
	local cboard = id and cloudd_get_cboard(id) or nil
	local enhance = uci:get("mcast", "config", "enhance") or 1
	local mcsrate = uci:get("mcast", "config", "mcsrate") or -1
	local rcnt_end

	if cboard then
		rcnt[1] = tonumber(uci:get("cloudd", cboard, "r2cnt") or 1)
		rcnt[2] = tonumber(uci:get("cloudd", cboard, "r5cnt") or 1)
	end

	-- if no 2.4G, start from 1
	if rcnt[1] == 0 then
		rcnt_end = rcnt[2] + 1
	else
		rcnt_end = rcnt[1] + rcnt[2]
	end

	for i = 0, rcnt_end do
		cloudd_gen_conf_set(i, "mcastenhance_radio", enhance, tab, prefix)
		cloudd_gen_conf_set(i, "mcsrate_radio", mcsrate, tab, prefix)
	end
end

local function cloudd_gen_nrmesh_conf(id, tab, prefix)
	local enable = uci:get("nrmesh", "mesh", "enable") or "0"
	local midx = tonumber(uci:get("nrmesh", "mesh", "midx") or "2")
	local ssid = uci:get("nrmesh", "mesh", "ssid") or "@#!nRadiOMeSH!#@"

	if enable == "1" then
		local suffix = {"", "_0", "_1", "_2"}
		local rcnt = { 1, 1 }
		local cboard = id and cloudd_get_cboard(id) or nil
		local rcnt_start = 0
		local rcnt_end

		if cboard then
			rcnt[1] = tonumber(uci:get("cloudd", cboard, "r2cnt") or 1)
			rcnt[2] = tonumber(uci:get("cloudd", cboard, "r5cnt") or 1)
		end

		-- if no 2.4G, start from 1
		if rcnt[1] == 0 then
			rcnt_start = 1
			rcnt_end = rcnt[2] + 1
		else
			rcnt_end = rcnt[1] + rcnt[2]
		end

		for i = rcnt_start, rcnt_end do
			cloudd_gen_conf_set(i, "nrctrl_mode_radio", "1", tab, prefix)
			cloudd_gen_conf_set(i, "nrdev_wlan"..suffix[midx + 1], "1", tab, prefix)
			cloudd_gen_conf_set(i, "disabled_wlan"..suffix[midx + 1], "0", tab, prefix)
			cloudd_gen_conf_set(i, "hidden_wlan"..suffix[midx + 1], "1", tab, prefix)
			cloudd_gen_conf_set(i, "ssid_wlan"..suffix[midx + 1], ssid, tab, prefix)
			cloudd_gen_conf_set(i, "encryption_wlan"..suffix[midx + 1], "ppsk", tab, prefix)
		end
	end
end

local function cloudd_device_match_cboard(id)
	local sid = cloudd_get_self_id()

	if id ~= sid  then
		local device = cloudd_get_device(sid)
		if device and device.slave then
			if device.id == id then
				return true
			end
			for i=1, device.slave_count do
				local slave = device.slave[i]
				if slave and slave.id == id then
					return true
				end
			end
		end
	else
		return true
	end

	return false
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

				if cloudd_device_match_cboard(id) then
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

local function cloudd_handle_vlan()
	local br_list = {}
	local need_restart = false
	local lan_ifname = uci:get("network", "lan", "ifname") or ""

	if cloudd_platform == "mtk" then
		if lan_ifname ~= "eth0" then
			c_debug.syslog("info", "not support vconfig, skip", 1)
			return need_restart
		end
	end

	uci:foreach("wireless", "wifi-iface",
				function(s)
					local modified = false
					if s[".name"]:match("^wlan") then
						if s.network then
							if s.vlan and s.vlan ~= "0" then
								if s.network:match("%d+") ~= s.vlan then
									s.network = "lan"..s.vlan
									modified = true
								end
							else
								if s.network ~= "lan" then
									s.network = "lan"
									modified = true
								end
							end
						else
							if s.vlan and s.vlan ~= "0" then
								s.network = "lan"..s.vlan
								modified = true
							else
								s.network = "lan"
								modified = true
							end
						end

						if s.vlan then
							br_list[s.network] = s.vlan
						else
							br_list[s.network] = "0"
						end

						if modified then
							uci:set("wireless", s[".name"], "network", s.network)
							need_restart = true
						end
					end
				end
	)

	cloudd_vlan_remove(br_list)
	cloudd_vlan_set(br_list)

	local changes = uci:changes()
	if changes then
		if changes.network then
			uci:commit("network")
		end
		if changes.wireless then
			uci:commit("wireless")
		end
	end

	return need_restart
end

local function cloudd_handle_sniffer()
	local enable_probe = false
	local enable_sniffer_2 = false
	local enable_sniffer_5 = false
	local bitmap = 0
	local sniff_channel_2 = {1, 6, 11}
	local sniff_channel_5 = {36, 52, 149, 165}
	local sniff_channel = {}

	if not fs.access("/etc/config/wm") then
		return false
	end

	uci:foreach("wireless", "wifi-device",
				function(s)
					if s.sniffer and s.sniffer == "1" then
						if s.disabled and s.disabled == "1" or s.channel == "-1" then
							if s.band then
								if s.band:match("2") then
									enable_sniffer_2 = true
								else
									enable_sniffer_5 = true
								end
							end
						else
							enable_probe = true
						end
					end
				end
	)

	if enable_probe then
		uci:set("wm", "probe", "module")
	end

	uci:set("wm", "probe", "enable", enable_probe and 1 or 0)

	if enable_sniffer_2 or enable_sniffer_5 then
		uci:set("wm", "sniffer", "module")

		if enable_sniffer_2 then
			bitmap = 1
			for i = 1, #sniff_channel_2 do
				sniff_channel[#sniff_channel + 1] = sniff_channel_2[i]
			end
		end

		if enable_sniffer_5 then
			if bitmap == 1 then
				bitmap = 3
			else
				bitmap = 2
			end

			for i = 1, #sniff_channel_5 do
				sniff_channel[#sniff_channel + 1] = sniff_channel_5[i]
			end
		end

		uci:set_list("wm", "sniffer", "channel", sniff_channel)
	end

	uci:set("wm", "sniffer", "bitmap", bitmap)

	local changes = uci:changes()
	if changes and changes.wm then
		uci:commit("wm")
		return true
	end

	return false
end

local function cloudd_handle_mcast()
	local qca_platform = false
	local radios = {}

	uci:foreach("wireless", "wifi-device",
				function(s)
					local mcsrate = s["mcsrate"] or "-1"
					local enhance = s["mcastenhance"] or "1"

					if s.type == "qcawifi" then
						qca_platform = true
						radios[s[".name"]] = {mcsrate = mcsrate, enhance = enhance}
					else
						if enhance == "2" then
							uci:set("wireless", s[".name"], "igmpsn", "1")
							uci:set("wireless", s[".name"], "mldsn", "0")
						else
							uci:set("wireless", s[".name"], "igmpsn", enhance)
							uci:set("wireless", s[".name"], "mldsn", "1")
						end
						uci:set("wireless", s[".name"], "mcast_rate", (mcsrate == "-1") and "3" or mcsrate)
					end
				end
	)

	if qca_platform then
		local rate_tbl = {
			mcs0 = 6000,
			mcs1 = 9000,
			mcs2 = 12000,
			mcs3 = 18000,
			mcs4 = 24000,
			mcs5 = 36000,
			mcs6 = 48000,
			mcs7 = 54000
		}

		uci:foreach("wireless", "wifi-iface",
					function(s)
						if not s["ifname"] or not s["device"] then
							return false
						end

						local mr_val
						local mcastenhance = (radios[s["device"]].enhance == "0") and 0 or 2
						local mcsrate = radios[s["device"]].mcsrate or "-1"

						uci:set("wireless", s[".name"], "mcastenhance", mcastenhance)
						if mcsrate ~= "-1" then
							mr_val = rate_tbl["mcs"..mcsrate] or 11000
							uci:set("wireless", s[".name"], "mcast_rate", mr_val)
						else
							uci:delete("wireless", s[".name"], "mcast_rate")
						end
					end
		)
	end

	uci:commit("wireless")
end

local function cloudd_handle_nrmesh()
	if not fs.access("/etc/config/wm") or not fs.access("/etc/config/msad") then
		return false
	end

	local mode = uci:get("wm", "nrctrl", "mode") or "0"
	local nrctrl_mode = "0"

	uci:foreach("wireless", "wifi-device",
				function(s)
					if s.nrctrl_mode and s.nrctrl_mode == "1" then
						nrctrl_mode = "1"
					end
				end
	)

	if (nrctrl_mode == "1" and mode ~= "1") then
		uci:set("wm", "nrctrl", "module")
		uci:set("wm", "nrctrl", "mode", "1")
		uci:commit("wm")
	end
	if (nrctrl_mode == "0" and mode ~= "0") then
		uci:set("wm", "nrctrl", "module")
		uci:set("wm", "nrctrl", "mode", "0")
		uci:commit("wm")
	end

	local msad_mode = uci:get("msad", "msad", "mode") or "1"
	local n_msad_mode = msad_mode

	-- set msad to mode AC if device isn't cboard and it's a CAP now
	if msad_mode ~= "0" and nrctrl_mode == "1" then
		n_msad_mode = "145"
	end

	if msad_mode ~= n_msad_mode then
		uci:set("msad", "msad", "mode", n_msad_mode)
		uci:commit("msad")
	end
end

local function cloudd_sync_apbd2()
	if not fs.access("/etc/config/apbd2") then
		return
	end

	local ssid = uci:get("wireless", "wlan1", "ssid") or nil
	local g_ssid = uci:get("apbd2", "g1", "ssid") or nil

	if g_ssid and ssid and g_ssid ~= ssid then
		uci:set("apbd2", "g1", "ssid", ssid)
		uci:commit("apbd2")
	end
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

	-- generate sniffer config
	cloudd_gen_sniff_conf(id, c_tab, nil)

	-- generate mcast config
	cloudd_gen_mcast_conf(id, c_tab, nil)

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

	-- genenrate nrmesh config
	if id == cloudd_get_self_id() then
		cloudd_gen_nrmesh_conf(id, c_tab, nil)
	end

	if have_config == 0 then
		return nil
	end

	return c_tab
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

	-- generate sniff config
	cloudd_gen_sniff_conf(id, tab, prefix)

	-- generate mcast config
	cloudd_gen_mcast_conf(id, tab, prefix)

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
	local nr = require "luci.nradio"
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
			if nr.support_mesh and nr.support_mesh() then
				return nil, nil
			else
				c_tab = cloudd_get_config(id)
			end
		end
	end

	return c_tab, did
end

local function cloudd_get_group_config(g_id)
	local c_tab = {}
	local action
	local debug_string
	local have_config

	action = uci:get("cloudd", g_id, "action")

	if action == nil then
		debug_string = g_id .. "don't have action, skip sync config"
		c_debug.syslog("info", debug_string, 1)
		return nil
	end

	c_tab["action"] = action

	-- generate sniff config
	cloudd_gen_sniff_conf(nil, c_tab, nil)

	-- generate mcast config
	cloudd_gen_mcast_conf(nil, c_tab, nil)

	-- generate config from template
	have_config = cloudd_gen_conf_by_tpl(nil, g_id, c_tab, nil)

	for i=1, #(c_config_sync_array) do
		local config_name = g_id .. c_config_sync_array[i]
		uci:load("cloudd")

		local id_config = uci:get_all("cloudd", config_name)
		if id_config ~= nil then
			for k,v in pairs(id_config) do
				local k1 = string.sub(k, 1, 1)
				if k1 ~= "." then
					have_config = 1
					c_tab[k] = v
				end
			end
		end
	end

	if have_config == 0 then
		return nil
	end

	return c_tab
end

local function cloudd_file_exist(filename)
	local file = io.open(filename, "rb")
	if file then
		file:close()
	end

	return file ~= nil
end

local function cloudd_wifi_bwlist(phyname, band)
	local bwlist = {
		mt7620 = {band2 = {"20", "40"}, band5 = {}},
		mt7612e = {band2 = {}, band5 = {"20", "40", "80"}},
		mt7615e = {band2 = {"20", "40"}, band5 = {"20", "40", "80"}},
		mt7628 = {band2 = {"20", "40"}, band5 = {}},
		mt7915 = {band2 = {"20", "40"}, band5 = {"20", "40", "80"}},
		mt7981 = {band2 = {"20", "40"}, band5 = {"20", "40", "80", "160"}},
		mt7993 = {band2 = {"20", "40"}, band5 = {"20", "40", "80", "160"}},
		swt6652 = {band2 = {"20", "40"}, band5 = {"20", "40", "80"}},
		aic8800 = {band2 = {"20", "40"}, band5 = {"20", "40", "80"}}
	}
	return bwlist[phyname] and bwlist[phyname][band] or {}
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

function cloudd_get_dest_version(id)
	local c_group
	local dversion

	c_group = cloudd_get_group(id)
	dversion = uci:get("cloudd", c_group, "dest_version")

	return dversion
end

function cloudd_get_dest_version_group(g_id)
	local dversion

	dversion = uci:get("cloudd", g_id, "dest_version")

	return dversion
end

function cloudd_get_firmware_url(id)
	local c_group
	local curl

	c_group = cloudd_get_group(id)
	curl = uci:get("cloudd", c_group, "url")

	return curl
end

function cloudd_get_firmware_url_group(g_id)
	local curl = uci:get("cloudd", g_id, "url")

	return curl
end

function cloudd_get_firmware_time(id)
	local c_group
	local upgrade_time

	c_group = cloudd_get_group(id)
	upgrade_time = uci:get("cloudd", c_group, "upgrade_time")

	return upgrade_time
end

function cloudd_get_firmware_upgrade_mode(id)
	local c_group
	local upgrade_mode

	c_group = cloudd_get_group(id)
	upgrade_mode = uci:get("cloudd", c_group, "upgrade_mode")

	return upgrade_mode
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
	cloudd_self_apply(true, false)
end

-- d_id: device id
-- sync config to device d_id
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

	c_tab,id = cloudd_device_get_config(d_id, false)

	if c_tab == nil then
		return
	end

	c_md5 = cloudd_calc_table_md5(c_tab)

	c_tab["md5"] = c_md5

	cloudd.cloudd_send(id, r_topic, c_tab, proto, 0)
end

-- g_id: group id
-- sync config to group
function cloudd_send_config_group(g_id, proto)
	local c_tab
	local c_md5
	local r_topic = "config"
	local d_id
	local self_id = cloudd_get_self_id()

	c_tab = cloudd_get_group_config(g_id)

	if c_tab == nil then
		return
	end

	d_id = self_id .. ":" .. g_id
	c_md5 = cloudd_calc_table_md5(c_tab)

	c_tab["md5"] = c_md5

	cloudd.cloudd_send(d_id, r_topic, c_tab, proto, 0)
end

-- sync group config to board
function cloudd_self_apply(apply_tpl, not_apply)
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

	return cloudd_apply_config_safe(c_tab, not_apply)
end
local function cloudd_cpe_apply_config(p_data)
	local keys
	local pat = "#"
	local check_section = {}
	local configs = {}

	for k, v in pairs(p_data) do
		keys = util.split(k, pat, 3)
		if keys and #keys == 3 then
			local _config = keys[1]
			local _section = keys[2]
			local _option = keys[3]
			local _tmp = _config.."#".._section
			local _valid = true

			-- check if section exists
			if check_section[_tmp] == nil then
				if p_data[_tmp] == nil then
					_valid = false
				else
					check_section[_tmp] = p_data[_tmp]
					if uci:get(_config, _section) == nil then
						c_debug.syslog("info", "create a new "..check_section[_tmp].." named ".._section)
						uci:set(_config, _section, check_section[_tmp])
					end
				end
			end

			if _valid == true then
				configs[_config] = true
				if type(v) ~= "table" then
					uci:set(_config, _section, _option, v)
				else
					uci:set_list(_config, _section, _option, v)
				end
			end
		end

	end

	-- commit config
	for config,_ in pairs(configs) do
		uci:commit(config)
	end
end
local function cloudd_device_apply_config(p_data)
	local keys
	local pat = "#"
	local check_section = {}
	local slaves = {}
	local sections = {}
	local id = cloudd_get_self_id()
	local configs = {}

	for k, v in pairs(p_data) do
		if k == "md5" then
			uci:set("cloudd", "config", "md5_v2", v)
		elseif k ~= "version" then
			keys = util.split(k, pat, 3)
			if keys and #keys == 3 then
				local _config = keys[1]
				local _section = keys[2]
				local _option = keys[3]
				local _tmp = _config.."#".._section
				local _valid = true

				-- check if section exists
				if check_section[_tmp] == nil then
					if p_data[_tmp] == nil then
						_valid = false
					else
						check_section[_tmp] = p_data[_tmp]
						if uci:get(_config, _section) == nil then
							c_debug.syslog("info", "create a new "..check_section[_tmp].." named ".._section)
							uci:set(_config, _section, check_section[_tmp])
							uci:commit(_config)
						end
					end
				end

				if _option == "device" then
					if type(v) == "table" then
						for i = 1, #v do
							slaves[#slaves + 1] = v[i]
							sections[#sections + 1] = _section
						end
					end
				end

				if _valid == true then
					configs[_config] = true
					if type(v) ~= "table" then
						uci:set(_config, _section, _option, v)
					else
						uci:set_list(_config, _section, _option, v)
					end
				end
			end
		end
	end

	-- delete redundant/invalid group config
	for i = 1, #slaves do
		local _sections = {}
		uci:delete_all("cloudd", "group",
					   function(s)
						   -- invalid group config
						   if not s.device and s[".name"] ~= c_default_group then
							   return true
						   end

						   if s.device and type(s.device) ~= "table" then
							   return true
						   end

						   if s.device then
							   for j = 1, #s.device do
								   if s.device[j] == slaves[i] and s[".name"] ~= sections[i] then
									   _sections[#_sections + 1] = s[".name"]
									   return true
								   end
							   end
						   end
					   end
		)

		for j = 1, #_sections do
			uci:delete("cloudd", _sections[j].."wlan")
			uci:delete("cloudd", _sections[j].."radio")
		end
	end

	-- commit config
	for config,_ in pairs(configs) do
		uci:commit(config)
	end

	-- send/apply config to devices
	for i = 1, #slaves do
		if slaves[i] ~= id then
			cloudd_update_config(slaves[i], "mqtt")
		else
			cloudd_self_apply(false, false)
		end
	end

	-- restart apbd2 for no wifi mboard
	if not fs.access("/etc/config/wireless") then
		os.execute("/etc/init.d/apbd2 restart")
	end

	-- reload mqtt config
	cloudd_reload_mosq()
end

local function cloudd_extra_action(action_cmd, need_restart)
	-- check MTK 8021xd
	if fs.access("/usr/sbin/8021xd") then
		action_cmd = action_cmd..";8021xd"
	end

	-- check wm
	if fs.access("/usr/sbin/wm") then
		action_cmd = action_cmd..";wm"
	end

	-- check apbd2
	if fs.access("/usr/sbin/apbd2") then
		action_cmd = action_cmd..";apbd2"
	end

	-- check msad
	if fs.access("/usr/sbin/msad") then
		action_cmd = action_cmd..";msad"
	end

	-- check guest
	if fs.access("/usr/sbin/guest.lua") then
		action_cmd = action_cmd..";guest"
	end

	if need_restart then
		action_cmd = action_cmd..";mosquitto"
	end

	return action_cmd
end

local function cloudd_apply_htmode(k, v)
	local radio = k:match("^htmode_(.+)")
	local cmd
	local bw = v:match("%d+$")
	local hwmode = util.exec("uci -q get wireless."..radio..".hwmode|xargs printf")
	local htmode = "HT"..bw
	
	if hwmode == "11be" then
		htmode = "EHT"..bw
	elseif hwmode == "11ax" then
		htmode = "HE"..bw
	elseif hwmode == "11ac" then
		htmode = "VHT"..bw
	else
		htmode = "HT"..bw
	end
	
	cmd = "uci -q set wireless."..radio..".htmode="..htmode
	os_cmd_execute(cmd)
end

local function cloudd_apply_hwmode(k, v)
	local radio = k:match("^hwmode_(.+)")
	local cmd
	local hwmode = v:match("%C+=(%C+)")	
	local htmode = util.exec("uci -q get wireless."..radio..".htmode|xargs printf")
	local bw = htmode:match("%d+$")
	local htmode = "HT"..bw
	
	if hwmode == "11be" then
		htmode = "EHT"..bw
	elseif hwmode == "11ax" then
		htmode = "HE"..bw
	elseif hwmode == "11ac" then
		htmode = "VHT"..bw
	else
		htmode = "HT"..bw
	end

	cmd = "uci -q set wireless."..radio..".htmode="..htmode
	os_cmd_execute(cmd)
	cmd = "uci -q set wireless."..radio..".hwmode="..hwmode
	os_cmd_execute(cmd)
end

local function cloudd_apply_config(p_data, not_apply)
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
						if k:match("^htmode") then
							cloudd_apply_htmode(k, v)
						elseif k:match("^hwmode") then
							cloudd_apply_hwmode(k, v)
						else
							cmd = "uci -q set " .. cjson.encode(v)
							os_cmd_execute(cmd:gsub("\\/", "/"):gsub("%$", "\\%$"))

							if v:match("wireless.radio%d.channel=%-1") or v:match("wireless.radio%d.disall=1") then
								local radio_name = v:match("radio%d")
								disabled_radio[radio_name] = true
							end
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
		elseif ver == "3" then
			c_debug.syslog("info", "ver:"..ver, 1)
			if p_data["info"] and #p_data["info"] > 0 then
				local exsit_update = 0
				local change_module = {}
				for k, v in pairs(p_data["info"]) do
					c_debug.syslog("info", "v:"..cjson.encode(v), 1)
					local module_name = v["module"] or ""
					local md5_val = v["md5"] or ""
					if #module_name > 0 and #md5_val > 0 then
						local c_md5 = uci:get("cloudd", "config", "md5_"..module_name) or ""
						c_debug.syslog("info", "module:"..module_name..",md5_val:"..md5_val..",c_md5:"..c_md5, 1)

						if c_md5 and c_md5 == md5_val then
							c_debug.syslog("info", "config md5 v"..ver.." module:"..module_name.." is the same", 1)
						else
							uci:set("cloudd", "config", "md5_"..module_name, md5_val)
							if module_name == "combo" then
								uci:delete("cloudd", module_name)
							elseif module_name == "speedlimit" then
								uci:foreach("cloudd", module_name,
									function(s)
										uci:delete("cloudd", s[".name"])
									end
								)
							elseif module_name == "limit" then
								uci:delete("cloudd", module_name)
							end
							change_module[#change_module + 1] = module_name
							cloudd_cpe_apply_config(v["data"])
							exsit_update = 1
						end
					end
				end
				if exsit_update == 1 then
					if #change_module == 0 then
						change_module[1] = ""
					end
					local nr = require "luci.nradio"
					local data = {type="config",uniq=tostring(socket.gettime()),module_name=change_module}
					c_debug.syslog("info", "send module_name:"..cjson.encode(data), 1)
					nr.ubus_send("combo.event",data)
				end
			end
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

		if not_apply then
			return
		end

		-- upgrade uci cursor
		uci = require "luci.model.uci".cursor()

		-- handle network vlan
		need_restart = cloudd_handle_vlan()

		-- set sniffer option
		cloudd_handle_sniffer()

		-- set mcast option
		cloudd_handle_mcast()

		-- set nrmesh option
		cloudd_handle_nrmesh()

		-- sync apbd2 ssid
		cloudd_sync_apbd2()

		if action_cmd ~= nil then
			local action = need_restart and "restart" or "reload"
			action_cmd = cloudd_extra_action(action_cmd, need_restart)
			os.execute("/usr/bin/cloudd_reload_service \"" .. action_cmd .. "\" \"" .. action .. "\" &")
		end
	end
end

function cloudd_apply_config_safe(p_data, not_apply)
	cloudd_lock()
	cloudd_apply_config(p_data, not_apply)
	cloudd_unlock()
end

-- d_id: device id
-- sync pass to device
function cloudd_send_pass(d_id, proto)
	local c_tab = {}
	local r_topic = "pass"
	local t = io.popen("grep -E ^root: /etc/shadow|xargs printf")
	local c_pass = t:read("*all")

	t:close()
	c_tab["pass"] = c_pass

	cloudd.cloudd_send(d_id, r_topic, c_tab, proto, 0)
end

function cloudd_apply_pass(p_data)
	if p_data ~= nil then
		if p_data["pass"] ~= nil then
			local ac_pass = p_data["pass"]:gsub('\'', '')
			l_sys.call("grep -qs '%s' /etc/shadow || sed -i 's|^root:.*|%s|' /etc/shadow" %{
					ac_pass, ac_pass
			})
			cloudd_sync_action(cloudd_send_pass)
		end
	end
end

-- d_id: device id
-- sync time to device
function cloudd_send_time(d_id, proto)
	local c_tab = {}
	local r_topic = "time"
	local c_time = os.time()

	c_tab["time"] = c_time

	cloudd.cloudd_send(d_id, r_topic, c_tab, proto, 0)
end

-- d_id: group id
-- sync time to group
function cloudd_send_time_group(g_id, proto)
	local c_tab = {}
	local r_topic = "time"
	local c_time = os.time()
	local self_id = cloudd_get_self_id()
	local d_id

	d_id = self_id .. ":" .. g_id
	c_tab["time"] = c_time

	cloudd.cloudd_send(d_id, r_topic, c_tab, proto, 0)
end

function cloudd_apply_time(p_data)
	if p_data ~= nil then
		if p_data["time"] ~= nil then
			local ac_time = tonumber(p_data["time"])
			if ac_time ~= nil and ac_time > 0 then
				local date = os.date("*t", ac_time)
				if date then
					l_sys.call("date -s '%04d-%02d-%02d %02d:%02d:%02d'" %{
							date.year, date.month, date.day, date.hour, date.min, date.sec
					})
					cloudd_sync_action(cloudd_send_time)
				end
			end
		end
	end
end

-- d_id: device id
-- send status topic to device
function cloudd_send_group_id(d_id, proto)
	local value = {}
	local r_event = "group_id"
	local group
	local self_id = cloudd_get_self_id()

	group = cloudd_get_group(d_id)

	value["id"] = self_id .. ":" .. group
	value["server_id"] = self_id

	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send message to all group
function cloudd_send_all_group(r_event, value, proto)
	local self_id = cloudd_get_self_id()
	local d_id = "FFFFFFFFFFFF"

	value["id"] = self_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- d_id: device id
-- send status topic to device
function cloudd_send_status(d_id, proto)
	local value = {}
	local r_event = "status"

	value["id"] = d_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send status to all group
function cloudd_send_status_all_group(proto)
	local value = {}
	local r_event = "status"

	cloudd_send_all_group(r_event, value, proto)
end

-- g_id: group id
-- send status to group
function cloudd_send_status_group(g_id, proto)
	local value = {}
	local r_event = "status"
	local self_id = cloudd_get_self_id()
	local d_id

	value["id"] = g_id
	d_id = self_id .. ":" .. g_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- d_id: device id
-- send report topic to device
function cloudd_send_report(d_id, rtype, proto)
	local value = {}
	local r_event = "report"

	value["id"] = d_id

	value["type"] = rtype

	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send report to all group
function cloudd_send_report_all_group(rtype, proto)
	local value = {}
	local r_event = "report"

	value["type"] = rtype

	cloudd_send_all_group(r_event, value, proto)
end

-- g_id: group id
-- send report to group
function cloudd_send_report_group(g_id, rtype, proto)
	local value = {}
	local r_event = "report"
	local self_id = cloudd_get_self_id()
	local d_id

	value["id"] = g_id
	value["type"] = rtype

	d_id = self_id .. ":" .. g_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
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

function cloudd_generate_local_radio()
	local clinfo = cloudd_get_client_info()
	local rv = { }
	local rcnt = { band2 = 0, band5 = 0, phy2 = 0, phy5 = 0, chlist = {} , skip_channels = {}, bwlist = {}}
	for _, dev in ipairs(ntm:get_wifidevs()) do
		local band = uci:get("wireless", dev:name(), "band") or nil
		local disabled = tonumber(uci:get("wireless", dev:name(), "disabled") or 0)
		local chlist = uci:get_list("wireless", dev:name(), "chlist") or {}
		local skip_channels = uci:get_list("wireless", dev:name(), "skip_channels")
		local channel = uci:get("wireless", dev:name(), "channel")
		local phyname = uci:get("wireless", dev:name(), "phyname") or ""
		local bwlist = {}

		if band then
			if band:match("5") then
				if disabled == 0 then
					rcnt.band5 = rcnt.band5 + 1
				end

				rcnt.phy5 = rcnt.phy5 + 1
				bwlist = cloudd_wifi_bwlist(phyname, "band5")
			else
				if disabled == 0 then
					rcnt.band2 = rcnt.band2 + 1
				end

				rcnt.phy2 = rcnt.phy2 + 1
				bwlist = cloudd_wifi_bwlist(phyname, "band2")
			end
			rcnt.chlist[dev:name()] = {chlist = chlist, channel = channel,skip_channels = skip_channels}
			rcnt.bwlist[dev:name()] = {bwlist = bwlist}
		end

		for _, net in ipairs(dev:get_wifinets()) do
			local status = util.ubus("wireless", "status", {device = net:ifname()})
			if status and (status.up == true) then
				local iface = ntm:get_interface(net:ifname())
				local assoclist
				local encr = uci:get("wireless", net:name(), "encryption") or "none"
				local ppsk_cfg = uci:get("wireless", net:name(), "ppsk_cfg") or nil
				local nrdev = uci:get("wireless", net:name(), "nrdev") or "0"
				local hostapd = util.ubus("hostapd."..net:name(), "get_status") or {}

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
					phyname    = phyname,
				}

				if hostapd and hostapd.channel then
					rv[#rv].channel = hostapd.channel
				end

				if hostapd and hostapd.freq then
					rv[#rv].frequency = hostapd.freq
				end

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

	c_debug.syslog("info", "rcnt: phy("..rcnt.phy2..","..rcnt.phy5.."), band("..rcnt.band2..","..rcnt.band5..")", 1)
	return rv, rcnt
end
function cloudd_get_cpesel()
	local cpesel_arr={}
	local res = util.ubus("infocd", "cpestatus") or {result={}}
	if not res.result then
		res.result = {}
	end
	for index,item in pairs (res.result) do
		local cpesel_item = {mode="",cur="",iccid=""}
		local cpebasic = item.status or {}
		local sim_index=""
		if index > 1 then
			sim_index=index-1
		end
		local simmode = uci:get("cpesel", "sim"..sim_index, "mode") or "1"
		local simno = uci:get("cpesel", "sim"..sim_index, "cur") or "1"
		cpesel_item.mode = simmode or ""
		cpesel_item.cur = simno or ""
		cpesel_item.iccid = cpebasic["iccid"] or ""
		cpesel_arr[#cpesel_arr + 1] = cpesel_item
	end
	if #cpesel_arr == 0 then
		cpesel_arr[1] = {}
	end
	return cpesel_arr
end
function cloudd_get_status(brief)
	local value = {}
	local s_info
	local f_data
	local pos = cloudd_get_position()
	local cl_raw = cloudd_ubus_cloudd_client()
	local cl = {}
	local nr = require "luci.nradio"
	local board_name = ""
	local board_pname = ""
	local wifiauth = nr.support_wifiauth()
	value["sversion"] = cloudd_get_local_sversion()
	value["iccid"] = {}
	value["simid"] = {}
	value["cpesel"] = cloudd_get_cpesel()

	if wifiauth then
		value["wifiauth"] = wifiauth
	end

	local oem_data = uci:get_all("oem", "board") or {}
	for k,v in pairs(oem_data) do
		if k == "pname" then
			board_pname = v
		elseif k == "name" then
			board_name = v
		elseif k == "ptype" then
			value["ptype"] = v
		elseif k == "vendor" then
			value["vendor"] = v
		elseif k == "device_code" then
			value["device_code"] = v
		elseif k:match("iccid(%d*)") then
			local iccid_array = util.split(v, ",")
			local iccid_item = {}
			if iccid_array and #iccid_array >= 1 then
				for _,iccid_v in pairs(iccid_array) do
					iccid_item[#iccid_item+1] = iccid_v
				end
				value["iccid"][#value["iccid"]+1] = iccid_item
			end
		elseif k:match("simid(%d*)") then
			local simid_array = util.split(v, ",")
			local simid_item = {}
			if simid_array and #simid_array >= 1 then
				for _,simid_v in pairs(simid_array) do
					simid_item[#simid_item+1] = simid_v
				end
				value["simid"][#value["simid"]+1] = simid_item
			end
		end
	end
	value["board"] = board_name or ""
	value["name"] = board_pname or board_name or ""
	value["wired_client"] = nr.list_wired_clients and nr.list_wired_clients() or { count = 0, client = {} }

	if (not value["vendor"]) or (#value["vendor"] == 0) then
		value["vendor"] = "nradio"
	end

	s_info = util.ubus("system", "info") or { }
	mqttagent_info = util.ubus("mqttagent", "info") or { }
	cloudd_connect_moment = mqttagent_info.connect_moment or 0
	uptime = s_info.uptime or 0
	value["uptime"] = uptime - cloudd_connect_moment
	value["uptime"] = s_info.uptime or 0


	if #value["simid"] == 0 then
		value["simid"][1] = {}
		value["simid"][1][1] = ""
	end

	if #value["iccid"] == 0 then
		value["iccid"][1] = {}
		value["iccid"][1][1] = ""
	end

	if #value["cpesel"] == 0 then
		value["cpesel"][1] = {}
		value["cpesel"][1][1] = ""
	end

	if brief == 1 then
		return value
	end

	value["id"] = cloudd_get_self_id()

	value["oid"] = cloudd_get_owner_id()

	if pos ~= nil then
		value["pos"] = pos
	end

	value["ifinfo"] = nr.get_local_device and nr.get_local_device() or {}

	if nr.support_mesh and nr.support_mesh() then
		for _, e in ipairs(nixio.getifaddrs()) do
			if e.name == "br-lan" and e.family == "inet" then
				value["ipaddr"] = e.addr
				break
			end
		end
	else
		local wan = ntm:get_wannet()
		if wan ~= nil then
			value["ipaddr"] = wan:ipaddr()
		else
			value["ipaddr"] = uci:get("network", "lan", "ipaddr")
		end
	end

	value["radio"], value["radiocnt"] = cloudd_generate_local_radio()

	for i = 1, cl_raw.count do
		local client = cl_raw.client[i]
		if client.radio then
			client.radio = cjson.decode(client.radio) or {}
		end
		table.insert(cl, client)
	end

	value["client"] = cl
	return value
end
-- d_id: device id
-- send local device info to remote device
function cloudd_send_device_info(d_id, p_data, proto)
	local r_topic = "device_info"
	local brief = 0
	if p_data and p_data["brief"] and p_data["brief"] == "1" then
		brief = 1
	end
	local value = cloudd_get_status(brief) or {}
	cloudd.cloudd_send(d_id, r_topic, value, proto, 1)
end

local function cloudd_report_env_stalist(rtype)
	local wm_stalist = util.ubus("wm", "stalist") or {}
	local stalist = {}
	local method = {"Probe", "Sniffer"}
	local cl = cloudd_ubus_cloudd_client(1)
	local sid = cloudd_get_self_id()
	local proto = "mqtt"

	for i = 1, #method do
		local list = wm_stalist[method[i]] or {}

		for k, v in pairs(list) do
			stalist[k] = v
		end
	end

	for i = 1, cl.count do
		local client = cl.client[i]

		if client.oid and client.oid == sid then
			cloudd_send_report(client.id, rtype, proto)
		end
	end

	return stalist
end

-- d_id: device id
-- reply local report to remote device
function cloudd_reply_report(d_id, rtype, proto)
	local r_topic = "report"
	local value = {}

	value["id"] = uci:get("cloudd", "config", "oid") or cloudd_get_self_id()

	value["type"] = rtype

	if rtype == "env" then
		value["stalist"] = cloudd_report_env_stalist(rtype)
	end

	cloudd.cloudd_send(d_id, r_topic, value, proto, 1)
end

local function cloudd_check_fakemac(mac)
	cloudd_unused(mac)
	return false
end

function cloudd_handle_env_stalist(id, stalist)
	local fake_check = uci:get("report-status-daemon", "envlist", "fake_check") or false

	if not fs.access("/usr/bin/redis-cli") then
		c_debug.syslog("info", "not support redis")
		return
	end

	local now = os.time()
	local items = {}

	if not redis_cli then
		connect_redis()
		if not redis_cli then
			return
		end
	end

	for mac, info in pairs(stalist) do
		local rssi = info.rssi
		local ts = now - info.tick
		local channel = info.channel or 0
		local rate = info.rate or 1
		local assoc = 0

		if info.preq ~= 1 then
			assoc = 1
		end

		if fake_check and info.preq == 1 and not cloudd_check_fakemac(mac) then
			c_debug.syslog("info", "fake mac: "..mac)
		else
			items[#items + 1] = id ..
				"," .. mac ..
				"," .. ts ..
				"," .. rssi ..
				"," .. channel ..
				"," .. rate ..
				"," .. assoc

			-- unpack may cause error if there're too many items.
			if #items > 1000 then
				redis_cli:rpush("envlist", unpack(items))
				items = {}
			end
		end
	end

	if #items > 0 then
		redis_cli:rpush("envlist", unpack(items))
	end
end

function cloudd_handle_report(d_id, p_data, proto)
	cloudd_unused(d_id)
	if p_data ~= nil then
		local c_info = util.ubus("cloudd", "info") or {}

		if c_info.server then
			local r_topic = "report"

			-- Device is a mboard, deliver message to AC
			p_data["id"] = cloudd_get_self_id()
			cloudd.cloudd_send(c_info.server, r_topic, p_data, proto, 1)
		else
			-- Device is a AC
			local rtype = p_data["type"]
			local id = p_data["id"]

			if rtype == "env" then
				local stalist = p_data["stalist"] or {}
				cloudd_handle_env_stalist(id, stalist)
			end
		end
	end
end

function cloudd_create_config(id, oid, rcnt, pos, cloud)
	local gid
	local ret
	local dname
	local dcboard
	local self_id = cloudd_get_self_id()

	c_debug.syslog("info", "create config for "..(id and id or "nil"), 1)
	cloudd_lock()
	dname = cloudd_create_device_config(oid, cloud)
	if dname then
		ret, dcboard = cloudd_create_cboard_config(dname, id, rcnt, pos)

		if self_id == oid then
			gid = "g"..(tonumber(pos)+2)
		end

		if ret and cloudd_create_group_config(id, gid) then
			cloudd_unlock()
			c_debug.syslog("info", "success create config for "..id, 1)
			return true
		end
	end
	cloudd_unlock()

	c_debug.syslog("info", "failed to create config for "..id, 1)
	cloudd_unused(dcboard)
	return false
end

function cloudd_update_config(id, proto)
	cloudd_send_group_id(id, proto)
	cloudd_send_config(id, proto)
end

function cloudd_send_device_state(d_id, state, proto)
	local r_topic = "device_info"
	local value = {}

	value["id"] = cloudd_get_self_id()
	value["state"] = state

	cloudd.cloudd_send(d_id, r_topic, value, proto, 1)
end

-- send cimd to d_id
function cloudd_send_cimd_request(d_id, proto)
	local value = {}
	local r_event = "cimd"

	value["id"] = d_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send cimd to group
function cloudd_send_cimd_request_group(g_id, proto)
	local value = {}
	local r_event = "cimd"
	local self_id = cloudd_get_self_id()
	local d_id

	value["id"] = self_id
	d_id = self_id .. ":" .. g_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send cimd to all group
function cloudd_send_cimd_request_all_group(proto)
	local value = {}
	local r_event = "cimd"

	cloudd_send_all_group(r_event, value, proto, 0)
end

-- apply cimd and return result
function cloudd_send_cimd_reply(d_id, proto)
	local p_data = {
		id = cloudd_get_self_id(),
	}
	local r_event = "cimd"
	local cl = cloudd_ubus_cloudd_client(1)
	local clinfo_all = cloudd_get_client_info()
	local clinfo = {}

	-- only reply associated stations information
	for _, dev in ipairs(ntm:get_wifidevs()) do
		for _, net in ipairs(dev:get_wifinets()) do
			local status = util.ubus("wireless", "status", {device = net:ifname()})
			if (status.up == true) then
				local assoclist = net:assoclist() or {}
				for mac in pairs(assoclist) do
					if clinfo_all[mac] then
						clinfo[mac] = clinfo_all[mac]
					end
				end
			end
		end
	end

	for i = 1, cl.count do
		local client = cl.client[i]
		local dir = client.dir or "1"

		if dir == "1" then
			cloudd_send_traffic_request(client.id, proto)
		end
	end

	p_data["clinfo"] = clinfo

	cloudd.cloudd_send(d_id, r_event, p_data, proto, 1)
end

local function cloudd_update_stainfo(items)

	if not fs.access("/usr/bin/redis-cli") then
		local key
		local sta_info = {name="report_station",parameter={}}

		for mac, info in pairs(items) do
			local hostname = info.hostname
			local ipaddr = info.ipaddr

			-- update hostname
			if hostname and hostname:len() > 0 then
				key = string.format("hn:%s", mac)
				sta_info.parameter[key] = hostname
			end

			-- update ipaddr
			if ipaddr and ipaddr:len() > 0 then
				key = string.format("ip:%s", mac)
				sta_info.parameter[key] = ipaddr
			end
		end

		util.ubus("infocdp", "passthrough",sta_info)
		return
	end

	if not redis_cli then
		connect_redis()
		if not redis_cli then
			return
		end
	end

	redis_cli:pipeline(
		function(p)
			local key

			for mac, info in pairs(items) do
				local hostname = info.hostname
				local ipaddr = info.ipaddr

				-- update hostname
				if hostname and hostname:len() > 0 then
					key = string.format("hn:%s", mac)
					p:set(key, hostname)
					p:expire(key, expire)
				end

				-- update ipaddr
				if ipaddr and ipaddr:len() > 0 then
					key = string.format("ip:%s", mac)
					p:set(key, ipaddr)
					p:expire(key, expire)
				end
			end
		end
	)
end

function cloudd_apply_cimd_reply(d_id, p_data, proto)
	local c_info = util.ubus("cloudd", "info") or {}

	cloudd_unused(d_id)
	if c_info.server then
		local r_topic = "cimd"

		-- Device is a mboard, deliver message to AC
		p_data["id"] = cloudd_get_self_id()
		return cloudd.cloudd_send(c_info.server, r_topic, p_data, proto, 1)
	end

	local clinfo = p_data["clinfo"]

	cloudd_update_stainfo(clinfo)
end

-- send traffic to d_id
function cloudd_send_traffic_request(d_id, proto)
	local value = {}
	local r_event = "traffic"

	value["id"] = d_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send traffic to group
function cloudd_send_traffic_request_group(g_id, proto)
	local value = {}
	local r_event = "traffic"
	local self_id = cloudd_get_self_id()
	local d_id

	value["id"] = self_id
	d_id = self_id .. ":" .. g_id
	cloudd.cloudd_send(d_id, r_event, value, proto, 0)
end

-- send traffic to all group
function cloudd_send_traffic_request_all_group(proto)
	local value = {}
	local r_event = "traffic"

	cloudd_send_all_group(r_event, value, proto, 0)
end

local function cloudd_get_local_traffic()
	local traffic = {
		txbytes2 = 0,
		rxbytes2 = 0,
		txbytes5 = 0,
		rxbytes5 = 0
	}

	for _, dev in ipairs(ntm:get_wifidevs()) do
		local hwmodes = dev:hwmodes()
		local is5g = false
		if hwmodes then
			if hwmodes.a or hwmodes.ac then
				is5g = true
			end
		end

		for _, net in ipairs(dev:get_wifinets()) do
			local status = util.ubus("wireless", "status", {device = net:ifname()})
			if (status and status.up == true) then
				local iface = ntm:get_interface(net:ifname())
				local txbytes = tonumber(iface:tx_bytes() or 0)
				local rxbytes = tonumber(iface:rx_bytes() or 0)

				if is5g then
					traffic.txbytes5 = traffic.txbytes5 + txbytes
					traffic.rxbytes5 = traffic.rxbytes5 + rxbytes
				else
					traffic.txbytes2 = traffic.txbytes2 + txbytes
					traffic.rxbytes2 = traffic.rxbytes2 + rxbytes
				end
			end
		end
	end

	return traffic
end

-- apply traffic and return result
function cloudd_send_traffic_reply(d_id, proto)
	local p_data = {
		id = cloudd_get_self_id(),
	}
	local r_event = "traffic"
	local cl = cloudd_ubus_cloudd_client(1)

	local traffic = cloudd_get_local_traffic()

	for i = 1, cl.count do
		local client = cl.client[i]
		if client.traffic then
			local c_traffic = cjson.decode(client.traffic) or {}
			traffic.txbytes2 = traffic.txbytes2 + tonumber(c_traffic.txbytes2)
			traffic.rxbytes2 = traffic.rxbytes2 + tonumber(c_traffic.rxbytes2)
			traffic.txbytes5 = traffic.txbytes5 + tonumber(c_traffic.txbytes5)
			traffic.rxbytes5 = traffic.rxbytes5 + tonumber(c_traffic.rxbytes5)
		end

		cloudd_send_traffic_request(client.id, proto)
	end

	p_data["traffic"] = traffic

	cloudd.cloudd_send(d_id, r_event, p_data, proto, 1)
end

function cloudd_apply_traffic_reply(d_id, tc_data)
	if not fs.access("/usr/bin/redis-cli") then
		return
	end

	if not redis_cli then
		connect_redis()
		if not redis_cli then
			return
		end
	end

	local k_tx2 = "tc:tx2:loc:" .. d_id
	local k_rx2 = "tc:rx2:loc:" .. d_id
	local k_tx5 = "tc:tx5:loc:" .. d_id
	local k_rx5 = "tc:rx5:loc:" .. d_id
	local k_ts = "tc:ts:loc:" .. d_id

	-- update current record in redis
	local items = {}
	items[k_tx2] = tc_data.txbytes2
	items[k_rx2] = tc_data.rxbytes2
	items[k_tx5] = tc_data.txbytes5
	items[k_rx5] = tc_data.rxbytes5
	items[k_ts] = os.time()
	redis_cli:mset(items)
end

function cloudd_update_local_traffic()
	local traffic = cloudd_get_local_traffic()
	local sid = cloudd_get_self_id()

	cloudd_apply_traffic_reply(sid, traffic)
end

-- upgrade firmware
function cloudd_handle_upgrade(d_id, p_data, proto)
	local url
	local c_md5
	local command
	local sversion = cloudd_get_local_sversion()
	local debug_string
	local dest_version

	url = p_data["sfile"]
	c_md5 = p_data["md5"]
	command = p_data["action"]
	dest_version = p_data["dest_version"]

	if dest_version ~= nil and sversion ~= nil then
		if dest_version ~= sversion then
			local ret, err_text = c_firmware.download_upgrade(url, c_md5, command)
			if ret ~= 0 then
				local r_data = {}
				local r_topic = "firmware_status"
				r_data["uniq"] = p_data["uniq"]
				r_data["code"] = ret
				r_data["code_string"] = err_text
				cloudd.cloudd_send(d_id, r_topic, r_data, proto, 1)
			end
		else
			debug_string = "dversion: " .. dest_version .. "; local version: " .. sversion
			c_debug.syslog("info", debug_string, 1)
		end
	end
end

-- upgrade firmware
function cloudd_firmware_upgrade_group(g_id, boardname, dversion, proto)
	local f_file = c_default_firmware_dir .. boardname .. "/" ..  dversion
	local t_pay = {}
	local topic = "firmware"
	local file_exist
	local debug_string
	local rurl
	local d_id
	local self_id = cloudd_get_self_id()
	local f_url
	local f_md5

	d_id = self_id .. ":" .. g_id

	file_exist = cloudd_file_exist(f_file)

	-- try local first
	if file_exist then
		local lan_ip = uci:get("network", "lan", "ipaddr")
		f_md5 = c_md5file.md5file(f_file)

		f_url = "http://" .. lan_ip .. ":8080/firmware/" .. boardname .. "/" .. dversion

		t_pay["sfile"] = f_url
		t_pay["md5"] = f_md5
		t_pay["action"] = "sysupgrade"
		t_pay["dest_version"] = dversion

		cloudd.cloudd_send(d_id, topic, t_pay, proto, 0)
	else
		-- try remote url
		rurl = cloudd_get_firmware_url_group(g_id)
		if rurl == nil then
			debug_string = "upgrade firmware: file " .. f_file .. " don't exist"
			c_debug.syslog("info", debug_string, 1)
		else
			f_url = rurl .. "/" .. boardname .. "/" .. dversion

			t_pay["sfile"] = f_url
			t_pay["action"] = "sysupgrade"
			t_pay["dest_version"] = dversion

			debug_string = "upgrade firmware from " .. f_url .. d_id
			c_debug.syslog("info", debug_string, 1)

			cloudd.cloudd_send(d_id, topic, t_pay, proto, 0)
		end
	end
end

-- upgrade device firmware
function cloudd_firmware_upgrade(d_id, boardname, dversion, proto)
	if not boardname or not dversion then
		return
	end

	local f_file = c_default_firmware_dir .. boardname .. "/" ..  dversion
	local t_pay = {}
	local topic = "firmware"
	local file_exist
	local debug_string
	local rurl
	local upgrade_mode
	local f_md5
	local f_url

	upgrade_mode = cloudd_get_firmware_upgrade_mode(d_id)

	-- upgrade_mode is 1 means upgrade firmware when connect
	if upgrade_mode ~= nil and upgrade_mode ~= "1" then
		return
	end

	file_exist = cloudd_file_exist(f_file)

	-- try local first
	if file_exist then
		local lan_ip = uci:get("network", "lan", "ipaddr")
		f_md5 = c_md5file.md5file(f_file)

		f_url = "http://" .. lan_ip .. ":8080/firmware/" .. boardname .. "/" .. dversion

		t_pay["sfile"] = f_url
		t_pay["md5"] = f_md5
		t_pay["action"] = "sysupgrade"
		t_pay["dest_version"] = dversion

		cloudd.cloudd_send(d_id, topic, t_pay, proto, 0)
	else
		-- try remote url
		rurl = cloudd_get_firmware_url(d_id)
		if rurl == nil then
			debug_string = "upgrade firmware: file " .. f_file .. " don't exist"
			c_debug.syslog("info", debug_string, 1)
		else
			f_url = rurl .. "/" .. boardname .. "/" .. dversion

			t_pay["sfile"] = f_url
			t_pay["action"] = "sysupgrade"
			t_pay["dest_version"] = dversion

			debug_string = "upgrade firmware from " .. f_url .. d_id
			c_debug.syslog("info", debug_string, 1)

			cloudd.cloudd_send(d_id, topic, t_pay, proto, 0)
		end
	end
end

-- send command to d_id
function cloudd_send_command(d_id, c_cmd, proto)
	local value = {}
	local topic = "command"

	value["cmd"] = c_cmd

	cloudd.cloudd_send(d_id, topic, value, proto, 0)
end

-- send command to group
function cloudd_send_command_group(g_id, c_cmd, proto)
	local value = {}
	local topic = "command"
	local self_id = cloudd_get_self_id()
	local d_id

	value["cmd"] = c_cmd
	d_id = self_id .. ":" .. g_id
	cloudd.cloudd_send(d_id, topic, value, proto, 0)
end

-- send command to group
function cloudd_send_command_all_group(c_cmd, proto)
	local value = {}
	local topic = "command"

	value["cmd"] = c_cmd

	cloudd_send_all_group(topic, value, proto, 0)
end

-- apply command and return result
function cloudd_apply_command(d_id, p_data, topic, proto)
	local ret = "1"
	local output = ""

	p_data["result"] = "# cmd not exist #"

	if p_data["cmd"] ~= nil then
		ret, output = cloudd_execute_command(p_data["cmd"])
	end

	p_data["result"] = output
	p_data["return"] = ret

	cloudd.cloudd_send(d_id, topic, p_data, proto, 1)
end

function cloudd_notify_upgrade(d_id, keep, path, proto)
	local value = {}
	local topic = "upgrade"
	local file = fs.basename(path)

	value["keep"] = keep or "1"

	value["file"] = file

	value["md5"] = util.exec("md5sum "..path.." |awk '{print $1}'|xargs printf")

	cloudd.cloudd_send(d_id, topic, value, proto, 0)
end

function cloudd_do_upgrade(d_id, p_data, proto)
	local ip
	local image
	local path = "/tmp/filexmit/"
	local c_md5
	local kopt = ""
	local code

	-- notify ac it's preparing upgrade
	cloudd_send_device_state(d_id, cloudd_enum_device_status("status_upgrade_preparing"), proto)

	if p_data["ip"] then
		ip = p_data["ip"]
	else
		ip = uci:get("mosquitto", "bridge_ac", "address")
		if not ip then
			ip = uci:get("mosquitto", "bridge", "address")
		end
		if not ip then
			c_debug.syslog("info", "do_upgrade: unknown ip", 1)
			cloudd_send_device_state(d_id, cloudd_enum_device_status("status_upgrade_error"), proto)
			return
		end
		ip = (ip:gsub(":1883$", ""))
	end

	if ip:match(":") then
		ip = "["..ip.."]"
	end

	image = p_data["file"] and p_data["file"] or "ap_firmware.img"

	fs.mkdir(path)

	-- download image
	if not fs.access("/usr/bin/curl") then
		util.exec("wget -q http://"..ip.."/filexmit/"..image.." -O "..path..image)
	else
		util.exec("curl -g http://"..ip.."/filexmit/"..image.." -o "..path..image)
	end
	

	if p_data["md5"] then
		c_md5 = util.exec("md5sum "..path..image.."|awk '{print $1}'|xargs printf")

		if c_md5 ~= p_data["md5"] then
			c_debug.syslog("info", "do_upgrade: incorrect md5", 1)
			cloudd_send_device_state(d_id, cloudd_enum_device_status("status_upgrade_error"), proto)
			return
		end
	end

	-- test image
	code = l_sys.call("sysupgrade -T "..path..image)
	if code ~= 0 then
		c_debug.syslog("info", "do_upgrade: image is invalid", 1)
		cloudd_send_device_state(d_id, cloudd_enum_device_status("status_upgrade_error"), proto)
		return
	end

	-- notify ac it's upgrading
	cloudd_send_device_state(d_id, cloudd_enum_device_status("status_upgrading"), proto)

	if p_data["keep"] and p_data["keep"] == "0" then
		kopt = "-n"
	end

	-- upgrade
	c_debug.syslog("info", "do_upgrade: start upgrade")
	code = l_sys.call("sysupgrade "..kopt.." "..path..image)
	if code == 0 then
		cloudd_send_device_state(d_id, cloudd_enum_device_status("status_rebooting"), proto)
	else
		cloudd_send_device_state(d_id, cloudd_enum_device_status("status_upgrade_error"), proto)
	end
end

function cloudd_notify_reboot(d_id, proto)
	local value = {}
	local topic = "reboot"

	cloudd.cloudd_send(d_id, topic, value, proto, 0)
end

function cloudd_notify_reset(d_id, proto)
	local value = {}
	local topic = "reset"

	cloudd.cloudd_send(d_id, topic, value, proto, 0)
end

function cloudd_do_reboot(d_id, proto)
	-- notify ac it's rebooting
	cloudd_send_device_state(d_id, cloudd_enum_device_status("status_rebooting"), proto)

	c_debug.syslog("info", "do_reboot: start reboot")
	util.exec("reboot")
end

function cloudd_do_reset(d_id, proto)
	-- notify ac it's resetting
	cloudd_send_device_state(d_id, cloudd_enum_device_status("status_resetting"), proto)

	c_debug.syslog("info", "do_reset: start reset")
	util.exec("echo y|firstboot && reboot")
end

-- make some delay
function cloudd_sleep(sec)
	os.execute("sleep " .. sec)
end

function cloudd_wait_reply(d_id, count, timeout)
	local mosq = require "mosquitto"
	local client = mosq.new()
	local self_id = cloudd_get_self_id()
	local topic_fmt = "kp/%s/%s/reply/command"
	local topic = ""
	local loop = true
	local t1, t2, diff
	local result = {}
	local host = "127.0.0.1"

	timeout = timeout or 2
	count = count or 1

	client.ON_CONNECT = function()
		topic = topic_fmt:format(self_id, d_id)
		client:subscribe(topic)
		topic = topic_fmt:format(self_id.."ap", d_id)
		client:subscribe(topic)
	end

	client.ON_MESSAGE = function(mid, r_topic, payload)
		cloudd_unused(mid)
		if not result[r_topic] then
			result[r_topic] = payload
			count = count - 1
			if count == 0 then
				loop = false
			end
		end
	end

	client:connect(host)
	t1 = os.time()
	while loop do
		client:loop(50, 10)
		t2 = os.time()
		diff = os.difftime(t2, t1)
		if diff > timeout then
			client:disconnect()
			break
		end
	end

	return result
end

function cloudd_sync_config(not_apply)
	local sid = cloudd_get_self_id()
	local rcnt
	local dummy

	c_debug.syslog("info", "start sync config "..(sid and sid or "nil"), 1)
	if not fs.access("/etc/config/wireless") then
		c_debug.syslog("info", "don't have wireless config", 1)
		return
	end

	dummy, rcnt = cloudd_generate_local_radio()

	if cloudd_create_config(sid, sid, rcnt, -1) then
		-- custom template config
		cloudd_set_custom_config(sid, "t0")
		uci:commit("cloudd")

		cloudd_self_apply(true, not_apply)

		-- update radio count
		dummy, rcnt = cloudd_generate_local_radio()
		cloudd_create_config(sid, sid, rcnt, -1)
	end

	c_debug.syslog("info", "end sync config", 1)
	cloudd_unused(dummy)
end

function cloudd_generate_client_config(payload)
	local cl = cloudd_ubus_cloudd_client(1)
	local sid = cloudd_get_self_id()
	local nr = require "luci.nradio"
	local did
	local proto = "mqtt"
	local modified = false
	local update_ids = {}
	local has_wifi = fs.access("/etc/config/wireless") or false
	local need_reload_apbd2 = false

	for i = 1, cl.count do
		local client = cl.client[i]
		if client.radio and client.id then
			for j = 1, #payload do
				if payload[j] == client.id or payload[j] == client.id.."ap" then
					local id = client.id
					local oid = client.oid or id
					local pos = client.pos or 0
					local rcnt = client.radiocnt and cjson.decode(client.radiocnt) or {band2 = 1, band5 = 1, phy2 = 1, phy5 = 1}
					local cloud = false
					if payload[j] == client.id.."ap" then
						cloud = true
					end

					if cloudd_create_config(id, oid, rcnt, pos, cloud) then
						if sid ~= id then
							if sid ~= oid then
								did = oid
							else
								did = id
								if not has_wifi then
									need_reload_apbd2 = true
								end
							end

							update_ids[did] = true
							modified = true
							util.ubus("wm", "nrctrl", {action=3, mac=id})
						end
					end
					break
				end
			end
		end
	end

	-- TODO: Need to diff AC/AP and Controller/Agent
	if nr.support_mesh and nr.support_mesh() then
		sync_wifi_config()
	else
		for id, _ in pairs(update_ids) do
			cloudd_update_config(id, proto)
		end
	end

	if modified then
		if need_reload_apbd2 then
			os.execute("/etc/init.d/apbd2 restart")
		end
		cloudd_reload_mosq_safe()
	end
end


function cloudd_update_agent_netstatus(p_data)
	local nr = require "luci.nradio"
	local data = cjson.decode(p_data)
	local status_info = data["mesh"] or "down"
	if nr.support_mesh and nr.support_mesh() then
		util.ubus("wanchk", "set", {name = "mesh",status=status_info})
	end
end

function sync_controller_netstat(d_id)
	local nr = require "luci.nradio"
	local value = {mesh="down"}
	local proto = "mqtt"
	local wans
	local wan
	local role = uci:get("mesh", "config", "role") or "1"

	if role ~= "0" then
		return
	end

	wans = nr.get_net_status("wan,cpe_4")

	if wans and #wans > 0 then
		for _,wan in pairs(wans) do
			if wan.is_up then
				value.mesh = "up"
				break
			end
		end
	end

	local r_event = "sync"
	if d_id and (#d_id > 0) then
		cloudd.cloudd_send(d_id, r_event, value, proto, 0)
	else
		cloudd_send_all_group(r_event, value, proto)
	end

end
function cloudd_check_firmware(proto)
	local id = "mosca"
	local topic = "firmware"
	local data = {pname = "", board = "", extra = "", vendor = "", ver = ""}

	util.ubus("cloudd", "state", {value = 1})

	data["pname"] = uci:get("oem", "board", "pname") or uci:get("oem", "board", "name") or ""
	data["board"] = uci:get("oem", "board", "name") or ""
	data["vendor"] = uci:get("oem", "board", "vendor") or ""
	data["ver"] = cloudd_get_local_sversion() or ""

	cloudd.cloudd_send(id, topic, data, proto, 0)
end

function cloudd_remote_download(r_url, r_md5)
	local nr = require "luci.nradio"
	local info = util.ubus("cloudd", "info") or {}
	local path = "/tmp/filexmit/"

	local platform = nr.get_platform()
	if platform == "tdtech" then
		path = "/online/filexmit/"
	end

	local image = path.."firmware.img"
	local code
	local fw_url = r_url and r_url or info.url
	local fw_md5 = r_url and r_md5 or info.md5
	local c_md5
	
	util.exec("rm -fr "..image.." >/dev/null 2>&1")
	c_debug.syslog("info", "ready to download", 1)

	util.ubus("cloudd", "state", {value = 3})

	if (not fw_url) or (not fw_md5) then
		c_debug.syslog("info", "failed to read remote url or md5", 1)
		util.ubus("cloudd", "state", {value = 254})
		return false
	end

	if not r_url then
		if info.code and info.code ~= 0 then
			c_debug.syslog("info", "no valid firmware", 1)
			util.ubus("cloudd", "state", {value = 253})
			return
		end
	end

	-- download image
	fs.mkdir(path)

	if not fs.access("/usr/bin/curl") then
		if fs.access("/etc/ssl/certs/ca-certificates.crt") then
			util.exec("wget -q --ca-certificate=/etc/ssl/certs/ca-certificates.crt "..fw_url.." -O "..image)
		else
			util.exec("wget --no-check-certificate  "..fw_url.." -O "..image)
		end
	else
		if fs.access("/etc/ssl/certs/ca-certificates.crt") then
			util.exec("curl --cacert /etc/ssl/certs/ca-certificates.crt -g "..fw_url.." -o "..image)
		else
			util.exec("curl -k -g "..fw_url.." -o "..image)
		end
	end

	-- check md5
	c_md5 = util.exec("md5sum "..image.."|awk '{print $1}'|xargs printf")
	if c_md5 ~= fw_md5 then
		c_debug.syslog("info", "do_remote_upgrade: incorrect md5", 1)
		util.ubus("cloudd", "state", {value = 252})
		return false
	end

	-- test image
	if platform ~= 'quectel' then
		code = l_sys.call("sysupgrade -T "..image)
		if code ~= 0 then
			c_debug.syslog("info", "do_remote_upgrade: image is invalid", 1)
			util.ubus("cloudd", "state", {value = 251})
			return false
		end
	end
	util.ubus("cloudd", "state", {value = 4})

	return true
end

function cloudd_remote_upgrade()
	local nr = require "luci.nradio"
	local info = util.ubus("cloudd", "info") or {}
	local image = "/tmp/filexmit/firmware.img"

	local platform = nr.get_platform()
	if platform == "tdtech" then
		image = "/online/filexmit/firmware.img"
	end

	local code

	if info.state ~= 4 then
		return true
	end

	util.ubus("cloudd", "state", {value = 2})

	-- upgrade
	if platform == "quectel" then
		local image_tmp = "/etc/update/firmware_cloudd.swu"
		os.execute("mkdir -p /etc/update")
		os.execute("cp "..image.." "..image_tmp)
		code = l_sys.call("sleep 1; rm -rf /tmp/luci*;cpetools.sh -t 0 -c 'AT+QFOTADL=\"%s\"'" %{image_tmp})
	else
		code = l_sys.call("sleep 1; /sbin/sysupgrade "..image)
	end

	if code ~= 0 then
		c_debug.syslog("info", "do_remote_upgrade: upgrade failure", 1)
		util.ubus("cloudd", "state", {value = 255})
		return false
	end

	return true
end

-- send message to all router device
function cloudd_send_from_mosca(d_id, r_event, value)
	local r_json

	value["id"] = "mosca"

	r_json = cjson.encode(value)

	l_sys.call("mosquitto_pub -t kp/"..d_id.."/mosca/"..r_event.." -m '"..r_json.."'")
end

function cloudd_set_bdinfo(ids, data, proto)
	local topic = "bdinfo"

	proto = proto or "mqtt"

	for i = 1, #ids do
		cloudd.cloudd_send(ids[i], topic, data, proto, 0)
	end
end

function cloudd_apply_bdinfo(d_id, data)
	local f

	cloudd_unused(d_id)
	if not data then
		c_debug.syslog("info", "data shouldn't be empty", 1)
		return false
	end

	f = io.popen("/usr/bin/bdinfo_edit.sh", "w")
	if not f then
		c_debug.syslog("info", "failed to open bdinfo_edit", 1)
		return false
	end

	for k, v in pairs(data) do
		c_debug.syslog("info", "set "..k.." as "..v, 1)
		f:write(k.."="..v.."\n")
	end

	f:close()

	os.execute("echo y|firstboot && reboot")
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

function cloudd_set_dmode(set)
	local id = "mosca"
	local topic = "develop"
	local data = {}

	uci:set("cloudd", "config", "developer", 2)
	uci:commit("cloudd")

	data["id"] = cloudd_get_self_id()
	data["enable"] = set

	cloudd.cloudd_send(id, topic, data, nil, 0)
end

function cloudd_dmode_confirm(d_id, p_data, proto)
	local enable = p_data and p_data["enable"] or "0"

	cloudd_unused(d_id, proto)

	c_debug.syslog("info", "receive server reply enable="..enable, 1)
	uci:set("cloudd", "config", "developer", enable)
	uci:commit("cloudd")
end

function cloudd_generate_config(id,sub_sid)
	local c_group
	--local c_config_sync_array = {{key="radio",data={}}, {key="wlan",data={}}}
	local c_config_sync_array = {{key="wlan",data={}}}
	local change = 0;

	c_group = cloudd_get_group(id)
	for i=1, #(c_config_sync_array) do
		local config_name = c_group .. c_config_sync_array[i].key
		local id_config = uci:get_all("cloudd", config_name)
		c_config_sync_array[i].data = id_config
	end

	if #sub_sid then
		for i = 1, #sub_sid do
			local id = sub_sid[i]
			local sub_group = cloudd_get_group(id)
			for i=1, #(c_config_sync_array) do
				local config_name = sub_group .. c_config_sync_array[i].key
				local id_config = c_config_sync_array[i].data
				uci:delete("cloudd",config_name)
				if c_config_sync_array[i].key == "radio" then
					uci:set("cloudd",config_name,"radio")
				else
					uci:set("cloudd",config_name,"interface")
				end

				if id_config ~= nil then
					for k,v in pairs(id_config) do
						local k1 = string.sub(k, 1, 1)
						if k1 ~= "." then
							c_debug.syslog("info", "config_name:"..config_name.." k:"..k.." v:"..v)
							uci:set("cloudd", config_name, k, v)
							change = 1
						end
					end
				end
			end
		end
	end

	if change == 1 then
		uci:commit("cloudd")
	end
end

function sync_wifi_config()
	local self_id = cloudd_get_self_id()
	local sub_sid = {}
	local role = uci:get("mesh", "config", "role") or "1"
	if role == "0" then
		uci:foreach("cloudd", "device",
			function(s)
				if s.id ~= self_id then
					sub_sid[#sub_sid + 1] = s.id
				end
			end
		)

		cloudd_generate_config(self_id,sub_sid)

		if #sub_sid then
			for i = 1, #sub_sid do
				local id = sub_sid[i]
				cloudd_send_config(id)
			end
		end
	end
end

function cloudd_disconnect_node(d_id,proto)
	local r_topic = "connection"
	local value = {}
	cloudd.cloudd_send(d_id, r_topic, value, proto,0)
end

function cloudd_get_sta()
	local value = {list={},deny={}}
	local result = util.ubus("infocd", "basic",{name="wlan"}) or { wlan = {}}
	if result.wlan.radio then
		for _,item in pairs(result.wlan.radio) do
			local wlan_data = {}
			if item.frequency:match("2.4") then
				wlan_data.band = "2.4G"
			elseif item.frequency:match("5.2") then
				wlan_data.band = "5.2G"
			elseif item.frequency:match("5.8") then
				wlan_data.band = "5.8G"
			elseif item.frequency:match("5") then
				wlan_data.band = "5G"
			end
			wlan_data.online = item.sta
			wlan_data.servied = 0
			wlan_data.list = {}
			for _,assoclist_item in pairs(item.assoclist) do
				wlan_data.list[#wlan_data.list+1] = assoclist_item.mac
			end
			wlan_data.mac = item.mac or ""
			if #wlan_data.list == 0 then
				wlan_data.list[1] = ""
			end
			value.list[#value.list+1] = wlan_data
		end
	end
	uci:foreach("cloudd_cli", "client",
		function(s)
			if s.mac and #s.mac > 0 then
				section = s[".name"]
				if s["switch"] == "0" then
					value.deny[#value.deny+1] = s.mac
				end
			end
		end
	)
	if #value.list == 0 then
		value.list[1]=""
	end
	if #value.deny == 0 then
		value.deny[1]=""
	end
	return value
end
function cloudd_get_cpe()
	local value = {list={}}
    local res = util.ubus("infocd", "cpestatus") or {result={}}

	for index,item in pairs (res.result) do
		local cpebasic = item.status or {}
		local sim_index=""
		if index > 1 then
			sim_index=index-1
		end
		cpebasic["cpeno"] = index
		value.list[#value.list+1] = cpebasic
	end
	if #value.list == 0 then
		value.list[1] = ""
	end
	return value
end
function cloudd_get_runtime()
	local value = {result={}}
    local res = util.ubus("infocd", "runtime") or {}
	value.result = res
	return value
end
local function get_cpeinfo(data,name)
    local isp = ""
    local cpe_mode = ""
    if data and data.cpe and name then
        for _, v in ipairs(data.cpe) do
            if v.name == name then
                if v.mode == "LTE" then
                    cpe_mode = "4G"
                elseif v.mode:find("NR") or v.mode:find("SA") then
                    cpe_mode = "5G"
                end
                if v.isp and #v.isp > 0 and #cpe_mode > 0 then
                    return v.isp..","..cpe_mode
                else
                    return ""
                end
            end
        end
    end
    return ""
end

function isValidIPv4(ip)
	if not ip or #ip < 7  or #ip > 15 then return false end
    local pattern = "^(%d+)%.(%d+)%.(%d+)%.(%d+)$"
    local segments = {ip:match(pattern)}
    if #segments == 4 then
        for _, v in ipairs(segments) do
            if tonumber(v) > 255 then return false end
        end
        return true
    end
    return false
end
function isValidIPv6(ip)
    if not ip or #ip < 2  or #ip > 39 then return false end
    if ip == "::" or ip == "::1" then return true end

    local colon_double = ip:find("::")
    if colon_double then
        if ip:sub(colon_double+1):find("::") then return false end
        ip = ip:gsub("::", ":0")
    end
	
    local segments = {}
    for seg in ip:gmatch("[^:]+") do
        nixio.syslog("err","seg:"..seg)
        if #seg > 4 or not seg:match("^[0-9a-fA-F]+$") then return false end
        segments[#segments+1] = seg
    end
    return #segments <= 8 and #segments > 1
end
function cloudd_get_int()
    local res = util.ubus("infocd", "basic",{name='wans'})
    local res_cpe = {}
    local ip_out = ""
    local cpenum = tonumber(uci:get("oem", "feature", "cpe") or "0")
    local mode = ""
    local ip = {v4 = "", v6 = ""}
    local time = {v4 = -1, v6 = -1}
    local wan_mode = false
    local value = {}
	local wan6 = uci:get("network", "globals", "default_wan6") or "wan6"
	local nr = require "luci.nradio"
	local cellular_prefix,cellular_default = nr.get_cellular_prefix()
	local cmd = "";
    if cpenum > 0 then
        res_cpe = util.ubus("infocd", "basic",{name='cpe'}) or {}
    end
	if not fs.access("/usr/bin/curl") then
		cmd="wget -t 2 -q -O - "
	else
		cmd="curl -s -m 2 "
	end
    if res and res.wans then
        for _, v in ipairs(res.wans) do
            if not wan_mode then
                if tonumber(v.status) == 0 and v.name ~= "wan" and v.name:match("^"..cellular_prefix) then
                    if v.name:match("_6$") then
                        ip_out = util.exec(cmd.." 6.ipw.cn") or ""
                    else
                        ip_out = util.exec(cmd.." 4.ipw.cn") or ""
                    end
                    if #ip_out == 0 and v.ipaddrs[1] and v.ipaddrs[1].ipaddr then
                        ip_out = util.split(v.ipaddrs[1].ipaddr,"/")[1] or ""
                    end
                    if v.name:match("_6$") then
                        ip.v6 = ip_out
                        time.v6 = tonumber(v.uptime)
                    else
                        ip.v4 = ip_out
                        time.v4 = tonumber(v.uptime)
                        mode = get_cpeinfo(res_cpe,v.name)
                    end
                end
            end
            if tonumber(v.status) == 0 and v.name == "wan" then
                if not wan_mode then
                    ip = {v4 = "", v6 = ""}
                    time = {v4 = -1, v6 = -1}
                    wan_mode = true
                end
                ip_out = util.exec(cmd.." 4.ipw.cn") or ""
                if #ip_out == 0 and v.ipaddrs[1] and v.ipaddrs[1].ipaddr then
                    ip_out = util.split(v.ipaddrs[1].ipaddr,"/")[1] or ""
                end
                mode = v.proto
                ip.v4 = ip_out
                time.v4 = tonumber(v.uptime)
            end
            if tonumber(v.status) == 0 and (v.name == wan6 ) then
                if not wan_mode then
                    ip = {v4 = "", v6 = ""}
                    time = {v4 = -1, v6 = -1}
                    wan_mode = true
                end
                ip_out = util.exec(cmd.." 6.ipw.cn") or ""
                if #ip_out == 0 and v.ipaddrs[1] and v.ipaddrs[1].ipaddr then
                    ip_out = util.split(v.ipaddrs[1].ipaddr,"/")[1] or ""
                end
                if #mode == 0 then
                    mode = v.proto
                end
                ip.v6 = ip_out
                time.v6 = tonumber(v.uptime)
            end
        end
    end

    value.mode = mode
	if isValidIPv4(ip.v4) then
		value.ip = ip.v4
	end
	if isValidIPv6(ip.v6) then
		value.ipv6 = ip.v6
	end

    if time.v6 > time.v4 then
        value.time = time.v6
    else
        value.time = time.v4
    end

    return value
end

function cloudd_get_traffic()
	local nr = require "luci.nradio"
	local runtime = nr.get_combo_info()
	return runtime
end

function cloudd_get_batinfo()
	local value = {percent="-1",charging=false}
	return value
end


function cloudd_get_limitstatus()
	local nr = require "luci.nradio"
	local runtime = nr.get_speedlimit_info()
	return runtime
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
	local id = cloudd_get_self_id()
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

function cloudd_get_wifistatus()
	local wifi_array = {list={}}
	local diff_2_4_wlan = uci:get("cloudd", "t0", "diff_2_4_wlan") or "X0"
	if diff_2_4_wlan == "X1" then --关闭合一
		local id = cloudd_get_self_id()
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
					c_debug.syslog("info", "match id", 1)
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

				wifi_array.list[#wifi_array.list+1]=wifi_item

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
		wifi_array.list[#wifi_array.list+1]=wifi_item
	end
	if #wifi_array.list == 0 then
		wifi_array.list[1] = {}
	end
	return wifi_array
end

function cloudd_set_wifi(data)
	if data and data.wifiset then
		local change=0
		local wifi_cnt=0
		local diff_wlan=0
		for _,item in pairs (data.wifiset) do
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
			local nr = require "luci.nradio"
			nr.fork_exec(function()
				local cl = require "luci.model.cloudd".init()
				local id = cloudd_get_self_id()
				local cdev = cl.get_device(id, "master")
				if nr.support_mesh() then
					sync_wifi_config()
				end
				cdev:send_config()
			end)
		end
	end
	return {errcode="0"}
end

function cloudd_get_linkstatus()
	local result = util.ubus("infocd", "basic", {name = "link"}) or {link={}}
	if #result.link == 0 then
		result.link[1] = {}
	end
	return result
end

function cloudd_get_wanstatus()
	local result = util.ubus("infocd", "wanstatus") or {}
	if result.parameter then
		return result.parameter
	else
		return result
	end
end

function cloudd_apply_cmd(d_id, p_data, topic, proto)
	local nr = require "luci.nradio"
	local ret = 1
	local output = ""
	local cmd_buffer = ""
	local prefix_path = "/var/run/cloudd/"
	local cmd_cache_return_prefix = prefix_path.."cmd_return"
	local cmd_cache_prefix = prefix_path.."cmd_result"
	local cmd_process_prefix = prefix_path.."cmd_process"
	local split_chr = "_"
	p_data["result"] = ""

	if not fs.access(prefix_path) then
		util.exec("mkdir -p "..prefix_path)
	end

	if p_data["cmd"] == "reboot" then
		ret = 0
		nr.fork_exec(function()
			nixio.nanosleep(5)
			util.exec("reboot")
		end)
	elseif p_data["cmd"] == "recovery" then
		ret = 0
		nr.fork_exec(function()
			nixio.nanosleep(5)
			util.exec("echo y|firstboot && reboot")
		end)
	elseif (p_data["cmd"] == "nslookup" or p_data["cmd"] == "ping") and p_data["destination"] then

		local cache_exsit = 0
		local cache_return_file = cmd_cache_return_prefix..split_chr..p_data["cmd"]..split_chr..p_data["destination"]
		local cache_file = cmd_cache_prefix..split_chr..p_data["cmd"]..split_chr..p_data["destination"]
		local cache_process = cmd_process_prefix..split_chr..p_data["cmd"]..split_chr..p_data["destination"]

		if fs.access(cache_return_file) then
			cache_exsit = 1
			ret = tonumber(fs.readfile(cache_return_file))
			util.exec("rm -f "..cache_return_file)
		end

		if fs.access(cache_file) then
			cache_exsit = 1
			output = fs.readfile(cache_file)
			util.exec("rm -f "..cache_file)
		end

		if cache_exsit == 0 then
			ret = 2
			if not fs.access(cache_process) then
				if p_data["cmd"] == "ping" then
					cmd_buffer=p_data["cmd"].." "..p_data["destination"].." -c 5 2>&1"
				else
					cmd_buffer=p_data["cmd"].." "..p_data["destination"].." 2>&1"
				end
				fs.writefile(cache_process,ret)
				nr.fork_exec(function()
					local asynchronous_ret = 1
					local asynchronous_output = ""
					asynchronous_ret, asynchronous_output = cloudd_execute_command(cmd_buffer)
					fs.writefile(cache_return_file,asynchronous_ret)
					fs.writefile(cache_file,asynchronous_output)
				end)
			end
		end
		if cache_exsit == 1 then
			util.exec("rm -f "..cache_process)
		end
	elseif p_data["cmd"] == "service" then
		local result_data = nr.deal_service(p_data)
		ret = result_data.code
		if ret ~= -1 then
			p_data["enabled"] = result_data.enabled
		end
	else
		ret=1
	end
	p_data["result"] = output
	p_data["code"] = ret
	cloudd.cloudd_send(d_id, topic, p_data, proto, 1)
end


function cloudd_set_topic_interval(data)
	local result = {list={}}
	local has_data = 0
	if data and data.list then
		for _,item in pairs (data.list) do
			local topic = item.topic
			local interval = 300
			if item.interval and (type(item.interval) == "string" or type(item.interval) == "number") then
				interval = tonumber(item.interval)
			end
			if topic and #topic > 0 then
				has_data = 1
				uci:set("report_proactively", topic,"topic")
				uci:set("report_proactively",topic,"interval",interval)
			end
		end
	end
	if has_data == 1 then
		uci:commit("report_proactively")
		os.execute("/etc/init.d/report_proactively restart >/dev/null 2>/dev/null")
	end
	uci:foreach("report_proactively", "topic",
		function(s)
			local rt_interval = 300
			if s.interval and (type(s.interval) == "string" or type(s.interval) == "number") then
				rt_interval = tonumber(s.interval)
			end
			result.list[#result.list+1] = {interval=rt_interval,topic=s[".name"]}
		end
	)

	if #result.list == 0 then
		result.list[1] = {}
	end
	return result
end
