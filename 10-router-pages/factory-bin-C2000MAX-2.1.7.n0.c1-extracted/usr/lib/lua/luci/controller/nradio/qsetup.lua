-- Copyright 2017 NRadio

module("luci.controller.nradio.qsetup", package.seeall)

local uci = require "luci.model.uci".cursor()
local fs = require "nixio.fs"
local nr = require "luci.nradio"

function index()
	local uci = require "luci.model.uci".cursor()
	local first = uci:get("luci", "main", "first") or "1"
	local nr = require "luci.nradio"
	if not nr.has_cpe() then
		if tonumber(first) == 0 then
			entry({"nradio", "qsetup"}, alias("nradio", "status"), _("Status"), 0, true).index = true
		else
			entry({"nradio", "qsetup"}, template("nradio_qsetup/first"), _("QSetupTitle"), 0, true).index = true
		end

		entry({"nradio", "qsetup", "second"}, template("nradio_qsetup/second"), _("QSetupTitle"), 2, true).index = true
		entry({"nradio", "qsetup", "second_wifi"}, template("nradio_qsetup/second_wifi"), _("QSetupTitle"), 3, true).index = true
		entry({"nradio", "qsetup", "second_pppoe"}, template("nradio_qsetup/second_pppoe"), _("QSetupTitle"), 4, true).index = true
		entry({"nradio", "qsetup", "second_static"}, template("nradio_qsetup/second_static"), _("QSetupTitle"), 5, true).index = true
		entry({"nradio", "qsetup", "other_mode"}, template("nradio_qsetup/other_mode"), _("QSetupTitle"), 6, true).index = true
		entry({"nradio", "qsetup", "third"}, template("nradio_qsetup/third"), _("QSetupTitle"), 7, true).index = true
		entry({"nradio", "qsetup", "get_account"}, template("nradio_qsetup/get_account"), _("QSetupTitle"), 8, true).index = true
		entry({"nradio", "qsetup", "privacy_agreement"}, template("nradio_qsetup/privacy_agreement"), _("QSetupTitle"), 9, true).index = true

		entry({"nradio", "qsetup", "get_old_account"}, call("action_get_account"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "pppoe_sniff_status"}, call("action_pppoe_sniff"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "get_pppoe_id"}, call("action_pppoe_id"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "detcet"}, call("action_system_detcet"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "detcet_status"}, call("action_detcet_status"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "wifi"}, call("action_system_wifi"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "wifiset"}, call("action_wifi_set"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "end"}, call("action_end_set"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "dhcpset"}, call("action_dhcp_set"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "pppoeset"}, call("action_pppoe_set"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "pppoedial"}, call("action_pppoe_dial"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "staticset"}, call("action_static_set"), nil, nil, true).leaf = true
		entry({"nradio", "qsetup", "next"}, call("action_system_next"), nil, nil, true).leaf = true
	end
end

function action_get_account()
	os.execute("/usr/sbin/pppoe-sniffer")
end


function action_pppoe_sniff_status()

	local result = {detect = "error",username = "nil",password = "nil"}
	if not fs.access("/tmp/pppoekey") then
		return  result
	end

	for l in io.lines("/tmp/pppoekey") do
		local u,v = l:match('(%w+):(%S+)')
		if u == "username" then
			result.username = v
		end
		if u == "password" then
			result.password = v
		end
	end
	result.detect = "ok"

	uci:set("network", "wan", "username", result.username)
	uci:set("network", "wan", "password", result.password)
	uci:commit("network")

	return result
end

function action_pppoe_sniff()
	nr.luci_call_result(action_pppoe_sniff_status())
end


function action_pppoe_id_get()
	local result = {detect = "error",username = "nil",password = "nil"}
	local username = uci:get("network", "wan", "username") or "nil"
	local password = uci:get("network", "wan", "password") or "nil"
	if username == "nil" or password == "nil" then
		return  result
	end
	result.username = username
	result.password = password
	result.detect = "ok"
	return result
end

function action_pppoe_id()
	nr.luci_call_result(action_pppoe_id_get())
end

function action_detcet_for_sniffer()
	local device=uci:get("network", "wan", "ifname") or uci:get("network", "wan", "device") or "eth0.2"
	if fs.access("/tmp/autowan") then
		os.execute("rm /tmp/autowan")
	end
	os.execute("killall auto_adapt")
	os.execute("auto_adapt -o -i "..device)
end

function action_detcet_for_adapt()
	local cmd
	local port = uci:get("auto_adapt", "mode", "port") or "nil"
	local ovlan = uci:get("network", "nrswitch", "ovlan")
	local mode = uci:get("auto_adapt", "mode", "en") or "0"

	if mode ~= "1" then
		uci:set("auto_adapt", "mode", "en","1")
		uci:delete("auto_adapt", "mode", "port")
		uci:commit("auto_adapt")

		if nixio.fs.access("/etc/config/mtkhnat") then
			os.execute("/etc/init.d/mtkhnat restart")
		end
		os.execute("/etc/init.d/auto_adapt restart")
	end

	if ovlan then
		uci:set("nrswitch", "nrswitch", "nvlan",ovlan)
		uci:commit("network")
	end

	os.execute("ACTION=reset sh /etc/hotplug.d/gmac/02_auto_adapt")

	uci:set("network", "wan", "proto", "dhcp")
	uci:set("network", "wan", "disabled", "0")
	uci:delete("network", "wan", "username")
	uci:delete("network", "wan", "password")
	uci:delete("network", "wan", "ipaddr")
	uci:delete("network", "wan", "netmask")
	uci:delete("network", "wan", "gateway")
	uci:delete("network", "wan", "dns")
	uci:commit("network")

	os.execute("killall auto_adapt")
	os.execute("killall -SIGUSR2 wanchk.sh")
	if fs.access("/tmp/autowan") then
		os.execute("rm /tmp/autowan")
	end
	if port ~= "nil" then
		cmd = "LUCI_DISPATCH=1 ACTION=linkup PORTNUM="..tonumber(port).." sh /etc/hotplug.d/gmac/02_auto_adapt"
	else
		cmd = "LUCI_DISPATCH=1 ACTION=linkup sh /etc/hotplug.d/gmac/02_auto_adapt"
	end
	os.execute(cmd)
end

function action_system_detcet()
	if nr.support_autoadapt() then
		action_detcet_for_adapt()
	else
		action_detcet_for_sniffer()
	end
end

local function get_detect_status()
	local nr = require "luci.nradio"
	local fs = require "nixio.fs"
	local value = "error"
	if fs.access("/tmp/autowan") then
		for l in io.lines("/tmp/autowan") do
			local v = l:match('(%w+)')
			value = v
		end
		if value and value ~= "error" and value ~= "detect" then
			uci:set("network", "wan", "proto", value)
			uci:commit("network")
		end
	end
	local result = {mode = value}
	return result
end

function action_detcet_status()
	nr.luci_call_result(get_detect_status())
end


local function get_wifi_ssid()
	local uci = luci.model.uci.cursor()
	local lan_section = uci:get("network", "globals", "default_lan") or "lan"
	local ssid_value = uci:get("cloudd", "t0", "ssid_wlan") or nil
	local key_value = uci:get("cloudd", "t0", "key_wlan") or 0
	local lanip_value = uci:get("network", lan_section, "ipaddr") or nil
	local password = uci:get("system", "@system[0]", "password") or nil

	ssid_value = string.sub(ssid_value, 2)
	key_value = string.sub(key_value, 2)

	local result = {ssid = ssid_value,key = key_value, lanip = lanip_value,pass = password}
	return result
end

function action_system_wifi()
	nr.luci_call_result(get_wifi_ssid())
end


function action_wifi_set()
	local sys  = require "luci.sys"
	local ssid = luci.http.formvalue("ssid") or nil
	local key = luci.http.formvalue("key") or nil
	local password = luci.http.formvalue("password") or nil
	uci:set("system", "@system[0]", "password", password)
	-- save temporarily, it will be deleted later
	uci:set("cloudd", "t0", "ssid_wlan", "X"..ssid)
	uci:set("cloudd", "t0", "key_wlan", "X"..key)
	uci:set("cloudd", "t0", "encryption_wlan", "Xpsk-mixed")
	uci:set("cloudd", "t0", "diff_2_4_wlan", "X0")
	uci:set("cloudd", "t0", "hidden_wlan", "X0")
	uci:set("cloudd", "t0", "disabled_wlan", "X0")

	local cl = require "luci.model.cloudd".init()
	local ca = require "cloudd.api"
	local id = ca.cloudd_get_self_id()
	local cdev = cl.get_device(id, "master")
	local slaves = cdev:slaves_sort()
	for i = 1, #slaves do
		local slave = slaves[i]
		local radio_cnt = slave:get_radiocnt()
		local radio_band2 = (radio_cnt.band2 or 1)
		local radio_band5 = (radio_cnt.band5 or 1)

		for j = 1, radio_band2 + radio_band5 do
			local index = j - 1
			local wlan
			local group = nil
			if radio_band2 ~= 0 then
				wlan = "wlan"..index
			else
				wlan = "wlan"..(index + 1)
			end

			uci:foreach("cloudd", "group",
						function(s)
							if s.device then
								for idx = 1, #s.device do
									if s.device[idx] == slave.sid then
										group = s[".name"].."wlan"
										return false
									end
								end
							end
						end
			)
			uci:delete("cloudd", group, "disabled_"..wlan)
			uci:delete("cloudd", group, "ssid_"..wlan)
			uci:delete("cloudd", group, "encryption_"..wlan)
			uci:delete("cloudd", group, "key_"..wlan)
			uci:delete("cloudd", group, "hidden_"..wlan)
			uci:delete("cloudd", group, "macfilter_"..wlan)
			uci:delete("cloudd", group, "acllist_"..wlan)
		end
	end
	uci:delete("cloudd", "config", "md5")

	sys.user.setpasswd("root", password)
	uci:commit("cloudd")
	uci:commit("system")
end

function action_end_set()
	local device = nil
	local ca = require "cloudd.api"
	device = action_system_next(true)

	if not device then
		local cld = require "luci.model.cloudd".init()

		local id = ca.cloudd_get_self_id()
		device = cld.get_device(id, "master")
	end

	nr.fork_exec(function()
		if nr.support_mesh() then
			ca.sync_wifi_config()
		end
		device:send_config()
	end)
end

function action_dhcp_set()
	uci:set("network", "wan", "proto", "dhcp")
	uci:set("network", "wan", "disabled", "0")
	uci:delete("network", "wan", "username")
	uci:delete("network", "wan", "password")
	uci:delete("network", "wan", "ipaddr")
	uci:delete("network", "wan", "netmask")
	uci:delete("network", "wan", "gateway")
	uci:delete("network", "wan", "dns")
	uci:commit("network")
	os.execute("ifup wan")
	trigger_network_check()
end


function action_pppoe_dial()
	os.execute("ifup wan")
	trigger_network_check()
end

function action_pppoe_set()
	local username = luci.http.formvalue("account")
	local password = luci.http.formvalue("password")

	uci:set("network", "wan", "proto", "pppoe")
	uci:set("network", "wan", "username", username)
	uci:set("network", "wan", "password", password)
	uci:set("network", "wan", "disabled", "0")
	uci:delete("network", "wan", "ipaddr")
	uci:delete("network", "wan", "netmask")
	uci:delete("network", "wan", "gateway")
	uci:delete("network", "wan", "dns")
	uci:commit("network")
	os.execute("ifup wan")
	trigger_network_check()
end

function action_static_set()
	local ipaddr = luci.http.formvalue("ip")
	local netmask = luci.http.formvalue("netmask")
	local gateway = luci.http.formvalue("gateway")
	local dns = luci.http.formvalue("dns")
	local dns1 = luci.http.formvalue("dns1")

	uci:set("network", "wan", "disabled", "0")
	uci:set("network", "wan", "proto", "static")
	uci:set("network", "wan", "ipaddr", ipaddr)
	uci:set("network", "wan", "netmask", netmask)
	uci:set("network", "wan", "gateway", gateway)
	uci:set("network", "wan", "dns", dns.." "..dns1)
	uci:delete("network", "wan", "username")
	uci:delete("network", "wan", "password")
	uci:commit("network")

	local mode = uci:get("auto_adapt", "mode", "en") or "0"
	if mode ~= "0" then
		uci:set("auto_adapt", "mode", "en","0")
		uci:commit("auto_adapt")

		if nixio.fs.access("/etc/config/mtkhnat") then
			os.execute("/etc/init.d/mtkhnat restart")
		end
		os.execute("/etc/init.d/auto_adapt restart")
	end

	os.execute("ifup wan")
	trigger_network_check()
end

function action_system_next(kick)
	local uci = luci.model.uci.cursor()
	local device = nil
	local old_first = uci:get("luci", "main", "first") or "1"

	if old_first == "1" then
		uci:set("luci", "main", "first", "0")
		uci:commit("luci")
		if nr.support_mesh() then
			local enabled = uci:get("mesh", "config", "enabled") or "0"
			local role = uci:get("mesh", "config", "role") or "1"

			if role ~= "0" then
				uci:set("mesh", "config", "role","0")
				uci:commit("mesh")
				os.execute("/etc/init.d/ledctrl restart")
			end
			device = nr.control_mesh_async(enabled,"0",kick)
			nr.fork_exec("mesh rt")
		end
	end
	os.execute("/etc/init.d/dnsmasq restart > /dev/null  2>&1")
	os.execute("/etc/init.d/wifidogx stop > /dev/null  2>&1")
	nr.luci_call_result("{'result':'OK'}")
	return device
end

function trigger_network_check()
	os.execute("killall -SIGUSR1 wanchk.sh")
end

-- Get system info
-- @return system info result
-- {
--   "result": {
--	 "mac": "FC:83:C6:00:42:E4",
--	 "version": "1.6.4"
--   }
-- }
function action_system_info()
	nr.luci_call_result(nr.system_info())
end
