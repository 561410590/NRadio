-- Copyright 2017-2018 NRadio

local pairs = pairs

local nw = require "luci.model.network"
local ut = require "luci.util"
local nt = require "luci.sys".net
local fs = require "nixio.fs"
local cl = require "luci.model.cloudd".init()
local nr = require "luci.nradio"
local ca = require "cloudd.api"
local disp = require "luci.dispatcher"
local nixio = require "nixio"
local luci_channel = disp._CHANNEL

local uniqv
local encrv = {}
local uniq_single = 0
local platform = nr.get_platform()
local id = ca.cloudd_get_self_id()
local tpl_def = '-1'

m = Map("cloudd", "")
if not luci_channel then
	m.title = translate("Wireless Setting")
else
	m:append(Template("nradio_wifi/wifi_simple"))
end
redirect = "nradio/basic/wifi"

nw.init(m.uci)
local uci = m.uci

local cdev = cl.get_device(id, "master")
local slaves = cdev:slaves_sort()

local function gettval(value)
	return value and value:sub(2) or ""
end

local function splitval(value)
	if value then
		local arr = ut.split(value, "=", 2)
		return arr[2]
	end

	return nil
end

local function getcfg(ifname, section, option)
	local tmp = m:get(section, option .. "_" .. ifname)
	return splitval(tmp)
end

local function setcfg(ifname, section, option, value, config)
	if not config then
		config = "wireless"
	end

	if value ~= tpl_def then
		local v = config .. "." .. ifname .. "." .. option .. "=" .. value
		m:set(section, option .. "_" .. ifname, v)
	else
		m:del(section, option .. "_" .. ifname)
	end
end

local function delcfg(ifname, section, option)
	m:del(section, option .. "_" .. ifname)
end

local function listopt(opt, vlist)
	for k, v in pairs(vlist) do
		opt:value(v[1], v[2])
	end
end

function tplparse(object, key, depend)
	object.rmempty = false

	function object.parse(self, section, novld)
		local fvalue = self:formvalue(section)
		local cvalue = self:cfgvalue(section)
		if not fvalue and key ~= depend then
			self:remove(section)
			return
		end
		return Value.parse(self, section, novld)
	end
end

local function initrw(object, group, iface, name, tpl_val, key)
	if iface and string.match(iface, "^radio") then
		object.cfgsect = group .. "radio"
	else
		object.cfgsect = group .. "wlan"
	end
	object.ifname = iface
	object.cfgopt = name
	object.tpl_val = tpl_val

	if object.widget == "select" then
		function object.cfgvalue(self, section)
			return getcfg(self.ifname, self.cfgsect, self.cfgopt) or self.tpl_val
		end

		function object.write(self, section, value)
			if value ~= self.tpl_val then
				if name and name == "encryption" then
					if value == "sae-mixed" or value == "sae" then
						setcfg(self.ifname, self.cfgsect, "ieee80211w", "1")
					else
						setcfg(self.ifname, self.cfgsect, "ieee80211w", "0")
					end
				end
				setcfg(self.ifname, self.cfgsect, self.cfgopt, value)
			else
				if name and name == "encryption" then
					delcfg(self.ifname, self.cfgsect, "ieee80211w")
				end
				delcfg(self.ifname, self.cfgsect, self.cfgopt)
			end
		end
	else
		object.rmempty = true

		function object.cfgvalue(self, section)
			val_str = getcfg(self.ifname, self.cfgsect, self.cfgopt) or self.tpl_val
			if name and name == "key1" then
				val_str = string.sub(val_str, 3)
			elseif name and name == "key" then
				if #val_str == 1 then
					val_str=""
				end
			end
			return val_str
		end

		function object.write(self, section, value)
			if key then
				key = value
			end
			if name and name == "key1" then
				value = "s:" .. value
				setcfg(self.ifname, self.cfgsect, "key", "1")
			end
			setcfg(self.ifname, self.cfgsect, self.cfgopt, value)
		end

		function object.remove(self, section)
			delcfg(self.ifname, self.cfgsect, self.cfgopt)
		end
	end
end

local function initrw_t0(object, key)
	if object.template == "cbi/fvalue" then
		object.rmempty = false
	end
	object.ifname = "t0"
	function object.cfgvalue(self, section)
		local tmp = self.map:get(self.ifname, self.option) or "X"
		local value = (tmp ~= "X") and tmp or "X"..(self.default or "")
		value = string.sub(value, 2)
		if self.option and self.option:match("key1") then
			value = string.sub(value, 3)
		elseif self.option and self.option:match("key") then
			if #value == 1 then
				value=""
			end
		end
		return value
	end

	function object.write(self, section, value)
		if key then
			key = value
		end
		if self.option and self.option:match("key1") then
			self.map:set(self.ifname, self.option, "Xs:"..value)
		else
			if self.option and self.option == "encryption_wlan" then
				if value == "sae-mixed" or value == "sae" then
					self.map:set(self.ifname, "ieee80211w_wlan", "X1")
				else
					self.map:set(self.ifname, "ieee80211w_wlan", "X0")
				end
			end
			self.map:set(self.ifname, self.option, "X"..value)
		end
	end
end

local function del_g1wlan()
	for i = 1, #slaves do
		local slave = slaves[i]
		local radio_cnt = slave:get_radiocnt()
		local radio_band2 = (radio_cnt.band2 or 1)
		local radio_band5 = (radio_cnt.band5 or 1)

		for j = 1, radio_band2 + radio_band5 do
			local index = j - 1
			local wlan
			if radio_band2 ~= 0 then
				wlan = "wlan"..index
			else
				wlan = "wlan"..(index + 1)
			end

			m:del("g1wlan", "disabled_"..wlan)
			m:del("g1wlan", "ssid_"..wlan)
			m:del("g1wlan", "encryption_"..wlan)
			m:del("g1wlan", "key_"..wlan)
			-- advance config
			-- m:del("g1wlan", "hidden_"..wlan)
			-- m:del("g1wlan", "macfilter_"..wlan)
			-- m:del("g1wlan", "acllist_"..wlan)
			-- m:del("g1wlan", "ieee80211w_"..wlan)
			-- m:del("g1wlan", "isolate_"..wlan)
		end
	end
end
local conf_diff_2_4_wlan = m.uci:get("cloudd", "t0", "diff_2_4_wlan") or "X0"
local function initrw_t0_unique(object)

	object.rmempty = false
	object.ifname = "t0"

	function object.cfgvalue(self, section)
		local tmp = self.map:get(self.ifname, self.option) or "X"
		local num = (tmp ~= "X") and tmp or "X"..(self.default or "")
		value = string.sub(num, 2)
		if value == "1" then
			return "0"
		else
			return "1"
		end
	end

	function object.write(self, section, value)
		if value == "1" then
			del_g1wlan()
			value = "0"
		else
			value = "1"
		end

		uniqv = value
		self.map:set(self.ifname, self.option, "X"..value)
	end
end

function m.on_after_commit(map)
	if nr.support_mesh() then
		ca.sync_wifi_config()
	end
	cdev:send_config()
end

-- wireless toggle was requested, commit and reload page
function m.parse(map)
	Map.parse(map)
end

m.uci = require("luci.model.uci").cursor()
local region = nr.get_wifi_region()
local vendor = nr.get_wifi_vendor()
local dfs_enable = tonumber(m.uci:get("wireless", "radio1", "dfs_enable") or "0")
local wifi7 = nr.support_eht()
local acmode = nr.has_ptype("ac") or false


local function wifi_max_clients(phyname)
	if phyname == "mt7981" or phyname == "mt7993" then
		return 128
	elseif phyname == "mt7628" or phyname == "mt7620" or phyname == "mt7603e" or phyname == "aic8800" or phyname == "swt6652" then
		return 16
	elseif phyname == "mt7612e" or phyname == "mt7663" then
		return 32
	elseif phyname == "mt7915" then
		return 64
	end

	return 16
end


-- WLAN Section
s = m:section(NamedSection, cdev:dname(), "wlan", "")

local total_radio2 = 0
local total_radio5 = 0
local index_radio2 = 0
local index_radio5 = 0

for i = 1, #slaves do
	local slave = slaves[i]
	local radio_cnt = slave:get_radiocnt()
	total_radio2 = total_radio2 + (radio_cnt.band2 or 1)
	total_radio5 = total_radio5 + (radio_cnt.band5 or 1)
end

if tonumber(total_radio2) > 0 and tonumber(total_radio5) > 0 then
	if not luci_channel then
		un = s:option(Flag, "diff_2_4_wlan",translate("Unique SSID"),translate("WifiHelp"))
	else
		un = s:option(Flag, "diff_2_4_wlan",translate("Unique SSID")..'<div class="un_help"><i class="far fa-nradio-note2 fa-fw" ></i></div>')
	end

	un.default = un.enabled
	initrw_t0_unique(un)

	-- local sep_mode = Template("nradio_wifi/wifi_underline")
	-- sep_mode.id = "wifi_underline_mode"
	-- sep_mode.depends = {
	-- 	{"diff_2_4_wlan", "1"},
	-- }
	-- s:append(sep_mode)
elseif  (tonumber(total_radio2) > 0 or tonumber(total_radio5) > 0 ) and conf_diff_2_4_wlan == "X0" then
	uniq_single = 1
end

un_en = s:option(Flag, "disabled_wlan", translate("Enable Wi-Fi"))

if uniq_single ~= 1 then
	un_en:depends({diff_2_4_wlan="1"})
end

un_en.rmempty = false
--initrw_t0(un_en)
function un_en.cfgvalue(self, section)
	local tmp = self.map:get("t0", self.option) or "X"
	local num = (tmp ~= "X") and tmp or "X"..(self.default or "")
	value = string.sub(num, 2)
	if value == "0" then
		return "1"
	else
		return "0"
	end
end
function un_en.write(self, section, value)
	if value == "1" then
		value = "0"
	else
		value = "1"
	end
	self.map:set("t0", self.option, "X"..value)
end

-- cbid.cloudd.d0.diff_2_4_ssid_wlan
--
un_ssid = s:option(Value, "ssid_wlan", translate("Wi-Fi SSID"))

if uniq_single ~= 1 then
	un_ssid:depends({diff_2_4_wlan="1"})
end
un_ssid.datatype = "and(minlength(1), maxlength(32))"
un_ssid.placeholder = translate("WifiHelpSSID")
initrw_t0(un_ssid)
tplparse(un_ssid, uniqv, "0")
un_encrlist,support_arr = nr.get_wifi_encryption()
if not luci_channel then
	un_encr = s:option(ListValue, "encryption_wlan", translate("Encryption"))

	if uniq_single ~= 1 then
		un_encr:depends({diff_2_4_wlan="1"})
	end

	listopt(un_encr, un_encrlist)
	initrw_t0(un_encr, encrv[1])

	if support_arr["ppsk"] then
		pb = s:option(Button, "ppsk_wlan", " ")
		pb:depends("encryption_wlan", "ppsk")
		pb.inputtitle = translate("Download Personal Password")
		pb.write = function(self, section, value)
			return luci.http.redirect(luci.dispatcher.build_url("nradio/ppsk/backup"))
		end
	end
end
un_wpakey = s:option(Value, "key_wlan", translate("Key"))
un_wpakey.placeholder = translate("WifiHelpPwd")
un_wpakey.password = true

un_wpakey.datatype = "wpakey"
initrw_t0(un_wpakey)

if not luci_channel then
	if uniq_single == 1 then
		adv_single = s:option(Flag, "wifi_adv_enable_single")
		adv_single.title = " "
		adv_single.template = "nradio_wifi/wifi_advance"
		adv_single.rmempty = false
		function adv_single.cfgvalue(self, section)
			return self:formvalue(section) or "0"
		end
		function adv_single.write(self, section, value)
			return true
		end
	else
		adv_unified = s:option(Flag, "wifi_adv_enable_unified")
		adv_unified.title = " "
		adv_unified.template = "nradio_wifi/wifi_advance"
		adv_unified:depends({diff_2_4_wlan="1"})
		adv_unified.rmempty = false
		function adv_unified.cfgvalue(self, section)
			return self:formvalue(section) or "0"
		end
		function adv_unified.write(self, section, value)
			return true
		end

		if tonumber(total_radio2 or 0) > 0 and tonumber(total_radio5 or 0) > 0 then
			local sep_unified = s:option(DummyValue, "wifi_underline_unified_sep", " ")
			sep_unified.template = "nradio_wifi/wifi_underline"
			sep_unified:depends({diff_2_4_wlan = "1", wifi_adv_enable_unified = "1"})
		end
	end
end

if not luci_channel then
	un_wpakey:depends("encryption_wlan", "psk-mixed")
	tplparse(un_wpakey, encrv[1], "psk-mixed")

	if support_arr["sae"] then
		un_wpakey:depends("encryption_wlan", "sae-mixed")
		tplparse(un_wpakey, encrv[1], "sae-mixed")
		un_wpakey:depends("encryption_wlan", "sae")
		tplparse(un_wpakey, encrv[1], "sae")
	end

	if support_arr["extra"] then
		if support_arr["psk"] then
			un_wpakey:depends("encryption_wlan", "psk")
			tplparse(un_wpakey, encrv[1], "psk")
		end

		if support_arr["wep-open"] then
			un_wepkey = s:option(Value, "key1_wlan", translate("Key"))
			un_wepkey:depends("encryption_wlan", "wep-open")
			un_wepkey.datatype = "wepkey"
			initrw_t0(un_wepkey)
			tplparse(un_wepkey, encrv[1], "wep-open")
		end

		if support_arr["wpa"] or support_arr["wpa2"] or support_arr["wpa-mixed"] then
			auth_server = s:option(Value, "auth_server_wlan", translate("Radius-Authentication-Server"))
			if support_arr["wpa-mixed"] then
				auth_server:depends("encryption_wlan", "wpa-mixed")
			end
			if support_arr["wpa"] then
				auth_server:depends("encryption_wlan", "wpa")
			end
			if support_arr["wpa2"] then
				auth_server:depends("encryption_wlan", "wpa2")
			end
			auth_server.datatype = "host(0)"
			initrw_t0(auth_server)

			auth_port = s:option(Value,"auth_port_wlan", translate("Radius-Authentication-Port"), translatef("Default %d", 1812))
			if support_arr["wpa-mixed"] then
				auth_port:depends("encryption_wlan", "wpa-mixed")
			end
			if support_arr["wpa"] then
				auth_port:depends("encryption_wlan", "wpa")
			end
			if support_arr["wpa2"] then
				auth_port:depends("encryption_wlan", "wpa2")
			end
			auth_port.datatype = "port"
			initrw_t0(auth_port)

			auth_secret = s:option(Value, "auth_secret_wlan", translate("Radius-Authentication-Secret"))
			if support_arr["wpa-mixed"] then
				auth_secret:depends("encryption_wlan", "wpa-mixed")
			end
			if support_arr["wpa"] then
				auth_secret:depends("encryption_wlan", "wpa")
			end
			if support_arr["wpa2"] then
				auth_secret:depends("encryption_wlan", "wpa2")
			end
			initrw_t0(auth_secret)
		end
	end

	if support_arr["psk2"] then
		un_wpakey:depends("encryption_wlan", "psk2")
		tplparse(un_wpakey, encrv[1], "psk2")
	end
end

local function component_name(option, group, section)
	return option.."_"..group.."_"..section
end

local append_radio_advanced
local append_single_radio_advanced
local guard_adv_parse

if not luci_channel then
	local function list_append(opt, values)
		for _, v in ipairs(values) do
			opt:value(v, v == "auto" and translate("Auto") or v)
		end
	end

	local function list_parse(values)
		local out = {}
		local function append_tokens(raw)
			local s = tostring(raw or "")
			if s == "" then
				return
			end
			for _, token in ipairs(ut.split(s, ",")) do
				if token then
					token = token:gsub("^%s+", ""):gsub("%s+$", "")
					if #token > 0 then
						out[#out + 1] = token
					end
				end
			end
		end
		if type(values) == "table" then
			for _, v in ipairs(values) do
				append_tokens(v)
			end
		elseif type(values) == "string" and #values > 0 then
			append_tokens(values)
		end
		return out
	end

	local function get_radio_chinfo(group, radname)
		for _, slave in ipairs(slaves) do
			if slave:group() == group then
				local radiocnt = slave:get_radiocnt() or {}
				if radiocnt.chlist and radiocnt.chlist[radname] then
					return radiocnt.chlist[radname]
				end
				return nil
			end
		end
		return nil
	end

	local function get_skip_channels()
		local function normalize(values)
			if values == nil then
				return ""
			end
			if type(values) == "string" then
				return values
			end
			if type(values) ~= "table" then
				return ""
			end
			local parts = {}
			for _, v in ipairs(values) do
				parts[#parts + 1] = tostring(v)
			end
			return table.concat(parts, ",")
		end

		local result = {}
		local cloudd_id = (ut.ubus("cloudd", "info") or {}).mac
		local device = cl.get_device(cloudd_id, "master")

		if not device then
			return result
		end

		local cloudd_slaves = device:slaves_sort()

		for j = 1, #cloudd_slaves do
			local slave = cloudd_slaves[j]
			local phy2_cnt = tonumber(uci:get("cloudd", slave:dname(), "p2cnt") or 1)
			local phy5_cnt = tonumber(uci:get("cloudd", slave:dname(), "p5cnt") or 1)
			local radiocnt = slave:get_radiocnt()

			for i = 1, (phy2_cnt + phy5_cnt) do
				local radidx = i - 1

				if phy2_cnt == 0 then
					radidx = radidx + 1
				end

				local radname = "radio" .. radidx
				if radiocnt and radiocnt.chlist and radiocnt.chlist[radname] then
					result[radname] = normalize(radiocnt.chlist[radname].skip_channels)
				else
					result[radname] = ""
				end
			end
		end
		return result
	end

	local skip_channels = get_skip_channels()

	local function get_channel_list(regions, freq, dfs, platforms)
		local WIFI_CHANNEL_TABLE = {
			JP = {
				["2"] = {
					[0] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14"},
					[1] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14"},
				},
				["5"] = {
					[0] = {"auto", "36", "40", "44", "48"},
					[1] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "100", "104", "108", "112", "116", "120", "124", "128", "132", "136", "140"},
				},
			},
			FCC = {
				["2"] = {
					[0] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"},
					[1] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"},
				},
				["5"] = {
					[0] = {"auto", "36", "40", "44", "48", "149", "153", "157", "161", "165"},
					[1] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "100", "104", "108", "112", "116", "132", "136", "140", "149", "153", "157", "161", "165"},
				},
			},
			CN = {
				["2"] = {
					[0] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
					[1] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
				},
				["5"] = {
					[0] = {"auto", "36", "40", "44", "48", "149", "153", "157", "161", "165"},
					[1] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "149", "153", "157", "161", "165"},
				},
			},
			CE = {
				["2"] = {
					[0] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
					[1] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
				},
				["5"] = {
					[0] = {"auto", "36", "40", "44", "48"},
					[1] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "100", "104", "108", "112", "116", "120", "124", "128", "132", "136", "140"},
				},
			},
			KR = {
				["2"] = {
					[0] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
					[1] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
				},
				["5"] = {
					[0] = {"auto", "36", "40", "44", "48", "149", "153", "157", "161", "165"},
					[1] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "100", "104", "108", "112", "116", "120", "124", "128", "132", "136", "140", "149", "153", "157", "161", "165"},
				},
			},
			ID = {
				["2"] = {
					[0] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
					[1] = {"auto", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13"},
				},
				["5"] = {
					[0] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "149", "153", "157", "161", "165"},
					[1] = {"auto", "36", "40", "44", "48", "52", "56", "60", "64", "149", "153", "157", "161", "165"},
				},
			},
		}

		local region_cfg = WIFI_CHANNEL_TABLE[regions] or WIFI_CHANNEL_TABLE.CN
		local band_cfg = region_cfg[freq] or WIFI_CHANNEL_TABLE.CN[freq]

		if freq == "5" and regions == "CN" then
			if platforms == "mtk" then
				return band_cfg[1]
			else
				return band_cfg[0]
			end
		end
		return band_cfg[dfs] or {"auto"}
	end

	local function bw_list_dft(freq)
		if freq == "2" then
			return {"20", "40"}
		end
		if nr.support_vht160() then
			return {"20", "40", "80", "160"}
		end
		return {"20", "40", "80"}
	end

	local function is_band4(channel)
		local ch = tonumber(channel)
		return ch and ch >= 149 and ch <= 165 or false
	end

	local function cbid_formvalue(section, optname)
		return m:formvalue("cbid." .. m.config .. "." .. section .. "." .. optname)
	end

	local function is_adv_enabled(section, group, wlanname)
		local unified = cbid_formvalue(section, "wifi_adv_enable_unified")
		local single = cbid_formvalue(section, "wifi_adv_enable_single")
		local split
		if group and wlanname then
			split = cbid_formvalue(section, component_name("adv_enable", group, wlanname))
		end
		return unified == "1" or single == "1" or split == "1"
	end

	guard_adv_parse = function(opt, group, wlanname)
		local old_parse = opt.parse
		function opt.parse(self, section, novld)
			local has_formvalue = (self:formvalue(section) ~= nil)
			local has_fexist = (self.map:formvalue("cbi.cbe." .. self.config .. "." .. section .. "." .. self.option) ~= nil)
			if not is_adv_enabled(section, group, wlanname) and not has_formvalue and not has_fexist then
				return
			end
			return old_parse(self, section, novld)
		end
	end

	local function initrw_adv_value(opt, group, ifname, cfgopt, tpl_val, valueopt)
		opt.ifname = ifname
		opt.cfgsect = group
		opt.cfgopt = cfgopt
		opt.tpl_val = tpl_val

		function opt.cfgvalue(self, section)
			return getcfg(self.ifname, self.cfgsect, self.cfgopt) or self.tpl_val
		end

		function opt.remove(self, section)
			delcfg(self.ifname, self.cfgsect, self.cfgopt)
		end

		function opt.write(self, section, value)
			local cur = self:cfgvalue(section)
			if value == cur then
				return
			end
			if value == nil or value == "" or value == self.tpl_val then
				return delcfg(self.ifname, self.cfgsect, self.cfgopt)
			end

			if valueopt then
				return valueopt(self, section, value)
			end

			return setcfg(self.ifname, self.cfgsect, self.cfgopt, value)
		end
	end
	local function build_radio_advanced(group, wlanname, is_5g, tabname, depends)
		local radidx = tonumber((wlanname or ""):match("^wlan(%d+)$")) or 0
		local radname = "radio" .. radidx
		local freq = is_5g and "5" or "2"
		local freqopt
		local show_tab_prefix = not (platform == "tdtech" or uniq_single == 1 or (tonumber(total_radio2 or 0) + tonumber(total_radio5 or 0) <= 1))

		local function apply_dep(opt)
			if not depends then
				return
			end
			if depends[1] then
				for _, dep in ipairs(depends) do
					opt:depends(dep)
				end
			else
				opt:depends(depends)
			end
		end

		local function adv_title(title)
			if show_tab_prefix then
				return tabname .. " " .. translate(title)
			end
			return translate(title)
		end

		local function current_freq(section)
			local resolved = freq
			if platform == "tdtech" and freqopt then
				local band = freqopt:formvalue(section) or freqopt:cfgvalue(section) or (is_5g and "5g" or "2g")
				resolved = (band == "5g") and "5" or "2"
			end
			return resolved
		end

		if platform == "tdtech" then
			freqopt = s:option(ListValue, component_name("band", group, radname), adv_title("Freq"))
			freqopt:value("2g", translate("2.4GHz"))
			freqopt:value("5g", translate("5GHz"))
			initrw_adv_value(freqopt, group .. "radio", radname, "band", is_5g and "5g" or "2g")
			apply_dep(freqopt)
			guard_adv_parse(freqopt, group, wlanname)
		end

		if wifi7 then
			local modeopt = s:option(ListValue, component_name("hwmode", group, radname), adv_title("WifiMode"))
			if is_5g then
				modeopt:value("11be", "Wi-Fi7(802.11a/n/ac/ax/be)")
				modeopt:value("11ax", "Wi-Fi6(802.11a/n/ac/ax)")
				modeopt:value("11ac", "Wi-Fi5(802.11a/n/ac)")
				modeopt.description = '<span class="sim_detail_err">' .. translate("WifiModeHelp5") .. "</span>"
			else
				modeopt:value("11be", "Wi-Fi7(802.11b/g/n/ax/be)")
				modeopt:value("11ax", "Wi-Fi6(802.11b/g/n/ax)")
				modeopt:value("11n", "Wi-Fi4(802.11b/g/n)")
				modeopt.description = '<span class="sim_detail_err">' .. translate("WifiModeHelp2") .. "</span>"
			end
			initrw_adv_value(modeopt, group .. "radio", radname, "hwmode", "")
			apply_dep(modeopt)
			guard_adv_parse(modeopt, group, wlanname)
		end

		local chopt = s:option(ListValue, component_name("channel", group, radname), adv_title("Channel"))
		local chinfo = get_radio_chinfo(group, radname)
		local chlist = chinfo and list_parse(chinfo.chlist) or {}

		if #chlist == 0 then
			if platform == "tdtech" then
				local merged = {}
				local mark = {}

				local function push_channels(items)
					for _, ch in ipairs(items) do
						if ch ~= "auto" and not mark[ch] then
							mark[ch] = true
							merged[#merged + 1] = ch
						end
					end
				end

				push_channels(get_channel_list(region, "2", dfs_enable, platform))
				push_channels(get_channel_list(region, "5", dfs_enable, platform))
				chlist = {"auto"}
				for _, ch in ipairs(merged) do
					chlist[#chlist + 1] = ch
				end
			else
				chlist = get_channel_list(region, freq, dfs_enable, platform)
			end
		end

		local skipset = {}
		local skip_channels_str = skip_channels[radname] or ""
		if type(skip_channels_str) == "string" and #skip_channels_str > 0 then
			local skip = ut.split(skip_channels_str, ",")
			if skip and #skip > 0 then
				for _, ch in ipairs(skip) do
					if ch ~= "" then
						skipset[ch] = true
					end
				end
			end
		end

		local filtered = {"auto"}
		local allowed = { auto = true }
		for _, ch in ipairs(chlist) do
			if ch ~= "auto" and not skipset[ch] then
				filtered[#filtered + 1] = ch
				allowed[ch] = true
			end
		end

		local function build_allowed(freq_key)
			local map = { auto = true }
			for _, ch in ipairs(get_channel_list(region, freq_key, dfs_enable, platform)) do
				if ch ~= "auto" and not skipset[ch] then
					map[ch] = true
				end
			end
			return map
		end

		local allowed2 = build_allowed("2")
		local allowed5 = build_allowed("5")

		local function allowed_for(section)
			if current_freq(section) == "5" then
				return allowed5
			end
			return allowed2
		end

		list_append(chopt, filtered)
		initrw_adv_value(chopt, group .. "radio", radname, "channel", "", function(self, section, value)
			local v = value
			if v == "auto" and (not acmode) and platform ~= "tdtech" and vendor ~= "seekwave" then
				if not m.uci:get("wireless", radname, "chlist") then
					v = "0"
				end
			end
			return setcfg(self.ifname, self.cfgsect, self.cfgopt, v)
		end)

		function chopt.cfgvalue(self, section)
			local cur = getcfg(self.ifname, self.cfgsect, self.cfgopt) or "auto"
			if cur == "0" or cur == "-1" then
				return "auto"
			end
			-- if not allowed_for(section)[tostring(cur)] then
			-- 	return "auto"
			-- end
			return cur
		end
		function chopt.validate(self, value, section)
			if not allowed_for(section)[tostring(value)] then
				return nil
			end
			return value
		end

		function chopt.write(self, section, value)
			if value == nil or value == "" then
				return delcfg(self.ifname, self.cfgsect, self.cfgopt)
			end
			local target = value
			if target == "auto" and (not acmode) and platform ~= "tdtech" and vendor ~= "seekwave" then
				if not m.uci:get("wireless", radname, "chlist") then
					target = "0"
				end
			end
			return setcfg(self.ifname, self.cfgsect, self.cfgopt, target)
		end

		apply_dep(chopt)
		guard_adv_parse(chopt, group, wlanname)

		local bwopt = s:option(ListValue, component_name("htmode", group, radname), adv_title("Bandwidth"))
		local bw_values = bw_list_dft(freq)

		if platform == "tdtech" then
			bw_values = bw_list_dft("5")
		end
		for _, bw in ipairs(bw_values) do
			bwopt:value(bw, translate(bw .. "MHz"))
		end

		bwopt.ifname = radname
		bwopt.cfgsect = group .. "radio"
		bwopt.cfgopt = "htmode"

		function bwopt.cfgvalue(self, section)
			local cur = getcfg(self.ifname, self.cfgsect, self.cfgopt) or ""
			local value = "20"
			if cur:match("160") then
				value = "160"
			elseif cur:match("80") then
				value = "80"
			elseif cur:match("40") then
				value = "40"
			elseif cur:match("20") then
				value = "20"
			end
			if current_freq(section) == "2" and (value == "80" or value == "160") then
				return "20"
			end
			return value
		end

		function bwopt.validate(self, value, section)
			local chv = chopt:formvalue(section) or chopt:cfgvalue(section) or ""
			local curfreq = current_freq(section)
			if curfreq == "2" and (value == "80" or value == "160") then
				return nil
			end
			if curfreq == "5" and tonumber(chv) == 165 and value ~= "20" then
				return nil
			end
			if curfreq == "5" and nr.support_vht160() and is_band4(chv) and value == "160" then
				return nil
			end
			return value
		end

		function bwopt.write(self, section, value)
			if value == self:cfgvalue(section) then
				return
			end
			if value == nil or value == "" then
				return delcfg(self.ifname, self.cfgsect, self.cfgopt)
			end

			-- local prefix = is_5g and "VHT" or "HT"
			local prefix = (radname == "radio0") and "HT" or "VHT"
			return setcfg(self.ifname, self.cfgsect, self.cfgopt, prefix .. value)
		end
		apply_dep(bwopt)
		guard_adv_parse(bwopt, group, wlanname)

		if platform ~= "tdtech" and platform ~= "quectel" then
			local txpopt = s:option(ListValue, component_name("txpower", group, radname), adv_title("Transmit Power"))
			txpopt:value("100", translate("Strong"))
			txpopt:value("80", translate("Normal"))
			txpopt:value("50", translate("Poor"))
			txpopt.ifname = radname
			txpopt.cfgsect = group .. "radio"
			txpopt.cfgopt = "txpower"
			txpopt.tpl_val = "100"

			function txpopt.cfgvalue(self, section)
				local cur = tonumber(getcfg(self.ifname, self.cfgsect, self.cfgopt) or "100")
				if cur >= 80 and cur < 100 then
					return "80"
				elseif cur < 80 then
					return "50"
				end
				return "100"
			end

			function txpopt.write(self, section, value)
				if value == self:cfgvalue(section) then
					return
				end
				if value == nil or value == "" then
					return delcfg(self.ifname, self.cfgsect, self.cfgopt)
				end
				return setcfg(self.ifname, self.cfgsect, self.cfgopt, value)
			end
			apply_dep(txpopt)
			guard_adv_parse(txpopt, group, wlanname)
		end

		local phyname = m.uci:get("wireless", radname, "phyname") or ""
		local max_client = wifi_max_clients(phyname)

		local maxopt = s:option(Value, component_name("maxstanum", group, wlanname), adv_title("Maximum Stations Limit"))
		maxopt.datatype = "range(1," .. max_client .. ")"
		maxopt.rmempty = true
		maxopt.placeholder = translate("WifiPlaceholder") .. "1 ~ " .. max_client
		maxopt.ifname = wlanname
		maxopt.cfgsect = group .. "wlan"
		maxopt.cfgopt = "maxstanum"
		maxopt.tpl_val = ""

		function maxopt.cfgvalue(self, section)
			local cur = getcfg(self.ifname, self.cfgsect, self.cfgopt) or ""
			local n = tonumber(cur)
			if n and n > max_client then
				return tostring(max_client)
			end
			return cur
		end

		function maxopt.write(self, section, value)
			if value == self:cfgvalue(section) then
				return
			end
			local optname = "maxstanum"
			if platform == "tdtech" or platform == "quectel" then
				optname = "maxassoc"
			end
			if value == nil or value == "" then
				return m:set(self.cfgsect, self.cfgopt .. "_" .. self.ifname, "wireless." .. self.ifname .. "." .. optname .. "=")
			end
			return m:set(self.cfgsect, self.cfgopt .. "_" .. self.ifname, "wireless." .. self.ifname .. "." .. optname .. "=" .. value)
		end
		function maxopt.remove(self, section)
			local optname = "maxstanum"
			if platform == "tdtech" or platform == "quectel" then
				optname = "maxassoc"
			end
			return m:set(self.cfgsect, self.cfgopt .. "_" .. self.ifname, "wireless." .. self.ifname .. "." .. optname .. "=")
		end

		apply_dep(maxopt)
		guard_adv_parse(maxopt, group, wlanname)

		if platform ~= "tdtech" and platform ~= "quectel" then
			local rssiopt = s:option(Value, component_name("lowrssi", group, wlanname), adv_title("RSSI Threshold"))
			rssiopt.datatype = "range(-110, 0)"
			rssiopt.rmempty = true
			rssiopt.placeholder = translate("WifiPlaceholder") .. "-110 ~ 0 dBm"
			rssiopt.ifname = wlanname
			rssiopt.cfgsect = group .. "wlan"
			rssiopt.cfgopt = "lowrssi"
			rssiopt.tpl_val = ""

			function rssiopt.cfgvalue(self, section)
				local cur = getcfg(self.ifname, self.cfgsect, self.cfgopt) or ""
				local n = tonumber(cur)
				if n == nil then
					return ""
				end
				if n == 0 then
					return "0"
				end
				if n > 0 then
					if n > 110 then
						n = 110
					end
					return tostring(-n)
				end
				if n < -110 then
					return "-110"
				end
				if n > 0 then
					return "0"
				end
				return tostring(n)
			end

			function rssiopt.write(self, section, value)
				if value == self:cfgvalue(section) then
					return
				end
				if value == nil or value == "" then
					return setcfg(self.ifname, self.cfgsect, self.cfgopt, "")
				end
				local n = tonumber(value)
				if n == nil then
					return setcfg(self.ifname, self.cfgsect, self.cfgopt, "")
				end
				return setcfg(self.ifname, self.cfgsect, self.cfgopt, tostring(math.abs(n)))
			end

			function rssiopt.remove(self, section)
				return setcfg(self.ifname, self.cfgsect, self.cfgopt, "")
			end
			apply_dep(rssiopt)
			guard_adv_parse(rssiopt, group, wlanname)
		end
	end
	append_radio_advanced = function(group, wlanname, is_5g, tabname, depends)
		return build_radio_advanced(group, wlanname, is_5g, tabname, depends)
	end
	append_single_radio_advanced = function(group, wlanname, is_5g, tabname, depends)
		return build_radio_advanced(group, wlanname, is_5g, tabname, depends)
	end

	local function resolve_single_radio_context()
		for i = 1, #slaves do
			local slave = slaves[i]
			local radio_cnt = slave:get_radiocnt()
			local radio_band2 = (radio_cnt.band2 or 1)
			local radio_band5 = (radio_cnt.band5 or 1)
			for j = 1, radio_band2 + radio_band5 do
				local index = j - 1
				local band5 = true
				local tabname = "5GHz"
				local wlan

				if index < radio_band2 then
					band5 = false
					tabname = "2.4GHz"
				end

				if radio_band2 + radio_band5 == 1 then
					wlan = "wlan0"
				else
					if radio_band2 ~= 0 then
						wlan = "wlan" .. index
					else
						wlan = "wlan" .. (index + 1)
					end
				end

				return slave:group(), wlan, band5, tabname
			end
		end
		return nil
	end

	if uniq_single == 1 then
		local single_group, single_wlan, single_is_5g, single_tabname = resolve_single_radio_context()
		if single_group and single_wlan then
			append_single_radio_advanced(single_group, single_wlan, single_is_5g, single_tabname, {wifi_adv_enable_single = "1"})
		end

		un_macfilt = s:option(ListValue, "macfilter_wlan", translate("ACL Policy"))
		un_macflist = {
			{"none", translate("Disable")},
			{"deny", translate("Black List")},
			{"allow", translate("White List")},
		}
		un_macfilt:depends({wifi_adv_enable_single="1"})
		listopt(un_macfilt, un_macflist)
		initrw_t0(un_macfilt)
		guard_adv_parse(un_macfilt)

		un_acl = s:option(ListValue, "acllist_wlan", translate("ACL List"))
		un_acl:depends({wifi_adv_enable_single="1", macfilter_wlan="deny"})
		un_acl:depends({wifi_adv_enable_single="1", macfilter_wlan="allow"})
		un_acllist = {}
		m.uci:foreach("cloudd_acl", "acl",
					function(s)
						un_acllist[#un_acllist + 1] = {s[".name"], s.name}
					end
		)
		listopt(un_acl, un_acllist)
		initrw_t0(un_acl)
		guard_adv_parse(un_acl)

		un_hidden = s:option(Flag, "hidden_wlan", translate("Hide SSID"))
		un_hidden:depends({wifi_adv_enable_single="1"})
		initrw_t0(un_hidden)
		guard_adv_parse(un_hidden)

		un_isolate = s:option(Flag, "isolate_wlan", translate("Isolate Clients"))
		un_isolate:depends({wifi_adv_enable_single="1"})
		initrw_t0(un_isolate)
		un_isolate.rmempty = false
		guard_adv_parse(un_isolate)
	end
end

if uniq_single ~= 1 then
	local total_wifi_blocks = tonumber(total_radio2 or 0) + tonumber(total_radio5 or 0)
	local wifi_block_index = 0
	for i = 1, #slaves do
		local slave = slaves[i]
		local radio_cnt = slave:get_radiocnt()
		local group = slave:group()
		local tpl_list = m:get(group, "template") or {}
		local radio_band2 = (radio_cnt.band2 or 1)
		local radio_band5 = (radio_cnt.band5 or 1)
		for j = 1, radio_band2 + radio_band5 do
			local band5 = true
			local index = j - 1
			local tabname = "5GHz"
			local wlan
			local tX = tpl_list[index + 1] or "t0"
			local tcfg = m:get(tX) or {}
			local ssid_tpl_val

			if index < radio_band2 then
				band5 = false
				tabname = "2.4GHz"
				index_radio2 = index_radio2 + 1
				if total_radio2 > 1 then
					tabname = "2.4GHz-"..(index_radio2)
				end
			else
				index_radio5 = index_radio5 + 1
				if total_radio5 > 1 then
					tabname = "5GHz-"..(index_radio5)
				end
			end

		   -- s:tab(tabname, tabname)
			if radio_band2 + radio_band5 == 1 then
				wlan = "wlan0"
			else
				if radio_band2 ~= 0 then
					wlan = "wlan"..index
				else
					wlan = "wlan"..(index + 1)
				end
			end
			wifi_block_index = wifi_block_index + 1
			if tonumber(radio_band2) == 0 or tonumber(radio_band5) == 0 then
				en = s:option(Flag, component_name("disabled", group, wlan), translate("Wi-Fi"))
			else
				en = s:option(Flag, component_name("disabled", group, wlan), tabname.." "..translate("Wi-Fi"))
			end
			en:depends({diff_2_4_wlan=""})
			en.rmempty = false
			en.ifname = wlan
			en.cfgsect = group.."wlan"
			en.cfgopt = "disabled"
			function en.cfgvalue(self, section)
				local tmp = getcfg(self.ifname, self.cfgsect, self.cfgopt)
				if tmp == nil then
					local tmp = m:get("t0", "disabled_wlan") or "X"
					local num = (tmp ~= "X") and tmp or "X"..(self.default or "")
					local value = string.sub(num, 2)

					if value == "0" then
						return "1"
					else
						return "0"
					end
				end

				local value = tonumber(tmp or 0)
				if value == 0 then
					return "1"
				else
					return "0"
				end
			end
			function en.write(self, section, value)
				if value == "1" then
					value = "0"
				else
					value = "1"
				end
				setcfg(self.ifname, self.cfgsect, self.cfgopt, value)
			end

			ssid = s:option( Value, component_name("ssid", group, wlan), translate("Wi-Fi SSID"))
			ssid:depends({diff_2_4_wlan=""})
			ssid.datatype = "and(minlength(1),maxlength(32))"
			ssid.forcewrite=true
			ssid.placeholder = translate("WifiHelpSSID")
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
				luci.nradio.syslog("info","match id")
			else
				ssid_tpl_val = ssid_tpl_val..wifi_reverse_label
			end

			initrw(ssid, group, wlan, "ssid", ssid_tpl_val)
			tplparse(ssid, uniqv, "1")
			if not luci_channel then
				encr = s:option(ListValue, component_name("encryption", group, wlan), translate("Encryption"))
				encr:depends({diff_2_4_wlan=""})
				encrlist = un_encrlist
				listopt(encr, encrlist)
				initrw(encr, group, wlan, "encryption", gettval(tcfg["encryption_wlan"]), encrv[j+1])
				if support_arr["ppsk"] then
					pb = s:option(Button, component_name("ppsk", group, wlan), " ")
					pb:depends(component_name("encryption", group, wlan), "ppsk")
					pb.inputtitle = translate("Download Personal Password")
					pb.write = function(self, section, value)
						return luci.http.redirect(luci.dispatcher.build_url("nradio/ppsk/backup"))
					end
				end
			end

			wpakey = s:option(Value, component_name("key", group, wlan), translate("Key"))
			wpakey.placeholder = translate("WifiHelpPwd")
			wpakey.password = true
			if not luci_channel then
				wpakey:depends(component_name("encryption", group, wlan), "psk-mixed")
				if support_arr["extra"] then
					if support_arr["psk"] then
						wpakey:depends(component_name("encryption", group, wlan), "psk")
					end
				end

				if support_arr["psk2"] then
					wpakey:depends(component_name("encryption", group, wlan), "psk2")
				end

				if support_arr["sae"] then
					wpakey:depends(component_name("encryption", group, wlan), "sae-mixed")
					wpakey:depends(component_name("encryption", group, wlan), "sae")
				end
			end

			wpakey.datatype = "wpakey"
			initrw(wpakey, group, wlan, "key", gettval(tcfg["key_wlan"]))
			tplparse(wpakey, encrv[j+1], "psk-mixed")

			if support_arr["extra"] then
				if support_arr["psk"] then
					tplparse(wpakey, encrv[j+1], "psk")
				end
			end

			if support_arr["psk2"] then
				tplparse(wpakey, encrv[j+1], "psk2")
			end

			if support_arr["sae"] then
				tplparse(wpakey, encrv[j+1], "sae-mixed")
				tplparse(wpakey, encrv[j+1], "sae")
			end

			local adv_toggle = nil
			if not luci_channel then
				local adv_optname = component_name("adv_enable", group, wlan)
				adv_toggle = s:option(Flag, adv_optname)
				adv_toggle.title = " "
				adv_toggle.template = "nradio_wifi/wifi_advance"
				adv_toggle:depends({diff_2_4_wlan=""})
				adv_toggle.rmempty = false

				function adv_toggle.cfgvalue(self, section)
					return self:formvalue(section) or "0"
				end
				function adv_toggle.write(self, section, value)
					return true
				end
			end

			if support_arr["kprsa"] and not luci_channel then
				seed = s:option(Value, component_name("seed", group, wlan), translate("Private Key"))
				seed:depends(component_name("encryption", group, wlan), "kprsa")
				seed.datatype = "rangelength(1,8)"
				initrw(seed, group, wlan, "seed", gettval(tcfg["seed_wlan"]))
			end
			if support_arr["extra"] then
				if not luci_channel then
					if support_arr["wpa"] or support_arr["wpa2"] or support_arr["wpa-mixed"] then
						auth_server = s:option(Value, component_name("auth_server", group, wlan), translate("Radius-Authentication-Server"))
						if support_arr["wpa"] then
							auth_server:depends(component_name("encryption", group, wlan), "wpa")
						end
						if support_arr["wpa2"] then
							auth_server:depends(component_name("encryption", group, wlan), "wpa2")
						end
						if support_arr["wpa-mixed"] then
							auth_server:depends(component_name("encryption", group, wlan), "wpa-mixed")
						end
						auth_server.datatype = "host(0)"
						initrw(auth_server, group, wlan, "auth_server", gettval(tcfg["auth_server_wlan"]))

						auth_port = s:option(Value, component_name("auth_port", group, wlan), translate("Radius-Authentication-Port"), translatef("Default %d", 1812))
						if support_arr["wpa"] then
							auth_port:depends(component_name("encryption", group, wlan), "wpa")
						end

						if support_arr["wpa2"] then
							auth_port:depends(component_name("encryption", group, wlan), "wpa2")
						end
						if support_arr["wpa-mixed"] then
							auth_port:depends(component_name("encryption", group, wlan), "wpa-mixed")
						end
						auth_port.datatype = "port"
						initrw(auth_port, group, wlan, "auth_port", gettval(tcfg["auth_port_wlan"]))

						auth_secret = s:option(Value, component_name("auth_secret", group, wlan), translate("Radius-Authentication-Secret"))
						if support_arr["wpa"] then
							auth_secret:depends(component_name("encryption", group, wlan), "wpa")
						end
						if support_arr["wpa2"] then
							auth_secret:depends(component_name("encryption", group, wlan), "wpa2")
						end
						if support_arr["wpa-mixed"] then
							auth_secret:depends(component_name("encryption", group, wlan), "wpa-mixed")
						end
						initrw(auth_secret, group, wlan, "auth_secret", gettval(tcfg["auth_secret_wlan"]))
					end
				end

				if support_arr["wep-open"] then
					wepkey = s:option(Value,component_name("key1", group, wlan), translate("Key"))
					wepkey:depends(component_name("encryption", group, wlan), "wep-open")
					wepkey.placeholder = translate("WifiHelpPwd")
					wepkey.datatype = "wepkey"
					wepkey.password = true
					wepkey:depends({diff_2_4_wlan=""})
					initrw(wepkey, group, wlan, "key1", gettval(tcfg["key1_wlan"]))
					tplparse(wepkey, encrv[j+1], "wep-open")
				end
			end
			if not luci_channel then
				local adv_deps = {
					{diff_2_4_wlan = "1", wifi_adv_enable_unified = "1"},
				}
				if adv_toggle then
					adv_deps[#adv_deps + 1] = {diff_2_4_wlan = "", [adv_toggle.option] = "1"}
				end

				append_radio_advanced(group, wlan, band5, tabname, adv_deps)

				macfilt = s:option(ListValue, component_name("macfilter", group, wlan), translate("ACL Policy"))
				macflist = {
					{"none", translate("Disable")},
					{"deny", translate("Black List")},
					{"allow", translate("White List")},
				}
				for _, dep in ipairs(adv_deps) do
					macfilt:depends(dep)
				end
				listopt(macfilt, macflist)
				initrw(macfilt, group, wlan, "macfilter", gettval(tcfg["macfilter_wlan"]))
				guard_adv_parse(macfilt, group, wlan)

				acl = s:option(ListValue, component_name("acllist", group, wlan), translate("ACL List"))
				local macfilter = component_name("macfilter", group, wlan)
				if adv_toggle then
					acl:depends({diff_2_4_wlan = "", [adv_toggle.option] = "1", [macfilter] = "deny"})
					acl:depends({diff_2_4_wlan = "", [adv_toggle.option] = "1", [macfilter] = "allow"})
				end
				acl:depends({diff_2_4_wlan = "1", wifi_adv_enable_unified = "1", [macfilter] = "deny"})
				acl:depends({diff_2_4_wlan = "1", wifi_adv_enable_unified = "1", [macfilter] = "allow"})

				acllist = {}
				m.uci:foreach("cloudd_acl", "acl",
							function(s)
								acllist[#acllist + 1] = {s[".name"], s.name}
							end
				)

				listopt(acl, acllist)
				initrw(acl, group, wlan, "acllist", gettval(tcfg["acllist_wlan"]))
				function acl.cfgvalue(self, section)
					return m:get(self.cfgsect, self.cfgopt .. "_" .. self.ifname) or self.tpl_val
				end
				function acl.write(self, section, value)
					if value == self.tpl_val then
						return m:del(self.cfgsect, self.cfgopt .. "_" .. self.ifname)
					else
						return m:set(self.cfgsect, self.cfgopt .. "_" .. self.ifname, value)
					end
				end
				guard_adv_parse(acl, group, wlan)

				hidden = s:option(Flag, component_name("hidden", group, wlan), translate("Hide SSID"))
				for _, dep in ipairs(adv_deps) do
					hidden:depends(dep)
				end
				initrw(hidden, group, wlan, "hidden", gettval(tcfg["hidden_wlan"]))
				hidden.rmempty = false
				guard_adv_parse(hidden, group, wlan)

				isolate = s:option(Flag, component_name("isolate", group, wlan), translate("Isolate Clients"))
				for _, dep in ipairs(adv_deps) do
					isolate:depends(dep)
				end
				initrw(isolate, group, wlan, "isolate", gettval(tcfg["isolate_wlan"]))
				isolate.rmempty = false
				guard_adv_parse(isolate, group, wlan)

				if total_wifi_blocks > 1 and wifi_block_index < total_wifi_blocks then
					local sep_wifi = s:option(DummyValue, component_name("wifi_underline", group, wlan), " ")
					sep_wifi.template = "nradio_wifi/wifi_underline"
					sep_wifi:depends({diff_2_4_wlan = ""})
					sep_wifi:depends({diff_2_4_wlan = "1", wifi_adv_enable_unified = "1"})
				end
			end
		end
	end
end

if not luci_channel then
	m:append(Template("nradio_wifi/template"))
end

submit = Template("nradio_plugin/confirm_submit")
function submit.render(self)
	local no_ppsk_flag = true
	if support_arr["ppsk"] then
		no_ppsk_flag = false
	end
	luci.template.render(self.template, {noppsk = no_ppsk_flag})
end
m:append(submit)

return m
