module("luci.controller.nradio_adv.access", package.seeall)

local uci = require "luci.model.uci".cursor()
local lng = require "luci.i18n"
local util = require "luci.util"
local nr = require "luci.nradio"
local nx = require "nixio"
local json = require "luci.jsonc"

function index()
	if not luci.nradio.has_nat() then		
		return 
	end

	page = entry({"nradioadv", "network","access"}, template("nradio_access/index"), _("AccessTile"), 80, true)
	entry({"nradioadv", "network","access", "list"}, call("action_access_list"), nil, nil, true).leaf = true
	entry({"nradioadv", "network","access", "add"}, call("action_access_add"), nil, nil, true).leaf = true
	entry({"nradioadv", "network","access", "del"}, call("action_access_del"), nil, nil, true).leaf = true
	entry({"nradioadv", "network","access", "setmode"}, call("action_access_mode"), nil, nil, true).leaf = true
	entry({"nradioadv", "network","access", "enabled"}, call("action_access_enable"), nil, nil, true).leaf = true
	page.icon = 'nradio-access'
	page.show = true
end

function access_list()
	local data = {
		whitelist={},
		blacklist={},
		disabled="0",
		mode="0"
	}

	data.disabled = uci:get("access_ctl", "config", "disabled") or "0"
	data.mode = uci:get("access_ctl", "config", "mode") or "0"
	uci:foreach("access_ctl", "address",
		function(s)
			if s[".name"] == "blacklist" then
				if s["member"] then
					data.blacklist = s["member"]
				end
			elseif s[".name"] == "whitelist" then
				if s["member"] then
					data.whitelist = s["member"]
				end
			end
		end
	)

	if #data.whitelist == 0 then
		data.whitelist[1] = ""
	end
	if #data.blacklist == 0 then
		data.blacklist[1] = ""
	end
	return data
end
function action_access_list()
	local data = access_list()
	nr.luci_call_result(data)
end
function action_access_add()
	local member = luci.http.formvalue("address") or nil;
	local mode = luci.http.formvalue("mode") or nil;
	local mode_bf = nil;
	if mode == "0" then
		mode_bf = "blacklist"
	elseif mode == "1" then
		mode_bf = "whitelist"
	end

	if not member or not mode_bf then
		nr.luci_call_result({code = -1})
	end
	member = member:gsub("[;'\\\"]", "")
	util.exec("uci -q add_list access_ctl."..mode_bf..".member="..member)
	uci:commit("access_ctl")
	reload_work()
	nr.luci_call_result({code = 0})
end

function action_access_del()
	local member = luci.http.formvalue("address") or nil;
	local mode = luci.http.formvalue("mode") or nil;
	local mode_bf = nil;
	if mode == "0" then
		mode_bf = "blacklist"
	elseif mode == "1" then
		mode_bf = "whitelist"
	end

	if not member or not mode_bf then
		nr.luci_call_result({code = -1})
	end
	member = member:gsub("[;'\\\"]", "")
	util.exec("uci -q del_list access_ctl."..mode_bf..".member="..member)
	uci:commit("access_ctl")
	reload_work()
	nr.luci_call_result({code = 0})
end


function action_access_enable()
	local disabled = luci.http.formvalue("disabled") or nil;
	local cur_work = uci:get("access_ctl", "config", "disabled") or "0"
	if disabled and cur_work ~= disabled then
		uci:set("access_ctl", "config", "disabled", disabled)
		uci:commit("access_ctl")
		reload_work()
	end

	nr.luci_call_result({code = 0})
end

function action_access_mode()
	local mode = luci.http.formvalue("mode") or nil;
	local cur_mode = uci:get("access_ctl", "config", "mode") or "0"
	if mode and cur_mode ~= mode then
		uci:set("access_ctl", "config", "mode", mode)
		uci:commit("access_ctl")
		reload_work()
	end

	nr.luci_call_result({code = 0})
end

function reload_work()
	local client_ip = luci.http.getenv("REMOTE_ADDR") or ""
	nixio.syslog("err","WEB["..client_ip.."] config access changing")
	util.exec("/usr/bin/access_ctl.sh -r 1")
end
