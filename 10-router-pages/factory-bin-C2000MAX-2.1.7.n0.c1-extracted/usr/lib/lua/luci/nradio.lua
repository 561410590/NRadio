local sys  = require "luci.sys"
local uci  = require "luci.model.uci"
local tpl  = require "luci.template"
local lng  = require "luci.i18n"
local util = require "luci.util"
local http = require "luci.http"
local i18n = require "luci.i18n"
local disp = require "luci.dispatcher"
local nixio = require "nixio"
local cjson = require "cjson.safe"
local fs = require "nixio.fs"
local ip = require "luci.ip"
local stat = require "luci.tools.status"


local os,tonumber,ipairs,pairs,table,tostring,require,type,io,string,pcall = os,tonumber,ipairs,pairs,table,tostring,require,type,io,string,pcall
local sms_noresult=-1
local sms_error=-2
local sms_notsupport=-3
local sms_errorspace=-4
local cellular_prefix = nil
local cellular_default = nil
module "luci.nradio"

function get_phyname(iface)
	local cur = uci:cursor()
	local phyname = cur:get("wireless", iface, "phyname") or ""

	return phyname
end

function get_network_type()
	local net_type = {
		WiredCellularPriority="0",--include wired
		CellularOnly="1",
		CellularPriority1="2",
		CellularPriority2="3",
		WiredCellularPriority1="4",--include wired
		WiredCellularPriority2="5",--include wired
		WiredOnly="6",--include wired
		CellularOnly1="7",
		CellularOnly2="8",
		WiredCellularOverlap="9",--include wired
		WiredCellularDividing="10",--include wired
		NBCPEOnly="11",
		WiredNBCPEPriority="12",--include wired
		WiredNBCPECellularPriority="13",--include wired
		WiredNBCPECellularDividing="14",--include wired
		WiredNBCPEDividing="15",--include wired,
		WiredNBCPECellularOverlap="16",
		WiredNBCPEOverlap="17",
		NBCPECellularPriority="18",
		NBCPECellularDividing="19",
		NBCPECellularOverlap="20",
		WiredCellularNBCPEPriority="21",--include wired
		CellularNBCPEPriority="22"--include wired
	}
	return net_type
end

function macaddr(val)
    if val and val:match(
        "^[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+:" ..
        "[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+$"
    ) then
        local parts = util.split( val, ":" )

        for i = 1,6 do
            parts[i] = tonumber( parts[i], 16 )
            if parts[i] < 0 or parts[i] > 255 then
                return false
            end
        end

        return true
    end

    return false
end

function get_clients_info()
	local l_dhcp = stat.dhcp_leases()
	local clients = {}

	for i = 1, #l_dhcp do
		local info = l_dhcp[i]
		clients[info.macaddr:upper()] = { ipaddr = info.ipaddr, hostname = info.hostname }
	end

	return clients
end

function get_client_ip(mac,family)
	local rv = ""
	local neigh_cmd = ""

	if family == 4  then
		neigh_cmd = "ip -4  neigh show dev br-lan|grep "..mac:lower()
	elseif family == 6 then
		neigh_cmd = "ip -6  neigh show dev br-lan|grep "..mac:lower()
	end

	local fd = io.popen(neigh_cmd, "r")
	if fd then
		while true do
			local ln = fd:read("*l")
			if not ln then
				break
			else
				local ip,name,mac,statnud = ln:match("^(%S+) (%S+) (%S+) (%S+)")

				if mac and ip and name then
					--luci.nradio.syslog("err", "ip：ip"..ip..",mac:"..mac..",name:"..name)
					rv = ip
				end
			end
		end
		fd:close()
	end

	return rv
end

function list_wired_clients(item)
	local rv= util.ubus("infocd", "terminal",{type="wired"}) or { count = 0, client = {}}
	return rv
end

function filter_mesh_radio(ssid)
	local cur = uci.cursor()
	local nrmesh = cur:get("nrmesh", "mesh", "enable") or "0"
	local nrmesh_ssid = cur:get("nrmesh", "mesh", "ssid") or "@#!nRadiOMeSH!#@"

	local mesh = cur:get("mesh", "config", "enabled") or "0"
	local mesh_ssid = cur:get("mesh", "config", "ssid") or "Cyk3a1nyQ*ghh9Isrhs7^5CM75QC3BVR"

	if (nrmesh == "1" and nrmesh_ssid == ssid) then
		return true
	end
	if (mesh == "1" and mesh_ssid == ssid) then
		return true
	end
	return false
end


function check_itself_mac(local_link_data,mac,mesh_mac,mesh_macs)
	local target_port,local_device
	if mesh_macs and mesh_macs[mesh_mac].symbol == "local" then
		local_device = true
	end
	for key,item in pairs(local_link_data) do
		if (mesh_macs[item.mac]) then
			mesh_macs[item.mac].port = item.port
		end
		if (item.mac == mac) then
			target_port = item.port
		end
	end
	local found = false
	if target_port then
		for key,item in pairs(mesh_macs) do
			if local_device then
				if item.port and item.port == target_port then
					return true
				end
			else
				if item.port and item.port == target_port then
					return false
				end
			end
		end
		if local_device then
			return false
		else
			return true
		end
	end

	return false
end

-- List all radio clients
-- @return clients list result
-- {
--   "result": {
--	 "count": 1,
--	 "client": [
--	   {
--		 "rxbytes": "10000",
--		 "ssid": "Test333",
--		 "rssi": -34,
--		 "ip": "192.168.168.171",
--		 "txrate": "144000",
--		 "apname": "AP123",
--		 "name": "Test-Device",
--		 "channel": 157,
--		 "mac": "00:11:22:33:44:55",
--		 "txbytes": "211111",
--		 "rxrate": "24000",
--		 "assoctime": "0m"
--	   }
--	 ]
--   }
-- }

function list_radio_clients(devices_para,cld_para)
	local result= util.ubus("infocd", "terminal", {type = "wireless"}) or { }
	return result
end


function list_clients(local_only, devices_para, cld)
	local items= util.ubus("infocd", "terminal") or { }
	return  items
end

function neigh_caculate(local_only, devices_para, cld)
	return list_clients(local_only, devices_para, cld).count
end

function device_status_info(status)
	local status_info = {}

	status_info['0'] = lng.translate("Offline")
	status_info['1'] = lng.translate("Connecting")
	status_info['2'] = lng.translate("Connected")
	status_info['3'] = lng.translate("Pre-Upgrade")
	status_info['4'] = lng.translate("Upgrading")
	status_info['5'] = lng.translate("Upgrade Error")
	status_info['6'] = lng.translate("Rebooting")
	status_info['7'] = lng.translate("Resetting")

	return status_info[status] or status_info['0']
end

function guide_display()
	local cur = uci.cursor()
	local guide = cur:get("luci", "main", "guide")

	if guide and guide == "0" then
		return false
	end

	return sys.user.checkpasswd("root", "admin")
end

function authenticator(validator, accs, default, template)
	local user = http.formvalue("luci_username")
	local pass = http.formvalue("luci_password")
	local comf = http.formvalue("luci_comfirm")
	local hint = http.formvalue("luci_hint")

	if guide_display() then
		if user and pass and comf and (pass == comf) then
			if (password_init(user, pass, hint or "")) then
				return user
			end
		end
	else
		if user and validator(user, pass) then
			return user
		end
	end

	-- Clear path to avoid nav display
	disp.context.path = {}
	http.status(403, "Forbidden")
	tpl.render(template or "sysauth", {duser=default, fuser=user})

	return false
end

function password_init(user, pass, hint)
	local cur = uci.cursor()
	if sys.user.setpasswd(user, pass) ~= 0 then
		return false
	end
	cur:set("system", "@system[0]", "password", pass)
	cur:commit("system")
	cur:set("luci", "main", "hint", hint)
	cur:set("luci", "main", "guide", "0")
	cur:save("luci")
	cur:commit("luci")
	cur:unload("luci")
	return true
end
function format_ver(version,count)
	if not count then
		count = 4
	end
	if version and #version > 0 then
		local ver_info = util.split(version, ".")
		local  max = #ver_info
		if max >=4 then
			version = ""
			for i = 1, count do
				if ver_info[i] then
					if  #version > 0 then
						version = version.."."..ver_info[i]:match("%d")
					else
						version = ver_info[i]
					end
				end
			end
		end
	end
	return version
end
function system_info(simple)
	local plat = get_platform()
	local cur = uci.cursor()
	local sysinfo = util.ubus("system", "info") or { }
	local version_ori = util.exec("cat /etc/openwrt_version|xargs printf")
	local result = {
		mac = "",
		ver = "",
		upt = "",
	}
	local version = version_ori
	result.mac = cur:get("oem", "board", "id")
	result.upt = sysinfo.uptime
	result.model = cur:get("oem", "board", "pname") or cur:get("oem", "board", "name") or ""
	result.device_code = cur:get("oem", "board", "device_code") or ""
	if simple then
		if plat == "quectel" then
			version = format_ver(version,5)
		else
			version = format_ver(version)	
		end		
	end
	if not cur:get("oem", "custom", "com") then
		result.ver = "NROS-"
	end
	result.ver = result.ver .. version

	return result
end

function luci_call_result(content)
	http.prepare_content("application/json")

	http.write('{ "result": ')
	http.write_json(content)
	http.write(" }")
end

function auto_reboot_cmd(time, magic, dest)
	local delay_cmd = "date +%s|awk '{print \\\"@\\\" \\$1+70}'|xargs date -s"
	magic = magic or "&& touch /etc/banner && reboot # Auto reboot in"
	dest = dest or "/etc/crontabs/root"

	local sdel = "sed -i \"\\_" .. magic .. "_d\" " .. dest
	local sadd = "echo '' &>/dev/null"
	local sapp = "crontab " .. dest

	if time and #time > 0 then
		local arr = util.split(time, ':')
		sadd = "sed -i \"1i " .. arr[2] .. " " .. arr[1] .. " * * * "
			.. delay_cmd .. " " .. magic .. " " .. time .. "\" " .. dest
	end

	return sdel .. " && " .. sadd .. " && " .. sapp
end

function syslog(level, data)
	local cur = uci.cursor()
	local debug_tbl = {
		err		 = 0,
		warning	 = 1,
		info	 = 2,
		debug	 = 3,
	}

	local cloudd_log_tag = "nradio_luci"
	local debug_level = tonumber(cur:get("luci", "main", "debug") or 0)

	if debug_tbl[level] and debug_tbl[level] <= debug_level then
		nixio.openlog(cloudd_log_tag)
		nixio.syslog(level,data)
		nixio.closelog()
	end
end

function switch_card()
	local max = uci.cursor():get("cpesel", "sim", "max") or "0"
	if tonumber(max) > 1 then
		return true;
	end

	return false;
end

function has_ptype(...)
	local cur = uci.cursor()
	local ctype = cur:get("oem", "board", "ptype")

	for i, v in ipairs{...} do
	if ctype == v then
			return true
		end
	end

	return false
end

function has_wan_port()
	local cur = uci.cursor()
	local nvlan = cur:get("network", "nrswitch", "nvlan") or "L"
	local auto = tonumber(cur:get("auto_adapt", "mode", "en") or 0)

	if auto == 1 then
		return true
	end
	return nvlan:match("[WM]") ~= nil
end

function has_wan()
	local cur = uci.cursor()
	local nvlan = cur:get("network", "nrswitch", "nvlan") or "L"
	local auto = tonumber(cur:get("auto_adapt", "mode", "en") or 0)

	if auto == 1 then
		return true
	end

	return nvlan:match("W") ~= nil
end

function support_ipv6()
	local network = require "luci.model.network"
	if network:has_ipv6() then
		return true
	end
	return false
end


function support_ipv6_relay()
	local cur = uci.cursor()
	local ipv6_relay = cur:get("luci", "main", "ipv6_relay") or "0"
	if support_ipv6() and ipv6_relay == "1" then
		return true
	end
	return false
end

function support_ipv6_nat()
	local cur = uci.cursor()
	local ipv6_nat_disabled = cur:get("luci", "main", "ipv6_nat_disabled") or "0"
	if ipv6_nat_disabled == "1" then
		return false
	end
	return true
end

function support_ipv6_relay_local()
	local cur = uci.cursor()
	local ipv6_local = cur:get("luci", "main", "ipv6_local") or "0"
	if ipv6_local == "1" then
		return true
	end
	return false
end

function support_wan_ipv6()
	local support_ipv6_f = support_ipv6()
	local wan_mode = has_wan()
	if wan_mode and support_ipv6_f then
		return true
	end
	return false
end

function support_vsim(name)
	local cur = uci.cursor()

	if not name or #name == 0 then
		return false
	end
	local vsim = cur:get("network",name, "vsim") or ""
	if vsim and vsim == "1" then
		return true
	else
		return false
	end
end

function has_phy()
	local cur = uci.cursor()
	local nvlan = cur:get("network", "nrswitch", "nvlan") or "L"

	return nvlan:match("E") ~= nil
end

function has_wlan(id)
	local cur = uci.cursor()
	local count = 0
	local dx
	if get_platform() == "tdtech" then
		return true
	end
	if id then
		cur:foreach("cloudd", "device",
					function(s)
						if s.id == id then
							dx = s[".name"]
							return false
						end
					end
		)

		if not dx then
			return false
		end
	end

	cur:foreach("cloudd", "cboard",
				  function(s)
					  if id and dx then
						  if s[".name"]:match(dx.."cboard") then
							  count = count + s.r2cnt + s.r5cnt
						  end
					  else
						  count = count + s.r2cnt + s.r5cnt
					  end
				  end
	)

	return count ~= 0
end

function has_own_wlan(local_only)
	local cur = uci.cursor()
	local id = cur:get("oem", "board", "id")

	if not id then
		return false
	end

	id = id:gsub(":", "")

	if local_only then
		if fs.access("/etc/config/wireless") then
			return true
		end
		return false
	end

	return has_wlan(id)
end

function has_cpe()
	return count_cpe() > 0
end

function count_cpe()
	local cur = uci.cursor()
	return tonumber(cur:get("oem", "feature", "cpe") or "0")
end

function has_nat()
	return has_cpe() or has_wan()
end

function get_build()
	local build_year = util.exec("grep -oE '[0-9]+$' /proc/version") or "2020"

	return build_year
end

function get_firmware_type()
	local cur = uci.cursor()
	local oem_name = cur:get("oem", "custom", "com")
	if oem_name and #oem_name then
		if oem_name ~= " " then
			return "odm"
		else
			return "oem"
		end
	end
	return "stand"
end

function get_company_info()
	local result = {name="",owe="",wb="",wchat=false}
	local cur = uci.cursor()
	local company_info = cur:get_all("oem", "custom") or {}
	local oem_name = company_info["com"] or ""
	local country = cur:get("oem", "board", "country") or "CN"
	if oem_name and (#oem_name > 0) then
		if oem_name ~= " " then
			result.name = company_info["name"] or ""
			result.owe = company_info["owe"] or ""
			result.wb = company_info["wb"] or ""
			if company_info["wchat"] and (#company_info["wchat"] > 0) then
				result.wchat = true
			else
				result.wchat = false
			end
		end
	else
		if #country > 0  and country ~= "CN" then
			result.name = lng.translate('NRadio')
			result.owe = "https://www.nradiowifi.net/"
		else
			result.name = lng.translate('NRadio')
			result.owe = "https://nradiowifi.com/"
			result.wb = "https://weibo.com/6351961397"
			result.wchat = true
		end
	end

	return result
end

function get_platform()
	if fs.access("/usr/sbin/atcmd") then
		return "tdtech"
	elseif fs.access("/bin/serial_atcmd") or fs.access("/usr/bin/qlnet") then
		return "quectel"
	else
		local board = util.ubus("system", "board") or {board_name = ""}

		if board.board_name:match("HCMT") then
			return "mtk"
		else
			return "qca"
		end
	end
end

function has_wan_page()
	if not has_ptype("ap", "cpe") then
		if has_wan() or has_cpe() then
			return true
		end
	end
	return false
end

function get_net_status(ifaces)
	local rv = {}

	for iface in ifaces:gmatch("[%w%.%-_]+") do
		local status = {}
		local netinfo = util.ubus("network.interface." .. iface, "status") or { }
		local main_iface = iface:gsub("_%d+", "")
		local wanchk = util.ubus("wanchk", "get", {name = main_iface}) or {}

		status.id = iface
		status.is_up = netinfo.up or false
		if wanchk[main_iface] and wanchk[main_iface] == "down" then
			status.is_up = false
		end
		status.proto = netinfo.proto or "none"
		status.uptime = netinfo.uptime or -1
		status.device = netinfo.l3_device or netinfo.device

		if status.uptime > 0 then
			status.ipaddrs = {}
			status.netmask = {}
			for idx, ite in pairs(netinfo["ipv4-address"] or {}) do
				status.ipaddrs[idx] = ite.address .. "/" .. ite.mask
				status.netmask[idx] = tostring(ip.new(status.ipaddrs[idx]):mask())
			end
			status.dnsaddrs = netinfo["dns-server"] or {}
			if netinfo.route then
				for i = 1, #netinfo.route do
					if netinfo.route[i].nexthop ~= "0.0.0.0" then
						status.gwaddr = netinfo.route[i].nexthop
						break
					end
				end
			else
				status.gwaddr = ""
			end
		end

		rv[#rv+1] = status
	end

	return rv
end

function get_wifi_info()
	local cur = uci.cursor()
	local id = cur:get("oem", "board", "id"):gsub(":", "")
	local dx
	local result = {r2cnt = 0, r5cnt = 0, wifi = {}}
	local gwlan, gradio, tpls

	cur:foreach("cloudd", "device",
				function(s)
					if s.id == id then
						dx = s[".name"]
						return false
					end
				end
	)

	if not dx then
		return result
	end

	cur:foreach("cloudd", "cboard",
				function(s)
					if s[".name"]:match(dx.."cboard") then
						local cboard = {
							r2cnt = tonumber(s.r2cnt or 1),
							r5cnt = tonumber(s.r5cnt or 1),
							id = s.id,
							pos = tonumber(s.pos),
							radio = {}
						}
						result.r2cnt = result.r2cnt + cboard.r2cnt
						result.r5cnt = result.r5cnt + cboard.r5cnt
						result.wifi[#result.wifi + 1] = cboard
					end
				end
	)

	table.sort(result.wifi, function(a, b) return a.pos < b.pos end)

	if #result.wifi == 0 then
		return result
	end

	tpls = cur:get("cloudd", "g"..(result.wifi[1].pos+2), "template") or {"t0", "t0"}

	for i = 1, #result.wifi do
		local wifi = result.wifi[i]
		gradio = cur:get_all("cloudd", "g"..(wifi.pos+2).."radio")
		gwlan = cur:get_all("cloudd", "g"..(wifi.pos+2).."wlan")

		for j = 1, wifi.r2cnt + wifi.r5cnt do
			local index = wifi.r2cnt ~= 0 and j-1 or j
			local keyword = "wlan"..index
			local radio = {
				channel = "auto",
				width = "HT20",
				txpower = "100",
				ssid = "",
				encryption = "none",
				key =  "",
				disabled = 1,
				section = "wlan"..index
			}
			local tpl = cur:get_all("cloudd", tpls[j] or "t0")

			if gwlan then
				if gwlan["ssid_"..keyword] then
					radio.ssid = gwlan["ssid_"..keyword]:match("%C+=(%C+)")
				elseif tpl["ssid_wlan"] then
					radio.ssid = tpl["ssid_wlan"]:gsub("^X", "")
					if index == 0 and tpl["diff_2_4_wlan"] and tpl["diff_2_4_wlan"] == "X1" then
						if tpl["diff_2_4_ssid_wlan"] then
							radio.ssid = tpl["diff_2_4_ssid_wlan"]:gsub("^X", "")
						else
							radio.ssid = radio.ssid.."-2.4G"
						end
					end
				end

				if gwlan["encryption_"..keyword] then
					radio.encryption = gwlan["encryption_"..keyword]:match("%C+=(%C+)")
				elseif tpl["encryption_wlan"] then
					radio.encryption = tpl["encryption_wlan"]:gsub("^X", "")
				end

				if radio.encryption and #radio.encryption and radio.encryption ~="none" then
					if gwlan["key_"..keyword] then
						radio.key = gwlan["key_"..keyword]:match("%C+=(%C+)")
					elseif tpl["key_wlan"] then
						radio.key = tpl["key_wlan"]:gsub("^X", "")
					end
				end

				if gwlan["disabled_"..keyword] then
					radio.disabled = gwlan["disabled_"..keyword]:match("%C+=(%C+)")
				elseif tpl["disabled_wlan"] then
					radio.disabled = tpl["disabled_wlan"]:gsub("^X", "")
				end
			end
			keyword = "radio"..index
			if gradio then
				if gradio["channel_"..keyword] then
					radio.channel = gradio["channel_"..keyword]:match("%C+=(%C+)") or "auto"
				end
				if gradio["htmode_"..keyword] then
					radio.width = gradio["htmode_"..keyword]:match("%C+=(%C+)")
				end
				if gradio["txpower_"..keyword] then
					radio.txpower = tonumber(gradio["txpower_"..keyword]:match("%C+=(%C+)"))
					if radio.txpower >= 80 and radio.txpower < 100 then
						radio.txpower = 80
					elseif radio.txpower < 80 then
						radio.txpower = 50
					end
				end
				if gradio["disall_"..keyword] then
					radio.disabled = gradio["disall_"..keyword]:match("%C+=(%C+)")
				end
				if gradio["band_"..keyword] then
					radio.band = gradio["band_"..keyword]:match("%C+=(%C+)") or "5g"
				end
			end
			wifi.radio[#wifi.radio + 1] = radio
		end
	end

	return result
end

function set_client_name(mac, name)
	local section
	local cur = uci.cursor()

	if not mac then
		return
	end

	mac = mac:upper()

	cur:foreach("cloudd_cli", "client",
				function(s)
					if s.mac and s.mac == mac then
						section = s[".name"]
						return false
					end
				end
	)

	if section then
		if name and name ~= "" then
			cur:set("cloudd_cli", section, "name", name)
		else
			cur:delete("cloudd_cli", section)
		end

		cur:commit("cloudd_cli")
	else
		if name then
			section = cur:add("cloudd_cli", "client")
			if section then
				cur:set("cloudd_cli", section, "name", name)
				cur:set("cloudd_cli", section, "mac", mac)
				cur:commit("cloudd_cli")
			end
		end
	end
end

function fork_exec(command)
	local pid = nixio.fork()
	if pid > 0 then
		return
	elseif pid == 0 then
		-- change to root dir
		nixio.chdir("/")

		-- patch stdin, out, err to /dev/null
		local null = nixio.open("/dev/null", "w+")
		if null then
			nixio.dup(null, nixio.stderr)
			nixio.dup(null, nixio.stdout)
			nixio.dup(null, nixio.stdin)
			if null:fileno() > 2 then
				null:close()
			end
		end
		if type(command) == "function" then
			command()
		else
			-- replace with target command
			nixio.exec("/bin/sh", "-c", command)
		end
		nixio.exec("/bin/echo", "done")
	end
end

function apply_guest()
	local capi = require "cloudd.api"
	local cur = uci:cursor()
	local id = cur:get("oem", "board", "id"):gsub(":", "")
	local dx
	local guest = cur:get_all("guest", "config") or {}
	local cboards = {}
	local bands = {}
	local lan_section = cur:get("network", "globals", "default_lan") or "lan"
	local ipaddr = cur:get("network", lan_section, "ipaddr")
	local mask = cur:get("network", lan_section, "netmask")

	if not has_ptype("rt") then
		syslog("err", "Device is not in RT mode, skip guest apply")
		return
	end

	cur:foreach("cloudd", "device",
				function(s)
					if s.id == id then
						dx = s[".name"]
						return false
					end
				end
	)

	if not dx then
		return
	end

	cur:foreach("cloudd", "cboard",
				function(s)
					if s[".name"]:match(dx.."cboard") then
						local cboard = {
							r2cnt = tonumber(s.r2cnt or 1),
							r5cnt = tonumber(s.r5cnt or 1),
							id = s.id,
							pos = tonumber(s.pos)
						}
						cboards[#cboards + 1] = cboard
					end
				end
	)

	table.sort(cboards, function(c1, c2) return c1.pos < c2.pos end)
	if #cboards == 0 then
		return
	end

	if guest["bands"] then
		local bandlist = util.split(guest["bands"], " ")
		for i = 1, #bandlist do
			bands[bandlist[i]] = 1
		end
	end

	for i = 1, #cboards do
		local cboard = cboards[i]
		for j = 1, cboard.r2cnt + cboard.r5cnt do
			local group = "g"..(cboard.pos+2).."wlan"
			local index = cboard.r2cnt ~= 0 and j - 1 or j
			local cfgname = "wlan"..index.."_0"
			if bands[group..index] and guest.enable and guest.enable == "1" then
				cur:set("cloudd", group, "disabled_"..cfgname, "wireless."..cfgname..".disabled=0")
				cur:set("cloudd", group, "ssid_"..cfgname, "wireless."..cfgname..".ssid="..(guest["ssid"] or ""))
				cur:set("cloudd", group, "encryption_"..cfgname, "wireless."..cfgname..".encryption="..(guest["encryption"] or ""))
				cur:set("cloudd", group, "key_"..cfgname, "wireless."..cfgname..".key="..(guest["key"] or ""))
				cur:set("cloudd", group, "isolate_"..cfgname, "wireless."..cfgname..".isolate=1")
				if guest["isolation"] and guest["isolation"] == "1" then
					cur:set("cloudd", group, "guest_"..cfgname, "wireless."..cfgname..".guest=1")
					cur:set("cloudd", group, "hostip_"..cfgname, "wireless."..cfgname..".hostip="..ipaddr.."/"..mask)
				else
					cur:set("cloudd", group, "guest_"..cfgname, "wireless."..cfgname..".guest=")
					cur:set("cloudd", group, "hostip_"..cfgname, "wireless."..cfgname..".hostip=")
				end
			else
				cur:delete("cloudd", group, "disabled_"..cfgname)
				cur:delete("cloudd", group, "ssid_"..cfgname)
				cur:delete("cloudd", group, "encryption_"..cfgname)
				cur:delete("cloudd", group, "key_"..cfgname)
				cur:set("cloudd", group, "guest_"..cfgname, "wireless."..cfgname..".guest=")
				cur:set("cloudd", group, "hostip_"..cfgname, "wireless."..cfgname..".hostip=")
			end
		end
	end
	cur:commit("cloudd")

	capi.cloudd_send_config(id)
	if support_mesh() then
		capi.sync_wifi_config()
	end
	return
end


function support_feature(feature)
	local cur = uci:cursor()
	local val = cur:get("oem", "feature", feature) or '0'

	return val == '1'
end

function support_nr(net,file)
	local cur = uci:cursor()
	local filename = "network"
	if file then
		filename = file
	end
	local val = cur:get(filename, net, "nrcap") or '0'

	if tonumber(val) == 1 then
		return true
	end

	return false
end

function support_lock_freq(net)
	local cur = uci:cursor()
	local val = cur:get("network", net, "freq_val") or ''

	if #val > 0 then
		return true
	end

	return false
end

function support_nrmesh()
	local iwinfo
	local iw
	local phyname = get_phyname("radio0")

	if phyname and (phyname == "mt7620" or phyname == "mt7628") then
		return true
	end

	return false
end

function support_ac()
	if has_ptype("ac") then
		return true
	end
	return false
end

function support_mesh()
	local cur = uci.cursor()
	local apcli_en = cur:get("wireless", "apcli", "disabled") or "1"
	local forbid = cur:get("oem", "forbidden", "mesh") or "0"

	if apcli_en ~= "1" then
		return false
	end

	if forbid == "1" then
		return false
	end

	if not fs.access("/etc/config/mesh") then
		return false
	end

	if not has_own_wlan() then
		return false
	end

	if (has_ptype("rt") and (not has_cpe())) then
		return true
	end

	return false
end

function support_ppsk()
	if not fs.access("/etc/config/ppsk") then
		return false
	end

	return true
end

function support_autoadapt()
	local cur = uci.cursor()
	local forbid = cur:get("oem", "forbidden", "auto_adapt") or "0"

	if forbid == "1" then
		return false
	end

	if not fs.access("/etc/config/auto_adapt") then
		return false
	end

	return true
end

function support_sae()
	local iwinfo
	local iw
	local phyname = get_phyname("radio0")

	if phyname and (phyname == "mt7915" or phyname == "mt7981" or phyname == "mt7993") then
		return true
	end

	if get_platform() == "tdtech" then
		return true
	end

	return false
end

function support_vht160()
	local iwinfo
	local iw
	local phyname = get_phyname("radio0")

	if phyname and (phyname == "mt7981" or phyname == "mt7993") then
		return true
	end

	return false
end

function support_eht()
	local iwinfo
	local iw
	local phyname = get_phyname("radio0")

	if phyname and (phyname == "mt7993" or phyname == "mt7992" ) then
		return true
	end

	return false
end

function support_agreement()
	local cur = uci.cursor()
	local agreement = cur:get("luci", "main", "agreement") or ""
	if agreement == "1" then
		return true
	end
	return false
end

function read_model_attr(model,attr)
	local model_file="/etc/freq.json"
	if fs.access(model_file) then
		local model_data = fs.readfile(model_file)
		local model_json =  cjson.decode(model_data)
		if model_json and model_json[model] and model_json[model][attr] then
			if model_json[model][attr] == "1" then
				return true
			end
		end
	end
	return false
end

function support_cellular_mode(rule_name)
	local cur = uci.cursor()
	local cellular_mode = cur:get("luci", "main", "dis_cellular_mode") or ""
	if cellular_mode == "1" then
		return false
	end

	if  rule_name and #rule_name > 0 then
		local cellular_model = cur:get("cellular_init",rule_name,"model") or ""
		if read_model_attr(cellular_model,"dis_mode") then
			return false
		end
	end

	return true
end

function support_cellular_roam(rule_name)
	local cur = uci.cursor()
	local cellular_mode = cur:get("luci", "main", "dis_cellular_roam") or ""
	if cellular_mode == "1" then
		return false
	end

	if  rule_name and #rule_name > 0 then
		local cellular_model = cur:get("cellular_init",rule_name,"model") or ""
		if read_model_attr(cellular_model,"dis_roam") then
			return false
		end
	end

	return true
end

function support_cellular_ippass(rule_name)
	local cur = uci.cursor()

	if  rule_name and #rule_name > 0 then
		local ippass = cur:get("network",rule_name,"ippass") or "0"
		local phycap = cur:get("network",rule_name,"phycap") or "0"
		if ippass == "1" and tonumber(phycap) >= 1000 then
			return true
		end
	end

	return false
end

function support_cellular_nrrc(rule_name)
	local cur = uci.cursor()

	if  rule_name and #rule_name > 0 then
		local nrrc = cur:get("network",rule_name,"nrrc") or "0"
		if nrrc == "1" then
			return true
		end
	end

	return false
end

function support_cpecfg_single(rule_name)
	local cur = uci.cursor()
	local cpecfg_single = cur:get("luci", "main", "cpecfg_single") or ""
	if cpecfg_single == "1" then
		return true
	end

	if  rule_name and #rule_name > 0 then
		local cpecfg_single = cur:get("cellular_init",rule_name,"model") or ""
		if read_model_attr(cpecfg_single,"cpecfg_single") then
			return true
		end
	end

	return false
end

function support_cpecfg_pdp(rule_name)
	local cur = uci.cursor()
	local cpecfg_pdp = cur:get("luci", "main", "cpecfg_nopdp") or ""
	if cpecfg_pdp == "1" then
		return false
	end

	if  rule_name and #rule_name > 0 then
		local cpecfg_pdp = cur:get("cellular_init",rule_name,"model") or ""
		if read_model_attr(cpecfg_pdp,"cpecfg_nopdp") then
			return false
		end
	end

	return true
end

function support_compatible_nr(rule_name)
	local cur = uci.cursor()
	local cpecfg_compatible_nr = cur:get("luci", "main", "cpecfg_compatible_nr") or ""
	if cpecfg_compatible_nr == "1" then
		return true
	end

	return false
end

function support_fallbackToR16(rule_name)
	local cur = uci.cursor()
	local cpecfg_fallbackToR16 = cur:get("luci", "main", "cpecfg_fallbackToR16") or ""
	if cpecfg_fallbackToR16 == "1" then
		return true
	end

	return false
end

function support_fallbackToLTE(rule_name)
	local cur = uci.cursor()
	local cpecfg_fallbackToLTE = cur:get("luci", "main", "cpecfg_fallbackToLTE") or ""
	if cpecfg_fallbackToLTE == "1" then
		return true
	end

	return false
end


function support_cellular_scan(rule_name)
	local cur = uci.cursor()
	local cellular_scan = cur:get("luci", "main", "dis_cellular_scan") or ""
	if cellular_scan == "1" then
		return false
	end

	if  rule_name and #rule_name > 0 then
		local cellular_model = cur:get("cellular_init",rule_name,"model") or ""
		if read_model_attr(cellular_model,"dis_scan") then
			return false
		end
	end

	local count_cpe = count_cpe()
	local exsit_support=0
	local vsim_active_support=0
	for i = 0, count_cpe - 1 do
		local iface = (i == 0 and cellular_default or cellular_prefix..i)
		local sim_rule = (i == 0 and "sim" or "sim"..i)
		local cellular_model = cur:get("cellular_init",iface,"model") or ""
		local cellular_disabled = cur:get("network",iface,"disabled") or ""
		local vsim_active = cur:get("cpesel",sim_rule,"vsim") or ""
		if not read_model_attr(cellular_model,"dis_scan") then
			exsit_support=1
		end
		if vsim_active == "1" and cellular_disabled ~= "1" then
			vsim_active_support = 1
		end
	end

	if exsit_support == 1 and vsim_active_support == 0 then
		return true
	else
		return false
	end
end
function check_memory()
	local sysinfo = util.ubus("system", "info") or { }
	local meminfo = sysinfo.memory or {
			total = 0,
			free = 0,
			buffered = 0,
			shared = 0
	}
	local free_left = meminfo.total/(1024*1204)

	if free_left < 256 then
		return false
	end
	return true
end
function modem_local_upgrade()
	local cur = uci.cursor()
	local model = cur:get("cellular_init", cellular_default, "model") or ""
	local model_support = false
	local package_support = false
	if model == "EC200A" or model == "EC200T" then
		model_support = true
		package_support = true
	elseif model:match("RM500U") then
		model_support = true
		if fs.access("/usr/bin/QDloader") and check_memory() then
			package_support = true
		end
	elseif model:match("MT5700M") then
		model_support = true
		if fs.access("/usr/bin/UpdateWizard_MT5700") then
			package_support = true
		end
	elseif model:match("RM520N") or model:match("EC25") then
		model_support = true
		if fs.access("/usr/bin/QFirehose") then
			package_support = true
		end
	elseif model:match("NU313") then
		model_support = true
		if fs.access("/usr/bin/MeigUpgradeToolU_Linux") then
			package_support = true
		end
	end
	if package_support and model_support then
		return true
	else
		return false
	end
end
function modem_ftp_check()
	if fs.access("/usr/bin/curlftpfs") then
		return true
	elseif fs.access("/tmp/rootfs/curlftp_related/usr/bin/curlftpfs") then
		return true
	end
	return false
end
function genarate_plmn_company(old_isp)
	if not old_isp or (#old_isp == 0) then
		return
	end
	local plmn = util.exec("jsonfilter -e '@[@.plmn[@=\""..old_isp.."\"]]' </usr/lib/lua/luci/plmn.json")
	if plmn and #plmn > 0 then
		local info = cjson.decode(plmn) or {}
		local plmn_company = info["company"] or ""
		if plmn_company then
			old_isp = lng.translate(plmn_company)
		end
	end
	return old_isp
end

local function get_wifi_status()
	local wifi_info = get_wifi_info()
	local radio1 = {disabled=1}
	local radio2 = {disabled=1}
	if wifi_info.r2cnt >= 1 then
		local wifi = wifi_info.wifi[1]
		local radio = {};

		radio1 = wifi.radio[1]
		radio2 = wifi.radio[2]
		if radio2 == nil then
			radio2 = radio1
		end
	end
	return radio1.disabled,radio2.disabled
end


local function get_clients_history(cld)
	local cnt2 = 0
	local cnt5 = 0
	local keys = {}
	if not fs.access("/usr/bin/redis-cli") then
		return cnt2, cnt5
	end

	if not redis_cli then
		redis_cli = cld.connect_redis()
		if not redis_cli then
			return cnt2, cnt5
		end
	end

	keys = redis_cli:keys('station:2g:*')
	cnt2 = keys and #keys or 0

	keys = redis_cli:keys('station:5g:*')
	cnt5 = keys and #keys or 0

	return cnt2, cnt5
end

local function genarate_signal(original_sig)
	local min = -100
	local max = -1
	local enlarge_signal = 0
	local target_sig = min

	if (not original_sig) or (#original_sig == 0) then
		return target_sig
	end

	if original_sig == "NA" or original_sig == "0" then
		target_sig = min
	else
		local sig_num = tonumber(original_sig)
		if sig_num > 0 then
			target_sig = max
		elseif sig_num == 0 then
			target_sig = min
		elseif sig_num < -50 then
			target_sig = sig_num + enlarge_signal
		else
			target_sig = sig_num
		end
	end
	return target_sig
end

function genarate_topology_data()
	local json = require "luci.jsonc"
	local topology_file = "/tmp/dump.txt"
	local link_table = {}

	util.exec("mapd_cli /tmp/mapd_ctrl dump_topology_v1 ")
	local parse = json.parse(fs.readfile(topology_file) or "")  or {}
	if parse["topology information"] then
		local item_list = parse["topology information"]  or {}
		for i,v in pairs(item_list) do
			local link_one = v["backhaul link metrics"]  or {}
			local node_role = v["Device role"]
			local node_mac = v["AL MAC"]:lower()
			local item_link_info = v["BH Info"]
			local device_info ={src="",role="",link={}}
			device_info.src = node_mac
			device_info.role = node_role

			if item_link_info and (#item_link_info > 0) then
				for j,vl in pairs(item_link_info) do
					local link_info = {}
					local type_tmp = vl["Backhaul Medium Type"]
					local link_dest = vl["neighbor almac addr"]:lower()
					local neighbor_rssi =  vl["RSSI"]:lower()
					link_info.dest = link_dest

					if type_tmp == "Ethernet" then
						link_info.type = "wired"
					else
						link_info.type = "wireless"
						link_info.signal  = genarate_signal(neighbor_rssi)
						link_info.symbol = type_tmp

					end
					device_info.link[link_dest] = link_info
					break
				end
			else
				for j,vl in pairs(link_one) do
					local metrics = vl["metrics"]
					local link_dest = vl["neighbor_al"]:lower()
				end

				local link_radio_info =  v["Radio Info"]  or {}
				for j,vl in pairs(link_radio_info) do
					local bssinfo =  vl["BSSINFO"] or {}

					for m,vb in pairs(bssinfo) do
						if filter_mesh_radio(vb["SSID"]) then
							if vb["connected sta info"] then
								for l,vr in pairs(vb["connected sta info"]) do
									local link_tdest = vr["STA MAC address"]:lower()
									if link_tdest  then
										local link_info = {}
										local link_symbol = vr["Medium"]
										local link_signal = vr["uplink rssi"]
										link_info.type = "wireless"
										link_info.signal = genarate_signal(link_signal)
										link_info.symbol = link_symbol
										link_info.dest = link_tdest
										link_info.ori_src = node_mac
										device_info.link[link_tdest] = link_info
									end
								end
							end
						end
					end
				end
			end
			link_table[#link_table + 1] = device_info
		end
	end
	return link_table
end

function get_runtime_info(ifaces)
	local result = util.ubus("infocd", "runtime") or { }
	if result.cpe then
		for _,v in ipairs(result.cpe) do
			if v.isp and #v.isp > 0 then
				v.isp = genarate_plmn_company(v.isp)
			end
			if v.imsi and #v.imsi > 0 then
				v.sim_isp = genarate_plmn_company(v.imsi:sub(1,5))
			end
		end
	end
	return result
end

function get_speed_info(ifaces)
	local result = util.ubus("infocd", "speed_record",{name=ifaces}) or { }
	return result
end

function control_mesh_core(enabled,role,device)
	local role_nrvalue = "1"
	local disabled_value = "1"
	local cur = uci.cursor()

	if role == "1" then
		role_nrvalue = "2"
	else
		disabled_value = "0"
	end

	if enabled ~= "1" then
		role_nrvalue = "0"
		disabled_value = "1"
	end

	if device then
		local group = device:group()
		local dname= device:dname()
		local rcnt = {1, 1}
		local rcnt_start = 0
		local rcnt_end = 0
		local htmode

		rcnt[1] = tonumber(cur:get("cloudd", dname, "r2cnt") or 1)
		rcnt[2] = tonumber(cur:get("cloudd", dname, "r5cnt") or 1)

		-- if no 2.4G, start from 1
		if rcnt[1] == 0 then
			rcnt_start = 1
			rcnt_end = rcnt[2] + 1
		else
			rcnt_end = rcnt[1] + rcnt[2]
		end

		for i = rcnt_start, rcnt_end do
			cur:set("cloudd", group.."radio", "nrctrl_mode_radio"..i, "wireless.radio"..i..".nrctrl_mode="..role_nrvalue)
			cur:set("cloudd", group.."wlan", "nrdev_wlan"..i, "wireless.wlan"..i..".nrdev="..role_nrvalue)
			if role == "0" then
				cur:set("cloudd", group.."wlan", "disabled_wlan"..i.."_2", "wireless.wlan"..i.."_2.disabled="..disabled_value)
			end
			htmode = cur:get("cloudd", group.."radio", "htmode_radio"..i)
			if htmode then
				cur:set("cloudd", "g0radio", "htmode_radio"..i, htmode)
			end
		end
		cur:commit("cloudd")
	end
end

function control_mesh_sync(enabled,role,device)
	if device then
		control_mesh_core(enabled,role,device)
		device:send_config()
	end
end

function control_mesh_async(enabled,role,kick)
	local cld = require "luci.model.cloudd".init()
	local capi = require "cloudd.api"
	local sid = capi.cloudd_get_self_id() or nil
	local device = cld.get_device(sid, "master")

	if sid and device then
		control_mesh_core(enabled,role,device)
		if not kick then
			fork_exec(function()
				device:send_config()
			end)
		end
	end

	return device
end

function get_local_device()
	local device_info = util.ubus("network.device","status") or { }
	local devices = {}
	if #device_info then
		for key,if_item in pairs(device_info) do
			if if_item.macaddr then
				local device = {}
				device.name = key
				devices[(if_item.macaddr):upper()] = device
			end
		end
	end
	return devices
end

function app_response(data)
	local data_result = data or "{}"
	local json = require "luci.jsonc"
	http.prepare_content("application/json")
	http.header("Access-Control-Allow-Origin","*")
	http.header("Access-Control-Allow-Credentials","true")
	http.header("Access-Control-Allow-Headers","Origin,X-Requested-With,Content-Type")
	http.header("Access-Control-Allow-Methods","POST,GET,OPTIONS,PUT")

	local data_result = json.stringify(data_result)
	data_result=data_result:gsub("\\","")
	http.write(data_result)
end

function app_decrypto()
	local math = require "math"
	local os = require "os"
	local input_data = http.content() or nil
	local real_data={}
	local cur = uci.cursor()
	local app_encrypt_disabled = cur:get("system", "basic", "app_encrypt_disabled")
	if input_data and #input_data > 0 then
		local data_json = cjson.decode(input_data)
		if app_encrypt_disabled and app_encrypt_disabled == "1" then
			return data_json
		end
		if data_json and type(data_json) == "table" and data_json.data then
			--nixio.syslog("err","app_decrypto data:"..data_json.data)
			fs.writefile("/tmp/app_decrypto_log",data_json.data)
			local decrypt_data=""
			if #data_json.data < 128 then
				decrypt_data = util.exec("nradio_crypto -d -s "..data_json.data)
			else
				local count = 1000
				math.randomseed(os.time())
				local index = math.random(count)
				local file_name="/tmp/decrypto"..index

				fs.writefile(file_name,data_json.data)
				decrypt_data = util.exec("nradio_crypto -d -f "..file_name..";rm -f "..file_name)
			end

			if decrypt_data then
				--nixio.syslog("err","app_decrypto result:"..decrypt_data)
				real_data = cjson.decode(decrypt_data) or {};
				decrypt_data=decrypt_data:gsub("\"","\\\"")
				fs.writefile("/tmp/app_decrypto_log",decrypt_data)
			end
		end
	end
	return real_data
end

function app_encrypto(data)
	--nixio.syslog("err","app_encrypto data:"..data)
	local cur = uci.cursor()
	local app_encrypt_disabled = cur:get("system", "basic", "app_encrypt_disabled")

	local math = require "math"
	local os = require "os"
	local result = {data=""}
	local encrypt_data=""
	if app_encrypt_disabled and app_encrypt_disabled == "1" then
		return cjson.decode(data)
	end

	if data and #data > 0 then
		fs.writefile("/tmp/app_encrypto_log",data)
		if #data < 128 then
			data=data:gsub("\"","\\\"")
			encrypt_data = util.exec("nradio_crypto -e -s "..data)
		else
			local count = 1000
			math.randomseed(os.time())
			local index = math.random(count)
			local file_name="/tmp/encrypto"..index
			fs.writefile(file_name,data)
			--util.exec("echo -n \""..data.."\" > "..file_name)
			encrypt_data = util.exec("nradio_crypto -e -f "..file_name..";rm -f "..file_name)
		end
		if encrypt_data then
			result.data = encrypt_data
			--nixio.syslog("err","app_encrypto result:"..encrypt_data)
			fs.writefile("/tmp/app_encrypto_log",encrypt_data)
		end
	end

	return result
end

function app_auth_failed()
	app_response(app_encrypto("{\"code\":\"1\"}"))
	return
end

function app_auth(ctx)
	local input_data = http.content() or nil
	local auth_fail=true
	if input_data and #input_data > 0 then
		nixio.syslog("err",input_data)
		local data_json = cjson.decode(input_data)
		local real_data=""
		local pre_buffer=""
		local md5_data=""

		if data_json and type(data_json) == "table" and data_json.data then
			--nixio.syslog("err","data_json.data:"..data_json.data)
			local decrypt_data = util.exec("nradio_crypto -d -s "..data_json.data)
			if decrypt_data then
				nixio.syslog("err","decrypt_data:"..decrypt_data)
				real_data = cjson.decode(decrypt_data);
				if real_data and type(real_data) == "table" and real_data.timestamp and real_data.trans_id and real_data.token then
					pre_buffer="device_code"..real_data.device_code.."timestamp"..real_data.timestamp.."trans_id"..real_data.trans_id
					md5_data=util.exec("nradio_crypto -t \""..pre_buffer.."\"")
					md5_data=md5_data:gsub("\n","")
					--nixio.syslog("err","md5_data:"..md5_data)
					--nixio.syslog("err","real_data.token:"..real_data.token)
					if real_data.token and #real_data.token and real_data.token == md5_data then
						auth_fail=false
					end
				end
			end
		end
	end

	if auth_fail then
		nixio.syslog("err","auth fail")
		app_auth_failed()
	else
		--nixio.syslog("err","auth ok")
		local config = require "luci.config"
		local sdat = util.ubus("session", "create", { timeout = tonumber(config.sauth.sessiontime) })
		if sdat then
			token = sys.uniqueid(16)
			util.ubus("session", "set", {
				ubus_rpc_session = sdat.ubus_rpc_session,
				values = {
					user = "root",
					token = token,
					section = sys.uniqueid(16)
				}
			})
			sess = sdat.ubus_rpc_session
		end


		if sess and token then
			if ctx then
				ctx.authsession = sess
				ctx.authtoken = token
				ctx.authuser = user
			end
		end
		app_response(app_encrypto("{\"code\":\"0\",\"token\":\""..sess.."\",\"timeout\":"..tonumber(config.sauth.sessiontime).."}"))
	end
end

function get_combo_info()
	local os = require "os"
	local runtime = {
		combo={},
		accumulation={total={},list={}},
		sysconf={SMdtMsd="",Dsg=1}
	}
	local cpe_accumulation_buffer = "combo sysconf"
	local cpe_count = 0
	local cur = uci.cursor()
	local cpe_total = {Dds=0,Mds=0,Cds=0,date=""}
	cpe_total.date = os.date("%Y-%m-%d")

	cur:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
				cpe_count=cpe_count+1
				cpe_accumulation_buffer = cpe_accumulation_buffer.." "..s[".name"].."_accumulation"
			end
		end
	)
	local runtime_info = util.ubus("infocd", "get", { name = cpe_accumulation_buffer }) or {list={}}

	for _,item in pairs(runtime_info.list) do
		if item.name and item.name == "combo" then
			runtime.combo = item.parameter.combo_record or {}
		end
		if item.name and item.name:match(cellular_prefix.."(%d*)_accumulation") then
			local index = item.name:match(cellular_prefix.."(%d*)_accumulation")
			if (index == nil) or (index == "") or (tonumber(index) == 0 ) then
				index=1
			else
				index=tonumber(index)+1
			end
			if index <= cpe_count then
				local accumulation_data = item.parameter.sim_record or {}
				local cpe_data = item.parameter.cpe_record or {}

				if cpe_data.Dds and tonumber(cpe_data.Dds)>0 then
					cpe_total.Dds = cpe_total.Dds + tonumber(cpe_data.Dds)
				end
				if cpe_data.Mds and tonumber(cpe_data.Mds)>0 then
					cpe_total.Mds = cpe_total.Mds + tonumber(cpe_data.Mds)
				end
				if cpe_data.Cds and tonumber(cpe_data.Cds)>0 then
					cpe_total.Cds = cpe_total.Cds + tonumber(cpe_data.Cds)
				end
				runtime.accumulation.list[index] = accumulation_data
			end
		end
		if item.name and item.name == "sysconf" then
			local sysconf_data = item.parameter.sysconf_record or {}
			if sysconf_data.SMdtMsd then
				runtime.sysconf.SMdtMsd = sysconf_data.SMdtMsd
			end
			if sysconf_data.Dsg then
				runtime.sysconf.Dsg = sysconf_data.Dsg
			end
		end
	end
	runtime.accumulation.total = cpe_total
	if #runtime.accumulation.list == 0 then
		runtime.accumulation.list[1] = {}
	end
	if #runtime.combo == 0 then
		runtime.combo[1] = {}
	end
	return runtime
end

function get_speedlimit_info()
	local data = {
		list={},
		support="0"
	}

	local cur = uci.cursor()
	data.support = cur:get("cloudd", "limit", "support") or "0"
	cur:foreach("cloudd", "speedlimit",
		function(s)
			local item = {type="",enabled="",stage={}}
			item.type = s[".name"] or ""
			item.enabled = s["enabled"] or "1"
			item.stage = s["stage"] or {}
			if #item.stage == 0 then
				item.stage[1] = ""
			end
			data.list[#data.list+1] = item
		end
	)

	if #data.list == 0 then
		data.list[1] = {}
	end

	return data
end

function ubus_send(event,p_data)
	local ubus = require "ubus"
	local conn = ubus.connect()
	local socket = require "socket"
	local rv
	local rst

	if not event then
		return -1
	end

	if conn == nil then
		return -1
	end

	rst, rv = conn:send(event, p_data)

	conn:close()
	return rv
end

function switch_simcard(simcard,mode)
	local uci = uci.cursor()
	local cur_now = uci:get("cpesel","sim","cur") or ""
	local mode_now = uci:get("cpesel","sim","mode") or ""
	local mode_target = 1
	local change = 0
	local sim_target = tonumber(cur_now)
	local max = uci:get("cpesel","sim","max") or "1"

	if mode then
		mode_target = mode
	end

	if simcard and type(simcard) == "number" then
		sim_target = simcard
	end

	if tonumber(cur_now) ~= sim_target then
		if sim_target > tonumber(max) then
			return false
		end
		uci:set("cpesel","sim","cur",tostring(sim_target))
		change = 1
	end

	if tonumber(mode_now) ~= mode_target then
		uci:set("cpesel","sim","mode",tostring(mode_target))
		change = 1
	end
	if change == 1 then
		uci:commit("cpesel")
		fork_exec(function()
			nixio.nanosleep(2)
			util.exec("/etc/init.d/cpesel restart")
			util.exec("/etc/init.d/wanchk restart")
			util.exec("/etc/init.d/tcsd restart")
		end)
	end

	return true
end

function get_sim_alias()
	local stype, t, idx,i
	local uci = uci.cursor()
	local model_data = {}

	stype_str = {lng.translate("SIM Slot"),
	lng.translate("Embedded China Mobile SIM"),
	lng.translate("Embedded China Unicom SIM"),
	lng.translate("Embedded China Telecom SIM"),
	lng.translate("Embedded SIM")}

	uci:foreach("cpesel", "cpesel",
		function(s)
			local stype_idx = {0, 0, 0, 0, 0}
			local stype_cnt = {0, 0, 0, 0, 0}
			local alias_data = {}
			local sim_two_sided = false
			local sim_two_sided_index=1

			if support_sim_two_sided(s[".name"]) then
				sim_two_sided = true
			end

			stype = util.split(s.stype or "0", ",")
			local  max = #stype

			for i = 1, max do
				t = (stype[i] and stype[i] or 0) + 1
				stype_cnt[t] = stype_cnt[t] + 1
			end
			for i = 1, max do
				t = (stype[i] and stype[i] or 0) + 1
				if stype_cnt[t] > 1 then
					stype_idx[t] = stype_idx[t] + 1
					idx = stype_idx[t]
				else
					idx = ""
				end
				alias_data[#alias_data + 1] = stype_str[t]..idx
				if sim_two_sided and stype_str[t] == lng.translate("SIM Slot") then
					if sim_two_sided_index == 1 then
						alias_data[#alias_data]=alias_data[#alias_data].."("..lng.translate("Front SIM")..")"
					elseif sim_two_sided_index == 2 then
						alias_data[#alias_data]=alias_data[#alias_data].."("..lng.translate("Back SIM")..")"
					end
					sim_two_sided_index=sim_two_sided_index+1
				end
			end
			model_data[#model_data + 1] = alias_data
		end
	)

	return model_data
end

function check_cellular_neighbour(model)
	local cellular_array = {}
	local iface = model or cellular_default
	local cpescan_last_cache = "/tmp/"..iface.."scan_cache_last_"
	local index=1
	local data_cnt=0
	local cur = uci.cursor()
	nixio.syslog("err","check result")

	cellular_array[#cellular_array+1] = {}
	if fs.access(cpescan_last_cache..iface) then
		scan_result = fs.readfile(cpescan_last_cache..iface)
		if scan_result and #scan_result > 0 then
			local scan_array = cjson.decode(scan_result)
			if scan_array and scan_array.scanlist then
				data_cnt=data_cnt+1
				nixio.syslog("err","scan check "..iface.." ok")
				cellular_array[index] = scan_array.scanlist or {}
			end
		end
	end
	if #cellular_array == 0 then
		cellular_array[1] = {}
	end
	return cellular_array,(index == (data_cnt+1))
end

function get_cellular_neighbour_cache(model)
	local utl = require "luci.util"
	local nr = require "luci.nradio"
	local fs = require "nixio.fs"
	local cjson = require "cjson.safe"

	local cache_data=""
	local cpescan_cache = "/tmp/"..model.."scan_cache"

	if fs.access(cpescan_cache) then
		cache_data = fs.readfile(cpescan_cache)
		local cache_json =  cjson.decode(cache_data)
		if cache_json then
			for _,v in ipairs(cache_json) do
				for _,vs in ipairs(v) do
					if vs.ISP and #vs.ISP then
						local tmp_isp=""
						isp_array = utl.split(vs.ISP, ":")
						max = #isp_array
						for i = 1, max do
							tmp_isp = tmp_isp..genarate_plmn_company(isp_array[i]).." "
						end
						vs.ISP=tmp_isp
					end
				end
			end
			cache_data =  cjson.encode(cache_json)
		end
	end
	return cache_data
end

function get_cellular_neighbour(model,type,force)
	local cellular_array = {}
	local cur = uci.cursor()
	local exsit = 0
	local iface = model or cellular_default 
	local cpescan_time = "/tmp/"..iface.."scan_time_point"
	local cpescan_cache = "/tmp/"..iface.."scan_cache"
	local cpescan_last_cache = "/tmp/"..iface.."scan_cache_last_"
	local sysinfo = util.ubus("system", "info") or { }
	local upt = sysinfo.uptime or 0
	local last_scan_point = 0
	local scan_interval = 60

	if get_platform() == "quectel" then
		if not is_openwrt() then
			util.exec("mkdir -p /var/run/infocd/tmp")
			cpescan_time = "/var/run/infocd/tmp/cpescan_time_point"
			cpescan_cache = "/var/run/infocd/tmp/cpescan_cache"
			cpescan_last_cache = "/var/run/infocd/tmp/cpescan_cache_last_"
		end
	end
	if force then
		util.exec("rm -f "..cpescan_time)
		util.exec("rm -f "..cpescan_cache)
		util.exec("rm -f "..cpescan_last_cache..iface)
	end
	if fs.access(cpescan_time) then
		local time_buffer = fs.readfile(cpescan_time)
		if time_buffer and #time_buffer > 0 then
			last_scan_point = tonumber(time_buffer)
		end
	end

	diff_time = upt - last_scan_point

	local cur_scan = {}
	if diff_time >= scan_interval then
		local try_time=1

		cur_scan[iface]={hasResult=0}
		cellular_array[#cellular_array+1] = {}
		fork_exec(function()
			if check_nrfamily_if(iface) then
				local result = app_scan_cellinfo(iface,type,force)
				local scan_json = cjson.decode(result)
				local target = {scanlist={}}
				if scan_json and scan_json.result and scan_json.result.neighbour then
					target.scanlist = scan_json.result.neighbour[1]
					local cache_data = cjson.encode(target)
					if #cache_data > 0 then
						fs.writefile(cpescan_last_cache..iface,cache_data)
					end
				end
			else
				if type == "5" then
					util.exec("cpetools.sh -i "..iface.." -c scan sa_only > "..cpescan_last_cache..iface)
				elseif type == "4" then
					util.exec("cpetools.sh -i "..iface.." -c scan lte > "..cpescan_last_cache..iface)				
				else
					util.exec("cpetools.sh -i "..iface.." -c scan > "..cpescan_last_cache..iface)
				end
			end
		end)
		nixio.syslog("err","scan "..iface)

		while true do
			if try_time>30 then
				nixio.syslog("err","scan get total over,timeout")
				break
			end
			nixio.nanosleep(2)
			local need_check=0
			local index=1
			for key,item in pairs(cur_scan) do
				if item["hasResult"] == 0 then
					need_check = 1
					if fs.access(cpescan_last_cache..key) then
						local scan_result = fs.readfile(cpescan_last_cache..key)
						if scan_result and #scan_result > 0 then
							local scan_array = cjson.decode(scan_result)
							if scan_array and scan_array.scanlist then
								nixio.syslog("err","scan get "..key.." new data")
								item["hasResult"] = 1
								if #scan_array.scanlist > 0 then
									exsit=1
								end
								cellular_array[index] = scan_array.scanlist or {}
							end
						end
					end
				end
				index=index+1
			end
			if need_check == 0 then
				nixio.syslog("err","scan get total over")
				break
			end
			try_time=try_time+1
		end

		util.exec("echo \""..upt.."\" > "..cpescan_time)
		if exsit == 1 then
			local cache_data = cjson.encode(cellular_array)
			if #cache_data > 0 then
				fs.writefile(cpescan_cache,cache_data)
			end
		end
	end

	if exsit == 0  then
		neighbour,result = check_cellular_neighbour(model)
		if result then
			nixio.syslog("err","scan get last new scan")
			cellular_array = neighbour
		end

		if #cellular_array == 0 or fs.access(cpescan_cache) then
			local cache_data = fs.readfile(cpescan_cache)
			local cache_json =  cjson.decode(cache_data)
			if cache_json then
				nixio.syslog("err","scan get cache scan")
				cellular_array = cache_json
			end
		end

	end

	if #cellular_array == 0 then
		cellular_array[1] = {}
	end
	return cellular_array
end

function do_cellular_earfcns(base_data,earfcns)
	local reload=false
	local reload_one=0
	for i = 1, #earfcns do
		local enabled = earfcns[i].enabled or "1"
		reload_one=do_cellular_earfcn(tonumber(enabled),base_data,earfcns[i])
		if reload_one then
			reload = reload_one
		end
	end
	return reload
end

function do_cellular_earfcn(action,base_data,info)
	local cur = uci.cursor()
	local change=false

	if not base_data or (#base_data.cpecfg_name == 0) then
		return change
	end
	local cpecfg_file = base_data.cpecfg_file
	if action == 0 then
		if info and info.MODE and info.MODE:match("NR") then
			if base_data.support_earfcn5 then
				cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_earfcn5")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn5")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "band5")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "pci5")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn5_mode")
				change=true
			end
		else
			if base_data.support_earfcn4 then
				cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_earfcn4")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn4")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "band4")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "pci4")
				cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn4_mode")
				change=true
			end
		end
	elseif action == 1 then
		if info then
			if info.MODE == "LTE" then
				if base_data.earfreq_work_mode == "one" then
					if base_data.support_earfcn5 then
						cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_earfcn5")
						cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn5")
						cur:delete(cpecfg_file, base_data.cpecfg_name, "band5")
						cur:delete(cpecfg_file, base_data.cpecfg_name, "pci5")
						change=true
					end
				end
				if base_data.support_band then
					cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_freq")
					cur:delete(cpecfg_file, base_data.cpecfg_name, "freq")
					change=true
				end
				if base_data.support_earfcn4 then
					change=true
					cur:set(cpecfg_file, base_data.cpecfg_name, "cpesim")
					cur:set(cpecfg_file, base_data.cpecfg_name, "custom_earfcn4","1")
					if info.EARFCN and #info.EARFCN > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "earfcn4",info.EARFCN)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn4")
					end

					if info.earfcn4_mode and #info.earfcn4_mode > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "earfcn4_mode",info.earfcn4_mode)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn4_mode")
					end

					if info.PCI and #info.PCI > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "pci4",info.PCI)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "pci4")
					end

					if info.BAND and #info.BAND > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "band4",info.BAND)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "band4")
					end
				end
			elseif info.MODE:match("NR") then
				if base_data.earfreq_work_mode == "one" then
					if base_data.support_earfcn4 then
						cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_earfcn4")
						cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn4")
						cur:delete(cpecfg_file, base_data.cpecfg_name, "band4")
						cur:delete(cpecfg_file, base_data.cpecfg_name, "pci4")
						change=true
					end
				end
				if base_data.support_band then
					cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_freq")
					cur:delete(cpecfg_file, base_data.cpecfg_name, "freq")
					change=true
				end
				if base_data.support_earfcn5 then
					change=true
					cur:set(cpecfg_file, base_data.cpecfg_name, "cpesim")
					cur:set(cpecfg_file, base_data.cpecfg_name, "custom_earfcn5","1")

					if info.EARFCN and #info.EARFCN > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "earfcn5",info.EARFCN)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn5")
					end
					if info.earfcn5_mode and #info.earfcn5_mode > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "earfcn5_mode",info.earfcn5_mode)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "earfcn5_mode")
					end
					if info.PCI and #info.PCI > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "pci5",info.PCI)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "pci5")
					end

					if info.BAND and #info.BAND > 0 then
						cur:set(cpecfg_file, base_data.cpecfg_name, "band5",info.BAND)
					else
						cur:delete(cpecfg_file, base_data.cpecfg_name, "band5")
					end
				end
			end
		end
	end

	if change then
		cur:commit(cpecfg_file)
	end
	return change
end

function do_cellular_earfreq_mode(base_data,earfreq_mode)
	local cur = uci.cursor()
	local reload = false
	local earfreq_mode_default = ""
	local cpecfg_file = base_data.cpecfg_file
	local cur_earfreq_work_mode = cur:get(cpecfg_file,base_data.cpecfg_name,"earfreq_mode") or ""
	if base_data.support_band and earfreq_mode == "band" then
		earfreq_mode_default = earfreq_mode
	end
	if base_data.support_earfcn4 and earfreq_mode == "earfcn4" then
		earfreq_mode_default = earfreq_mode
	end
	if base_data.support_earfcn5 and earfreq_mode == "earfcn5" then
		earfreq_mode_default = earfreq_mode
	end
	if cur_earfreq_work_mode ~= earfreq_mode_default then
		cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
		cur:set(cpecfg_file, base_data.cpecfg_name, "earfreq_mode",earfreq_mode_default)
		reload = true
		cur:commit(cpecfg_file)
	end
	
	return reload
end
function do_cellular_band(base_data,band)
	local cur = uci.cursor()
	local reload = false
	local enabled = band.enabled or "1"
	local freq = band.freq or ""
	local cpecfg_file = base_data.cpecfg_file
	if not base_data or (#base_data.cpecfg_name == 0) then
		return reload
	end

	if base_data.support_band then
		if base_data.support_earfcn5 then
			cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_earfcn5")
			reload=true
		end
		if base_data.support_earfcn4 then
			cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_earfcn4")
			reload=true
		end

		local simcfg = cur:get_all(cpecfg_file, base_data.cpecfg_name) or {}
		if not simcfg.custom_freq or simcfg.custom_freq ~= enabled or enabled == "0" then
			cur:set(cpecfg_file, base_data.cpecfg_name, "cpesim")
			if enabled and #enabled > 0 and simcfg.earfreq_mode == "band" then
				cur:set(cpecfg_file, base_data.cpecfg_name, "custom_freq",enabled)
			else
				cur:delete(cpecfg_file, base_data.cpecfg_name, "custom_freq")
			end
			reload=true
		end
		if not simcfg.freq or simcfg.freq ~= freq then
			cur:set(cpecfg_file, base_data.cpecfg_name, "cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "freq",freq)
			reload=true
		end
	end
	if reload then
		cur:commit(cpecfg_file)
	end
	return reload
end

function do_cellular_mode(base_data,mode)
	local cur = uci.cursor()
	local reload = false
	local cpecfg_file = base_data.cpecfg_file
	if not mode or (#mode == 0) then
		return reload
	end
	if base_data.cpecfg_name and #base_data.cpecfg_name > 0 then
		local modecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"mode") or ""
		if modecfg ~= mode then
			cur:set(cpecfg_file, base_data.cpecfg_name, "cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "mode",mode)
			reload=true
		end
	end
	if reload then
		cur:commit(cpecfg_file)
	end
	return reload
end
function do_cellular_adv(base_data,adv)
	local cur = uci.cursor()
	local reload = false

	if not adv then
		return reload
	end
	local cpe_section = base_data.cpe_name
	local cpecfg_file = base_data.cpecfg_file
	local network_file = base_data.network_file
	local ori_cpe = base_data.ori_cpe
	local local_cpesection = ori_cpe or cpe_section
	if base_data.cpecfg_name and #base_data.cpecfg_name > 0 then
		cur:set(cpecfg_file, base_data.cpecfg_name, "cpesim")
		local support_mobility = uci:get(network_file,cpe_section,"mobility")
		if support_mobility then
			if uci:get(network_file,cpe_section,"mobility") then
				local mobilitycfg = cur:get(cpecfg_file, base_data.cpecfg_name,"mobility") or ""
				if mobilitycfg ~= adv.mobility then
					cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
					cur:set(cpecfg_file, base_data.cpecfg_name, "mobility",adv.mobility or "")
					reload=true
				end
			end
		end
		if support_nr(cpe_section,network_file) then			
			local freq_timecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"freq_time") or ""
			if freq_timecfg ~= adv.freq_time then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "freq_time",adv.freq_time or "")
				reload=true
			end
			local endtimecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"endtime") or ""
			if endtimecfg ~= adv.endtime then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "endtime",adv.endtime or "")
				reload=true
			end
			local starttimecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"starttime") or ""
			if starttimecfg ~= adv.starttime then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "starttime",adv.starttime or "")
				reload=true
			end
			local peak_hourcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"peak_hour") or ""
			if peak_hourcfg ~= adv.peak_hour then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "peak_hour",adv.peak_hour or "")
				reload=true
			end
			local peak_timecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"peaktime") or ""
			if peak_timecfg ~= adv.peaktime then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "peaktime",adv.peaktime or "")
				reload=true
			end
		end
		if support_cellular_roam (local_cpesection) then
			local roamingcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"roaming") or ""
			if roamingcfg ~= adv.roaming then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "roaming",adv.roaming or "")
				reload=true
			end
		end
		if uci:get(network_file,cpe_section,"compatibility") == "1" then
			local compatibilitycfg = cur:get(cpecfg_file, base_data.cpecfg_name,"compatibility") or ""
			if compatibilitycfg ~= adv.compatibility then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "compatibility",adv.compatibility or "")
				reload=true
			end
		end

		if support_cellular_ippass(cpe_section) then
			local ippasscfg = cur:get(cpecfg_file, base_data.cpecfg_name,"ippass") or ""
			if ippasscfg ~= adv.ippass then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "ippass",adv.ippass or "")
				reload=true
			end
		end

		if support_cellular_nrrc(cpe_section) then
			local nrrccfg = cur:get(cpecfg_file, base_data.cpecfg_name,"nrrc") or ""
			if nrrccfg ~= adv.nrrc then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "nrrc",adv.nrrc or "")
				reload=true
			end
		end
		
		local profilecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"profile") or ""
		if profilecfg ~= adv.profile then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "profile",adv.profile or "")
			reload=true
		end
		local permanentcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"permanent") or ""
		if permanentcfg ~= adv.permanent then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "permanent",adv.permanent or "")
			reload=true
		end

		if support_compatible_nr(cpe_section) then
			local compatible_nrcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"compatible_nr") or ""
			if compatible_nrcfg ~= adv.compatible_nr then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "compatible_nr",adv.compatible_nr or "")
				reload=true
			end
		end

		if support_fallbackToR16() then
			local fallbackToR16cfg = cur:get(cpecfg_file, base_data.cpecfg_name,"fallbackToR16") or ""
			if fallbackToR16cfg ~= adv.fallbackToR16 then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "fallbackToR16",adv.fallbackToR16 or "")
				reload=true
			end
		end

		if support_fallbackToLTE() then
			local fallbackToLTEcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"fallbackToLTE") or ""
			if fallbackToLTEcfg ~= adv.fallbackToLTE then
				cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
				cur:set(cpecfg_file, base_data.cpecfg_name, "fallbackToLTE",adv.fallbackToLTE or "")
				reload=true
			end
		end

		local threshold_enabledcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"threshold_enabled") or ""
		if threshold_enabledcfg ~= adv.threshold_enabled then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "threshold_enabled",adv.threshold_enabled or "")
			reload=true
		end
		local threshold_typecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"threshold_type") or ""
		if threshold_typecfg ~= adv.threshold_type then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "threshold_type",adv.threshold_type or "")
			reload=true
		end
		local threshold_datacfg = cur:get(cpecfg_file, base_data.cpecfg_name,"threshold_data") or ""
		if threshold_datacfg ~= adv.threshold_data then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "threshold_data",adv.threshold_data or "")
			reload=true
		end
		local threshold_percentcfg = cur:get(cpecfg_file, base_data.cpecfg_name,"threshold_percent") or ""
		if threshold_percentcfg ~= adv.threshold_percent then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "threshold_percent",adv.threshold_percent or "")
			reload=true
		end
		local threshold_datecfg = cur:get(cpecfg_file, base_data.cpecfg_name,"threshold_date") or ""
		if threshold_datecfg ~= adv.threshold_date then
			cur:set(cpecfg_file, base_data.cpecfg_name,"cpesim")
			cur:set(cpecfg_file, base_data.cpecfg_name, "threshold_date",adv.threshold_date or "")
			reload=true
		end
	end
	if reload then
		cur:commit(cpecfg_file)
	end
	return reload
end
function do_cellular_adv_cpedata(base_data,adv)
	local cur = uci.cursor()
	local reload = false

	if not adv then
		return reload
	end
	local cpecfg_file = base_data.cpecfg_file
	for _,item in pairs(adv) do
		if item.sim_id then
			local cpecfg_name = base_data.cpe_name.."sim"..item.sim_id			
			local threshold_enabledcfg = cur:get(cpecfg_file, cpecfg_name,"threshold_enabled") or ""
			if threshold_enabledcfg ~= item.threshold_enabled then
				cur:set(cpecfg_file, cpecfg_name,"cpesim")
				cur:set(cpecfg_file, cpecfg_name, "threshold_enabled",item.threshold_enabled or "")
				reload=true
			end
			local threshold_typecfg = cur:get(cpecfg_file, cpecfg_name,"threshold_type") or ""
			if threshold_typecfg ~= item.threshold_type then
				cur:set(cpecfg_file, cpecfg_name,cpecfg_file)
				cur:set(cpecfg_file, cpecfg_name, "threshold_type",item.threshold_type or "")
				reload=true
			end
			local threshold_datacfg = cur:get(cpecfg_file, cpecfg_name,"threshold_data") or ""
			if threshold_datacfg ~= item.threshold_data then
				cur:set(cpecfg_file, cpecfg_name,"cpesim")
				cur:set(cpecfg_file, cpecfg_name, "threshold_data",item.threshold_data or "")
				reload=true
			end
			local threshold_percentcfg = cur:get(cpecfg_file, cpecfg_name,"threshold_percent") or ""
			if threshold_percentcfg ~= item.threshold_percent then
				cur:set(cpecfg_file, cpecfg_name,"cpesim")
				cur:set(cpecfg_file, cpecfg_name, "threshold_percent",item.threshold_percent or "")
				reload=true
			end
			local threshold_datecfg = cur:get(cpecfg_file, cpecfg_name,"threshold_date") or ""
			if threshold_datecfg ~= item.threshold_date then
				cur:set(cpecfg_file, cpecfg_name,"cpesim")
				cur:set(cpecfg_file, cpecfg_name, "threshold_date",item.threshold_date or "")
				reload=true
			end

			local signalcfg = cur:get(cpecfg_file, cpecfg_name,"signal") or ""
			if signalcfg ~= item.signal then
				cur:set(cpecfg_file, cpecfg_name,"cpesim")
				cur:set(cpecfg_file, cpecfg_name, "signal",item.signal or "")
				reload=true
			end
			local enabledcfg = cur:get(cpecfg_file, cpecfg_name,"enabled") or ""
			if enabledcfg ~= item.enabled then
				cur:set(cpecfg_file, cpecfg_name,"cpesim")
				cur:set(cpecfg_file, cpecfg_name, "enabled",item.enabled or "")
				reload=true
			end
		end
	end
	
	if reload then
		cur:commit(cpecfg_file)
	end
	return reload
end
function get_earfcn_data(base_data)
	local result = {}
	local cur = uci.cursor()

	if not base_data or (#base_data.cpecfg_name == 0) then
		return result
	end

	local simcfg = cur:get_all(base_data.cpecfg_file, base_data.cpecfg_name) or {}

	result.mode = simcfg.mode or "auto"
	result.adv = simcfg
	if base_data.support_band then
		local band = {}
		band.status = simcfg.custom_freq or "0"
		band.freq = simcfg.freq or ""
		result.band = band
	end

	result.earfcn = {}

	if base_data.support_earfcn5 then
		local earfcn5 = {}
		earfcn5.status = simcfg.custom_earfcn5 or "0"
		earfcn5.EARFCN = simcfg.earfcn5 or ""
		earfcn5.PCI = simcfg.pci5 or ""
		earfcn5.BAND = simcfg.band5 or ""
		earfcn5.MODE = "NR"
		result.earfcn[#result.earfcn + 1] = earfcn5
	end

	if base_data.support_earfcn4 then
		local earfcn4 = {}
		earfcn4.status = simcfg.custom_earfcn4 or "0"
		earfcn4.EARFCN = simcfg.earfcn4 or ""
		earfcn4.PCI = simcfg.pci4 or ""
		earfcn4.MODE = "LTE"
		result.earfcn[#result.earfcn + 1] = earfcn4
	end
	return result
end

function do_cellular_apn(base_data,data)
	local cur = uci.cursor()
	local change = false

	if not base_data or (#base_data.cpecfg_name == 0) then
		return change
	end
	local filename = get_apn_filename(base_data.cpe_name)
	if not fs.access("/etc/config/"..filename) then
		util.exec("touch /etc/config/"..filename)
	end

	local apn_cfg = data.profile or "app"
	local simcfg = cur:get_all(filename, apn_cfg) or {}
	local apn = data.apn or ""
	local username = data.username or ""
	local password = data.password or ""
	local auth = data.auth or "0"
	local pdptype = data.pdptype or "ipv4v6"
	local enabled = data.enabled or "1"
	local sim_profile = data.sim_profile
	if data.action and tonumber(data.action) == 0 then
		cur:delete(filename,apn_cfg)
		change=true
	else
		cur:set(filename,apn_cfg, "rule")
		if not simcfg.apn or simcfg.apn ~= apn then
			cur:set(filename, apn_cfg, "apn",apn)
			change=true
		end
		if not simcfg.username or simcfg.apn ~= username then
			cur:set(filename, apn_cfg, "username",username)
			change=true
		end
		if not simcfg.password or simcfg.apn ~= password then
			cur:set(filename, apn_cfg, "password",password)
			change=true
		end
		if not simcfg.auth or simcfg.apn ~= auth then
			cur:set(filename, apn_cfg, "auth",auth)
			change=true
		end
		if not simcfg.pdptype or simcfg.pdptype ~= apn then
			cur:set(filename, apn_cfg, "pdptype",pdptype)
			change=true
		end
		if not simcfg.custom_apn or simcfg.custom_apn ~= enabled then
			cur:set(filename, apn_cfg, "custom_apn",enabled)
			change=true
		end
	end

	local locao_sim_profile = cur:get("cpecfg", base_data.cpecfg_name, "apn_cfg")
	if sim_profile then		
		if locao_sim_profile ~= sim_profile and #sim_profile > 0 then
			cur:set("cpecfg", base_data.cpecfg_name, "apn_cfg",sim_profile)
			change=true
		end
	else
		if locao_sim_profile ~= apn_cfg then
			change=true
			cur:set("cpecfg", base_data.cpecfg_name, "apn_cfg",apn_cfg)
		end
	end
	if change then
		cur:commit(filename)
		cur:commit("cpecfg")
	end
	return change
end

function do_cellular_sms(base_data,data)
	local cur = uci.cursor()
	local change = false

	if not base_data or (#base_data.cpecfg_name == 0) then
		return change
	end

	if not fs.access("/etc/config/cpecfg") then
		util.exec("touch /etc/config/cpecfg")
	end

	local simcfg = cur:get_all("cpecfg", base_data.cpecfg_name) or {}
	local force_ims = data.enabled or ""

	cur:set("cpecfg",base_data.cpecfg_name, "cpesim")
	if not simcfg.force_ims or simcfg.force_ims ~= force_ims then
		cur:set("cpecfg", base_data.cpecfg_name, "force_ims",force_ims)
		change=true
	end
	if change then
		cur:commit("cpecfg")
		app_write_sms(base_data.cpe_name,base_data.sim,base_data.cpecfg_name)
	end
	return change
end

function encode_pdu(smsc, phone_num,sms_msg)
	local luapdu = require("luci.luapdu")
	local pdu_arr = {}

	local pdu_data = ""
	smsObj = luapdu.newTx()
	smsObj.recipient.num = phone_num
	smsObj.msg.content = sms_msg
	smsObj.smsc = {num = smsc}
	pdu_data = smsObj:encode()

    for i,sms in ipairs(pdu_data) do
		local pdu_item = {pdu="",lens=0}
		pdu_item.pdu=sms
		pdu_item.lens=(#sms)/2 - tonumber(sms:sub(1,2),16) - 1
		pdu_arr[#pdu_arr+1] = pdu_item
	 end

	return pdu_arr
end


function support_ims(rule_name)
	uci = uci.cursor()

	if  rule_name and #rule_name > 0 then
		local sms = uci:get("network",rule_name,"sms") or ""
		if sms == "1" then
			return true
		end
		return false
	end

	local count_cpe = count_cpe()
	local vsim_active_support=0

	for i = 0, count_cpe - 1 do
		local iface = (i == 0 and cellular_default or cellular_prefix..i)
		local sms = uci:get("network",iface,"sms") or ""
		local sim_rule = (i == 0 and "sim" or "sim"..i)
		local cellular_disabled = uci:get("network",iface,"disabled") or ""
		local vsim_active = uci:get("cpesel",sim_rule,"vsim") or ""

		if vsim_active == "1" and cellular_disabled ~= "1" then
			vsim_active_support = 1
		end

		if sms and sms == "1" and vsim_active_support == 0 then
			return true
		end
	end

	return false
end

function support_automatic(rule_name)
	uci = uci.cursor()
	if  rule_name and #rule_name > 0 then
		local module_automatic = uci:get("network",rule_name,"automatic") or ""
		if module_automatic == "1" then
			return true
		end
		return false
	end
	local count_cpe = count_cpe()
	for i = 0, count_cpe - 1 do
		local iface = (i == 0 and cellular_default or cellular_prefix..i)
		local module_automatic = uci:get("network",iface,"automatic") or ""
		if module_automatic == "1" then
			return true
		end
	end
	return false
end
function support_self_speedlimit()
	uci = uci.cursor()
	local self_speedlimit = uci:get("system","basic", "speedlimit") or ""
	if self_speedlimit == "0" then
		return false
	end
	return true
end
function support_sim_two_sided(rule_name)
	uci = uci.cursor()
	local two_sided = uci:get("luci","main","two_sided") or ""
	local cpesel_info = uci:get_all("cpesel", rule_name) or {}
	if two_sided == "1" then
		local stype = util.split(cpesel_info.stype or "0", ",")
		local slot_cnt = 0
		local  max = #stype
		
		for i = 1, max do
			if stype[i] == "0" then
				slot_cnt=slot_cnt+1
			end
		end
		if slot_cnt > 1 then
			return true
		end
	end
	return false
end


function sms_list(sms_type,channel)
	local name = channel or ""
	local ifname = cellular_default
	if name == cellular_default then
		name=""
	end
    if channel and #channel > 0 then
        ifname = tostring(channel)
    end
	if not sms_type then
		sms_type=""
	else
		--[[return {smslist={
			{index="89",timestamp=1701439510,content="adfadfadfadsfasd",contact="16567494"},
			{index="90",timestamp=1701439710,content="hgjhgdadfadfadfa达到",contact="16567494"},
			{index="91",timestamp=1701439810,content="hggg我凯乐科技了们1",contact="18038035002"},
			{index="92",timestamp=1701439910,content="hggg我们2",contact="18038035002"}}}--]]
	end
	local smsdlist = {code=sms_noresult}
	if not support_ims() then
		smsdlist.code = sms_notsupport
		return smsdlist
	end
	if check_nrfamily_if(ifname) then
		local app_result = app_sms_data(ifname,{action = "read",type=sms_type})
		app_result = cjson.decode(app_result) or {}
		smsdlist = app_result.result or {smslist={},ready=0}
	else
		smsdlist = util.ubus("smsd"..name, "list",{type=sms_type}) or {smslist={},ready=0}
	end
	smsdlist.code = 0
	return smsdlist
end

function sms_del(ids,sms_type,channel)
	local return_code = {code=sms_noresult}
	local name = channel or ""
	local ifname = cellular_default
	if name == cellular_default then
		name=""
	end
    if channel and #channel > 0 then
        ifname = tostring(channel)
    end
	if not support_ims() then
		return_code.code = sms_notsupport
		return return_code
	end

	if not sms_type then
		sms_type=""
	end
	
	local data = {type=sms_type}
	if ids and #ids > 0 then
		data.ids=ids
	end
	if check_nrfamily_if(ifname) then		
		data.action="del"
		local app_result = app_sms_data(ifname,data)
		app_result = cjson.decode(app_result) or {}
		return_code = app_result or { code=sms_error }
	else
		return_code = util.ubus("smsd"..name, "del",data) or { code=sms_error }
	end
	if not return_code.code then
		return_code.code = sms_error
	end

	return return_code
end

function sms_send(sms_msg,phone_num,channel)
	local return_code = {code=sms_noresult,item={}}
	local ifname = cellular_default
	local name = channel or ""
	local multi_result=sms_noresult
	local smsstorage_data = nil
	local last_space=0
	if not support_ims() then
		return_code.code = sms_notsupport
		return return_code
	end

    if channel and #channel > 0 then
        ifname = tostring(channel)
    end

	if name == cellular_default then
		name=""
	end

	local cur = uci.cursor()


	if sms_msg and #sms_msg>0 and phone_num and #phone_num>0 then
		if not phone_num:match("\+") then
			nixio.syslog("err","phone_num not +")
			if phone_num:match("^1[3-9]%d%d%d%d%d%d%d%d%d$") then
				nixio.syslog("err","phone_num match phone")
				phone_num="+86"..phone_num
			end
		end
		nixio.syslog("err","phone_num:"..phone_num)
		if check_nrfamily_if(ifname) then
			local app_result = app_sms_data(ifname,{action="send",phone_num=phone_num,msg=sms_msg})
			app_result = cjson.decode(app_result) or {}
			return_code.item = app_result.item or {{}}
			return_code.code = app_result.code
		else
			local smsc = util.exec("cpetools.sh -i "..ifname.." -c smsnum")
			local smsstorage = util.exec("cpetools.sh -i "..ifname.." -c smsstorage")
			if smsstorage and #smsstorage > 0 then
				smsstorage_data = cjson.decode(smsstorage) or {}
			end
			if not smsc or #smsc ==0 or smsc:match("usb not ready") then
				return_code.code = sms_error
			end
			local pdu_data = encode_pdu(smsc, phone_num,sms_msg)
			if pdu_data then
				if smsstorage_data and smsstorage_data.used and smsstorage_data.total then
					last_space=tonumber(smsstorage_data.total)-tonumber(smsstorage_data.used)
					nixio.syslog("err","sms space:"..last_space.." sendcout:"..#pdu_data)
				end

				if #pdu_data > last_space then
					multi_result=sms_errorspace
					nixio.syslog("err","sms space not enough")
				else
					for i,pdu_item in ipairs(pdu_data) do
						local one_sms_result = {}
						nixio.syslog("err","pdu:"..pdu_item.pdu)
						nixio.syslog("err","pdu len:"..pdu_item.lens)
						one_sms_result = util.ubus("smsd"..name, "record",{len=tonumber(pdu_item.lens),msg=pdu_item.pdu}) or {code=sms_noresult,index="",timestamp=os.time()}
						
						if not one_sms_result.code then
							one_sms_result.code = sms_noresult
						end
						if tonumber(one_sms_result.code) ~= 0 then
							if tonumber(one_sms_result.code) == sms_errorspace then
								multi_result=sms_errorspace
							else
								multi_result=-1
							end
						else
							multi_result=0
						end
						return_code.item[#return_code.item + 1] = one_sms_result
					end
				end
			end
			return_code.code = multi_result
		end		
	end
	return return_code
end

function sms_resend(resend_id,channel)
	local name = channel or ""
	local ifname = cellular_default
	if name == cellular_default then
		name=""
	end
    if channel and #channel > 0 then
        ifname = tostring(channel)
    end
	local return_code = {code=sms_noresult}
	if resend_id and #resend_id>0 then
		if check_nrfamily_if(ifname) then
			local app_result = app_sms_data(ifname,{action="send",index=tonumber(resend_id)})
			app_result = cjson.decode(app_result) or {}
			return_code.code = app_result.code or sms_noresult
		else
			return_code = util.ubus("smsd"..name, "record",{index=tonumber(resend_id)}) or {code=sms_noresult}
		end
	end
	if not return_code.code then
		return_code.code = sms_noresult
	end
	return return_code
end

function sms_force_ims(force_data)
	uci = uci.cursor()
	local return_code = {code=0}

	if force_data and #force_data>0 then
		local cur_force_ims = uci:get("cpecfg","config","force_ims") or ""
		if cur_force_ims ~= force_data then
			uci:set("cpecfg","config","force_ims",force_data)
			uci:commit("cpecfg")
			util.exec("ifup "..cellular_default)
		end
	end
	return return_code
end

function support_multi_system()
	local board = util.ubus("system", "board") or {board_name = ""}
	local result = ""

	if fs.access("/usr/bin/sysupgrade-opensource") then
		if board.board_name:match("NAND") then
			result = util.exec("cat /proc/mtd|grep ubi_2nd")
		elseif board.board_name:match("EMMC") or board.board_name:match("EPHY") then
			result = util.exec("blkid -t PARTLABEL=kernel_2nd -o device|xargs -r printf")
		end

		if result ~= "" then
			return true
		end
	end

	return false
end

function get_wifi_region()
	local cur = uci.cursor()
	local country = cur:get("oem", "board", "country") or "CN"
	local country_regions = {
		CN = "CN",
		US = "FCC",
		CA = "FCC",
		DE = "CE",
		FR = "CE",
		GB = "CE",
		IT = "CE",
		ES = "CE",
		NL = "CE",
		BE = "CE",
		AT = "CE",
		CH = "CE",
		CZ = "CE",
		DK = "CE",
		FI = "CE",
		GR = "CE",
		HU = "CE",
		IE = "CE",
		LU = "CE",
		LT = "CE",
		LV = "CE",
		MT = "CE",
		PL = "CE",
		PT = "CE",
		RO = "CE",
		SK = "CE",
		SI = "CE",
		SE = "CE",
		JP = "JP",
		KR = "KR",
		ID = "ID"
	}

	return country_regions[country] or "CN"
end

function with_battery()
	if fs.access("/usr/sbin/wifisleep") then
		local no_battery = util.exec("bdinfo -g nobattery")
		if not no_battery or #no_battery == 0 then
			no_battery="0"
		end

		return no_battery == "0"
	end
	return false
end

function get_wifi_encryption()
	local cur = uci.cursor()
	local wifi_encryption_extra = cur:get("oem", "feature", "wifi_encryption_extra") or "0"
	local support_flag={extra=false,stand=true,ppsk=false,sae=false,kprsa=false}
	local wifi_encryption_custom = cur:get("oem", "feature", "wifi_encryption_custom")
	--local wifi_encryption_custom = "none psk2 psk-mixed"
	local custom_arr = nil
	local un_encrlist = {
		{"none", lng.translate("Open"),"stand"},
		{"wep-open", lng.translate("WEP"),"extra"},
		{"psk", lng.translate("WPA-Personal"),"extra"},
		{"psk2", lng.translate("WPA2-Personal"),"stand"},
		{"psk-mixed", lng.translate("WPA/WPA2-Personal"),"stand"},
		{"sae", lng.translate("WPA3-personal"),"stand sae"},
		{"sae-mixed", lng.translate("WPA2/WPA3-Personal"),"stand sae"},
		{"wpa", lng.translate("WPA-Enterpise"),"extra"},
		{"wpa2", lng.translate("WPA2-Enterpise"),"extra"},
		{"wpa-mixed", lng.translate("WPA/WPA2-Enterpise"),"extra"},
		{"ppsk", lng.translate("Personal Password"),"ppsk"},
		{"kprsa", lng.translate("Private"),"kprsa"}
	}
	local target_encrlist = {}
	if wifi_encryption_extra == "1" then
		support_flag["extra"] = true
	end
	if support_feature("kprsa") then
		support_flag["kprsa"] = true
	end
	if support_ppsk() then
		support_flag["ppsk"] = true
	end
	if support_sae() then
		support_flag["sae"] = true
	end
	if wifi_encryption_custom and #wifi_encryption_custom then
		support_flag["extra"] = true
		custom_arr = util.split(wifi_encryption_custom, " ")
	end
	for i = 1, #un_encrlist do
		local item = un_encrlist[i]
		local tag = util.split(item[3], " ")
		local support = true
		for j=1,#tag do
			if not support_flag[tag[j]] then
				support = false
			end
		end
		if support then
			if custom_arr then
				for z=1,#custom_arr do
					if item[1] == custom_arr[z] then
						support_flag[item[1]] = true
						target_encrlist[#target_encrlist+1] = item
						break
					end
				end
			else
				support_flag[item[1]] = true
				target_encrlist[#target_encrlist+1] = item
			end

		end
	end
	return target_encrlist,support_flag
end

function support_dualdnn()
	return get_platform() == "tdtech"
end

function ui_bat_support()
	local bat_support = util.exec("bdinfo -g bat_support")
	if not bat_support or #bat_support == 0 then
		bat_support="1"
	end

	return bat_support ~= "0" and bat_support ~= "2"
end

function get_client_switch(mac,type)
	local uci = uci.cursor()
	local section
	local switch = 1
	local key = "switch"
	if not mac then
		return
	end
	if type then
		key = type
	end
	mac = mac:upper()
	uci:foreach("access_ctl", "client",
				function(s)
					if s.mac and s.mac == mac then
						section = s[".name"]
						if s[key] then
							switch = tonumber(s[key])
						end
						return false
					end
				end
	)
	return switch
end

function set_client_qos(mac, switch)
	local uci = uci.cursor()
	local section
	if not mac then
		return
	end

	mac = mac:upper()
	uci:foreach("access_ctl", "client",
				function(s)
					if s.mac and s.mac == mac then
						section = s[".name"]
						return false
					end
				end
	)

	if section then
		if switch and switch ~= "" then
			uci:set("access_ctl", section, "qos", switch)
		else
			uci:delete("access_ctl", section)
		end

		uci:commit("access_ctl")
	else
		if switch then
			section = uci:add("access_ctl", "client")
			if section then
				uci:set("access_ctl", section, "qos", switch)
				uci:set("access_ctl", section, "mac", mac)
				uci:commit("access_ctl")
			end
		end
	end
end
function set_client_switch(mac, switch)
	local uci = uci.cursor()
	local section
	if not mac then
		return
	end

	mac = mac:upper()
	uci:foreach("access_ctl", "client",
				function(s)
					if s.mac and s.mac == mac then
						section = s[".name"]
						return false
					end
				end
	)

	if section then
		if switch and switch ~= "" then
			uci:set("access_ctl", section, "switch", switch)
			util.exec("access_ctl.sh -m "..mac.." -a "..switch.." >/dev/null")
		else
			util.exec("access_ctl.sh -m "..mac.." -a 1 >/dev/null")
			uci:delete("access_ctl", section)
		end

		uci:commit("access_ctl")
	else
		if switch then
			section = uci:add("access_ctl", "client")
			if section then
				uci:set("access_ctl", section, "switch", switch)
				uci:set("access_ctl", section, "mac", mac)
				uci:commit("access_ctl")
				util.exec("access_ctl.sh -m "..mac.." -a "..switch.." >/dev/null")
			end
		end
	end
end

function get_nettype_data(match_key)
	local net_arr = {}
	local net_type = get_network_type()
	for key,item in pairs(net_type) do
		if key:match(match_key) then
			net_arr[#net_arr + 1] = item
		end
	end
	return net_arr
end

function match_wired_nettype(match_val)
	local net_type = get_network_type()
	for key,item in pairs(net_type) do
		if match_val == item then
			if key:match("Wired") then
				return true
			end
			break
		end
	end
	return false
end
function match_cellular_nettype(match_val)
	local net_type = get_network_type()
	for key,item in pairs(net_type) do
		if match_val == item then
			if key:match("Cellular") or key:match("NBCPE") then
				return true,key
			end
			break
		end
	end
	return false,nil
end

function match_cellular_priority(match_val)
	local net_type = get_network_type()
	for key,item in pairs(net_type) do
		if match_val == item then
			if key:match("Priority") then
				return true
			end
			break
		end
	end
	return false
end

function match_overlap(match_val)
	local net_type = get_network_type()
	for key,item in pairs(net_type) do
		if match_val == item then
			if key:match("Overlap") then
				return true
			end
			break
		end
	end
	return false
end

function get_nettype_nbcpe(match_val)
	local net_type = get_network_type()
	for key,item in pairs(net_type) do
		if match_val == item then
			return key
		end
	end
	return ""
end

function get_wifi_vendor()
	local cur = uci.cursor()
	local vendor = cur:get("wireless", "radio0", "vendor") or "mtk"

	return vendor
end

function support_ac()
	local cur = uci.cursor()
	local ac = cur:get("luci", "module", "ac") or "0"

	return ac == "1"
end

function support_authvideo(feature)
	if fs.access("/www/luci-static/nradio/images/login.mp4") then
		return true
	end
	return false
end

function is_openwrt()
	return fs.access("/etc/openwrt_release")
end

function get_wans_data()
	local cur = uci.cursor()
	local cpe_cnt = count_cpe()
	local cpe_num = 0
	local wans_data = {}
	local networktype = cur:get("network", "globals", "net_prefer") or ""
	local cellular_flag,nettype_name = match_cellular_nettype(networktype)
	if cur:get("network", "wan") then
		local disabled = cur:get("network", "wan", "disabled") or "0"
		wans_data[#wans_data+1] = {name="wan",pos=1,disabled=disabled}
	end
	local priority = match_cellular_priority(networktype)
	if cpe_cnt > 0 then
		uci.cursor():foreach("network", "interface",
			function(s)
				if s.proto == "wwan" or s.proto == "tdmi" then
					cpe_num=cpe_num+1
					if cpe_num <= cpe_cnt then
						local item_data = {}
						item_data.name = s[".name"]
						item_data.disabled = s["disabled"] or "0"
						if s.mode == "odu" then
							if nettype_name == "WiredCellularNBCPEPriority" or nettype_name == "CellularNBCPEPriority" then
								item_data.pos = 30+cpe_num
							else
								item_data.pos = 10+cpe_num
							end
						else
							item_data.pos = 20+cpe_num
						end
						wans_data[#wans_data+1] = item_data
					end
				end
			end
		)
	end
	table.sort(wans_data, function(a, b) return a.pos < b.pos end)
	return wans_data
end

function ip6class_set(nat,open)
	local cur = uci.cursor()
	local class_name = {}
	local plat = get_platform()
	local lan_section = cur:get("network", "globals", "default_lan") or "lan"
	local wan6_section = cur:get("network", "globals", "default_wan6") or "wan6"
	cur:delete("network",lan_section,"ip6class")
	if open then
		if nat then
			cur:set("network",lan_section,"ip6class","local")
		else
			cur:foreach("network", "interface",
				function(s)
					local test = "open"
					if s.disabled == "1" then
						test = "close"
					end
					
					if (s.proto == "wwan" or s.proto == "tdmi") then
						if s.disabled ~= "1" then
							if plat == "tdtech" or plat == "quectel" then
								class_name[#class_name+1] = s[".name"]
							else
								class_name[#class_name+1] = s[".name"].."_6"
							end
							--nixio.syslog("err","ip6class 3 "..s[".name"])
						end
					elseif s[".name"] == wan6_section then
						if cur:get("network","nrswitch") then
							local disable_wan = cur:get("network","nrswitch", "disable_wan")
							if disable_wan ~= "1" then
								class_name[#class_name+1] = s[".name"]
								--nixio.syslog("err","ip6class 1 "..s[".name"].." disable_wan:"..disable_wan)
							end
						elseif s.disabled ~= "1" then
							class_name[#class_name+1] = s[".name"]
							--nixio.syslog("err","ip6class 2 "..s[".name"])
						end
					end		
				end
			)
			cur:set_list("network",lan_section,"ip6class",class_name)
		end
	end
	cur:commit("network")
end

function get_eauthenticity_image()
	local oem_pname = util.exec("bdinfo -g oem_pname") or ""
	local eauthenticity_path = "/www/luci-static/nradio/images/"
	local eauthenticity_stand_name = "eauthenticity.jpg"
	if oem_pname and #oem_pname > 0 then
		local eauthenticity_name = oem_pname.."_eauthenticity.jpg"
		local filename = eauthenticity_path..eauthenticity_name
		if fs.access(filename) then
			return eauthenticity_name
		end
	end
	return eauthenticity_stand_name
end

function get_cellular_prefix()
	if get_platform() == "quectel" and is_openwrt() then
		return "wan","wan0"
	end
	return "cpe","cpe"
end


function get_cellular_template()
	local request = disp.context.requestpath
	local model_id = request[5] or 1
	local menu = request[3] or ""
	if menu == "cpestatus" then
		tpl.render("nradio_adv/cpestatus", {model=model_id})
	elseif menu == "cpedevice" then
		tpl.render("nradio_adv/cpedevice", {model=model_id})
	elseif menu == "cpescan" then
		tpl.render("nradio_adv/cpescan", {model=model_id})
	elseif menu == "cpedata" then
		tpl.render("nradio_cpedata/cpedata", {model=model_id})
	elseif menu == "upgrade" then
		tpl.render("nradio_adv/cpe_upgrade", {model=model_id})
	elseif menu == "sms" then
		tpl.render("nradio_sms/index", {model=model_id})
	elseif menu == "apn" then
		tpl.render("nradio_adv/apn", {model=model_id})
	elseif menu == "freq" then
		tpl.render("nradio_adv/freq", {model=model_id})
	elseif menu == "sim" then
		tpl.render("nradio_status/sim", {model=model_id})
	elseif menu == "device" then
		tpl.render("nradio_status/device", {model=model_id})
	end
end
function get_cellular_last(name)
	local cellular_prefix,cellular_default = get_cellular_prefix()
	local cpe_section = cellular_default

	if name and #name > 0 then
		cpe_section = name 
	end
	local model_index = 1
	local model_str = ""
	local name_arr = util.split(cpe_section, cellular_prefix)
	if name_arr and #name_arr > 1 then
		model_str=name_arr[2]
		if model_str and (model_str) == "0" then
			model_str=""
		else
			if model_str and #model_str > 0 then
				model_index = tonumber(model_str)+1
			end
		end
	end
	return model_str,cpe_section,model_index
end
function get_cellular_data(name)
	local cpe_num = 0
	local cpe_cnt = 0
	local cellular_info = {cnt=0,nbcpe=false,celluar={}}
	local mode = uci.cursor():get("network", name, "mode")
	local count_cpe = count_cpe()
	local include = false
	uci.cursor():foreach("network", "interface",
		function(s)
			if s.proto == "wwan" or s.proto == "tdmi" and not s.ignore then
				local channel_info = s.share_channel
				if not channel_info or channel_info == s[".name"] then
					cpe_cnt = cpe_cnt +1
					local match = false
					local nbcpe = false
					if mode == "odu" then
						if s.mode == mode then							
							nbcpe = true
							match = true
						end
					else
						if s.mode ~= "odu" then
							match = true
						end
					end
					if cpe_cnt <= count_cpe then
						if match then
							local item_data = {}
							if nbcpe then
								cellular_info.nbcpe = true
							end
							if name == s[".name"] then
								include = true
							end
							item_data.name = s[".name"]
							cpe_num=cpe_num+1
							cellular_info.cnt = cellular_info.cnt + 1
							item_data.index = cpe_num
							cellular_info.celluar[#cellular_info.celluar+1] = item_data							
						end
					end
				end	
			end
		end
	)
	if not include then
		local item_data = {}
		item_data.name = name
		item_data.index = 1
		if mode == "odu" then
			cellular_info.nbcpe = true			
		end
		cellular_info.cnt = 1
		cellular_info.celluar = {}
		cellular_info.celluar[#cellular_info.celluar+1] = item_data
	end
	table.sort(cellular_info.celluar, function(a, b) return a.index < b.index end)
	return cellular_info
end

function get_cellular_list(name)
	local cpe_num = 0
	local cpe_cnt = 0
	local cellular_info = {cnt=0,celluar={}}
	local count_cpe = count_cpe()
	local include = false
	local nbpce_index = 0
	local cellular_index = 0
	uci.cursor():foreach("network", "interface",
		function(s)
			if s.proto == "wwan" or s.proto == "tdmi" and not s.ignore then
				local channel_info = s.share_channel
				if not channel_info or channel_info == s[".name"] then
					cpe_cnt = cpe_cnt +1
					local nbcpe = false
					local match = false
					local cur_index = 0
					if s["mode"] == "odu" then						
						nbcpe = true
						cur_index = nbpce_index
						nbpce_index=nbpce_index+1
					else
						cur_index = cellular_index
						cellular_index=cellular_index+1
					end
					if cpe_cnt <= count_cpe then
						local item_data = {}
						item_data.cur_index = cur_index
						if nbcpe then
							item_data.nbcpe = true
						end
						if name == s[".name"] then
							item_data.match = true
							include = true
						end
						item_data.name = s[".name"]
						cpe_num=cpe_num+1
						cellular_info.cnt = cellular_info.cnt + 1
						item_data.index = cpe_num
						cellular_info.celluar[#cellular_info.celluar+1] = item_data							
					end
				end	
			end
		end
	)
	if not include then
		cellular_info[1].match = true
	end
	table.sort(cellular_info.celluar, function(a, b) return a.index < b.index end)
	return cellular_info
end

function get_cellular_menu(name)
	local uci = uci.cursor()
	local count_cpe = count_cpe()
	local model_str,cpe_section = get_cellular_last(name)
	local sim_section="sim"..model_str
	local max = tonumber(uci:get("cpesel", sim_section, "max") or 1)
	local mode = uci:get("network",cpe_section,"mode")
	local cpecfg_ctl = uci:get("luci","module","cpecfg") or "1"
	local support_vsim = support_vsim(cpe_section)
	local support_sms = support_ims(cpe_section)

	local support_earfcn5 = uci:get("network",cpe_section,"earfcn5")
	local support_earfcn4 = uci:get("network",cpe_section,"earfcn4")
	local support_lock_freq = support_lock_freq(cpe_section)

	local cpecfg_pdp = true
	local default_support = true
	local plat = get_platform()
	if count_cpe == 0 then
		default_support = false
		support_sms = false
	end
	local sub_menu_info = {
		switch = {
			language = lng.translate("SIM Switch"),
			match = true,
			index = 1,
			name = "switch",
			support = default_support
		},
		cpelock = {
			language = lng.translate("CellularLockTitle"),
			match = false,
			index = 2,
			name = "cpelock",
			support = false
		},
		apn = {
			language = lng.translate("APNSettingTemplate"),
			match = false,
			index = 3,
			name = "apn",
			support = default_support
		},
		sms = {
			language = lng.translate("SMSTile"),
			match = false,
			index = 4,
			name = "sms",
			support = support_sms
		},
		cpecfg = {
			language = lng.translate("SIMRelate"),
			match = false,
			index = 5,
			name = "cpecfg",
			support = default_support
		},
		upgrade = {
			language = lng.translate("Cellular Upgrade"),
			match = false,
			index = 6,
			name = "upgrade",
			support = default_support
		},
		cpepin = {
			language = lng.translate("Cellular Pin"),
			match = false,
			index = 7,
			name = "cpepin",
			support = default_support,
			hidden = true
		}
	}
	if mode == "odu" or (plat ~= "mtk" and plat ~= "qca") then
		sub_menu_info.upgrade.support = false
	end
	if not fs.access("/usr/lib/lua/luci/controller/nradio_adv/cpe_upgrade.lua") then
		sub_menu_info.upgrade.support = false
	end

	if not fs.access("/usr/lib/lua/luci/controller/nradio_adv/sms.lua") then
		sub_menu_info.sms.support = false
	end
	if support_earfcn5 or support_earfcn4 or support_lock_freq then
		sub_menu_info.cpelock.support = true
	end
	if max == 1 and not support_vsim then
		sub_menu_info.switch.support = false
	end
	
	if cpecfg_ctl == "0" then
		sub_menu_info.cpecfg.support = false
	end

	if not support_cpecfg_pdp(cpe_section) then
		cpecfg_pdp = false
		sub_menu_info.apn.support = false
	end
	return sub_menu_info
end
function has_nbcpe()
	local count_cpe = count_cpe()
	for i = 0, count_cpe - 1 do
		local iface = (i == 0 and cellular_default or cellular_prefix..i)
		local iface_odu_mode = uci.cursor():get("network",iface, "mode") or ""
		if iface_odu_mode == "odu" then
			return iface
		end
	end
	return false
end
function has_nbcpe_only()
	local count_cpe = count_cpe()
	local exsit_nbcpe = false
	local exsit_cellular = false
	for i = 0, count_cpe - 1 do
		local iface = (i == 0 and cellular_default or cellular_prefix..i)
		local iface_odu_mode = uci.cursor():get("network",iface, "mode") or ""
		local iface_background = uci.cursor():get("network",iface, "background") or ""
		if iface_odu_mode == "odu" then
			exsit_nbcpe = true
		else
			if iface_background ~= "1" then
				exsit_cellular = true
			end
		end
	end
	if exsit_nbcpe and not exsit_cellular then
		return true
	else
		return false
	end
end
function check_nrfamily_if(cpe_section)
	local uci  = require "luci.model.uci"
	local cur = uci.cursor()
	local odu_model = cur:get("network", cpe_section, "odu_model") or ""
	if odu_model == "NRFAMILY" then
		return true
	end
	return false
end
function check_odu_if(cpe_section)
	local uci  = require "luci.model.uci"
	local cur = uci.cursor()
	local odu_mode = cur:get("network", cpe_section, "mode") or ""
	if odu_mode == "odu" then
		return true
	end
	return false
end
function get_nrfamily_id(cpe_section)
	local uci  = require "luci.model.uci"
	local cur = uci.cursor()
	local kpcpe_id = cur:get("network", cpe_section, "kpcpe_id") or nil
	return kpcpe_id
end
function get_apn_filename(cpe_section)
	local filename = "apn"
	if cpe_section and #cpe_section > 0 then
		if check_nrfamily_if(cpe_section) then
			local kpcpe_id = get_nrfamily_id(cpe_section)
			if kpcpe_id then
				filename = "kpcpe_"..kpcpe_id.."_apn"
			end
		end
	end
	return filename
end

function get_apn_profile(cpe_section)
	local cur = uci.cursor()
	local apn_list = {}
	local filename = get_apn_filename(cpe_section)
	cur:foreach(filename, "rule",
		function(s)
			apn_list[#apn_list+1] = {name=s[".name"]}
		end
	)
	return apn_list
end

function support_wifiauth()
	local uci = uci.cursor()
	if not fs.access("/usr/sbin/terminal_trackd") then
		return -1
	end
	local portal = uci:get("luci", "main", "portal") or "0"
	return tonumber(portal)
end
function set_wifiauth(wifiauth)
	local uci = uci.cursor()
	local diff = false
	if not wifiauth then
		return
	end
	wifiauth = tonumber(wifiauth)
	local cur_info = tonumber(uci:get("luci", "main", "portal") or "0")
	if wifiauth == 1 then
		if cur_info ~= wifiauth then
			uci:set("luci", "main", "portal", "1")
			diff = true
		end
	else
		if cur_info ~= wifiauth then
			uci:set("luci", "main", "portal", "0")
			diff = true
		end
	end
	if diff then
		uci:commit("luci")
		os.execute("/etc/init.d/terminal_trackd restart >/dev/null 2>/dev/null")
		os.execute("/etc/init.d/wifidogx restart >/dev/null 2>/dev/null")
		if wifiauth ~= 1 then
			os.execute("wifidogx -D >/dev/null 2>/dev/null")
		end
	end
end
local function generate_random(count,max,seed)
	local math = require "math"
	local numbers = {}
	math.randomseed(os.time()+seed)
	for i = 1,count do
		table.insert(numbers,math.random(max))
	end
	return numbers
end

local function last_caculate(data)
	local math = require "math"
	local last
	local odd_target = 0
	local even_target = 0

	if not data or #data ~= 14 then
		return nil
	end
	for i = 1,#data do

		if i%2 == 0 then
			local even = tonumber(data:sub(i,i))*2
			local single = math.floor(even/10)
			local double = even%10
			even_target = even_target + single + double
		else
			odd_target = odd_target + tonumber(data:sub(i,i))
		end
	end
	last = (even_target + odd_target)%10
	if last ~= 0 then
		last = 10 - last
	end
	return last
end

function genarate_cpeoptimizes_cfg(reset)
	local uci = require "luci.model.uci".cursor()
	local count = 6	
	local prefix = uci:get_list("cpeoptimizes","cpeoptimizes","prefix")
	local count_cpe = count_cpe()
	local num = 1*count_cpe
	local cpename_array = {}

	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" or s.proto == "tdmi" or s.proto == "netmanager" then
				if #cpename_array < count_cpe then
					cpename_array[#cpename_array+1] = s[".name"]
					nixio.syslog("err",s[".name"])
				end
			end
		end
	)

	uci:delete_all("cpeoptimizes", "rule")

	for i = 1 ,num do
		local data = ""
		local middle_buffer = table.concat(generate_random(count, 9,i))
		if prefix and #prefix > 0 then
			local prefix_buffer = table.concat(generate_random(1,#prefix,i))
			data = prefix[tonumber(prefix_buffer)]..middle_buffer
		end
		data = data..last_caculate(data)
		uci:set("cpeoptimizes",data,"rule")
		uci:set("cpeoptimizes",data,"check","0")
		for j = 1 ,count_cpe do
			if j>=i and i%j == 0 then
				uci:set("cpeoptimizes",data,"name",cpename_array[j])
				break
			end
		end		
	end
	uci:commit("cpeoptimizes")

	if reset then
		for j = 1 ,count_cpe do
			util.exec("ifup "..cpename_array[j].." >/dev/null 2>&1")
		end
	end
end

function switch_sim(sim_change,mode_change,vsim_change,cpe_section,sim_section)
	local plat = get_platform()
	local uci = uci:cursor()
	local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"

	app_write_cpesel(cpe_section,sim_section)
	app_write_cpecfg(cpe_section,cur_sim,cpe_section.."sim"..cur_sim)
	if sim_change == 1 or mode_change == 1 or vsim_change == 1 then
		if plat == "quectel" and not is_openwrt() then
			fork_exec("/etc/init.d/cpesel restart>/dev/null 2>&1")
		else
			util.exec("/etc/init.d/cpesel restart>/dev/null 2>&1")
		end
	end
	if mode_change == 1 or vsim_change == 1 then
		util.exec("/etc/init.d/wanchk restart>/dev/null 2>&1")
	end
	if vsim_change == 1 then
		os.execute("ubus call network.interface notify_proto \"{'interface':'"..cpe_section.."','action':5,'available':true}\" >/dev/null 2>&1")
	end

	if support_dualdnn() then		
		local custom_apn2_data = "0"
		local apn_cfg2_info = uci:get("cpecfg", cpe_section.."sim"..cur_sim, "apn_cfg2") or ""
		local cur_mode = uci:get("cpesel", sim_section, "mode") or "0" 
		
		if #apn_cfg2_info > 0 then
			custom_apn2_data = uci:get("apn", apn_cfg2_info, "custom_apn") or "0"
		else
			custom_apn2_data = uci:get("cpecfg", cpe_section.."sim"..cur_sim, "custom_apn2") or "0"
		end
		if custom_apn2_data == "1" or cur_mode == "0" then
			uci:set("network", "cpe1", "disabled","0")
		else
			uci:set("network", "cpe1", "disabled","1")
		end
		uci:commit("network")
		util.exec("/etc/init.d/network reload >/dev/null 2>&1")
	end

	if sim_change ~= 1 then
		if plat == "quectel" and not is_openwrt() then
			fork_exec("/etc/init.d/network restart >/dev/null 2>&1")
		else
			util.exec("ifup "..cpe_section)
			if support_dualdnn() then
				util.exec("ifup cpe1 >/dev/null 2>&1")
			end
		end
	end
end

function get_terminal_list()
	local terminal = list_clients()
	local termianl_array = {}
	if terminal.client then
		for mac, item in pairs (terminal.client) do
			item.switch = get_client_switch(mac)
			termianl_array[#termianl_array+1]= item
		end
	end
	if #termianl_array == 0 then
		termianl_array[1] = {}
	end
	return termianl_array
end
function get_top_menu()
	local default_support = true

	local wan_support = false
	if has_wan_port() then
		wan_support = true
	end
	local wifi_support = false
	if has_own_wlan() then
		wifi_support = true
	end
	local cellular_support = false
	if has_cpe() then
		cellular_support = true
	end
	local menu_info = {
		index = {
			language = lng.translate("MenuHome"),
			match = false,
			index = 1,
			name = "index",
			url = "/cgi-bin/luci/nradio/system/overview",
			support = default_support
		},
		cellular = {
			language = lng.translate("MenuCPE"),
			match = false,
			index = 2,
			name = "cellular",
			url = "/cgi-bin/luci/nradio/cellular",
			support = cellular_support
		},
		wan = {
			language = lng.translate("MenuInternet"),
			match = false,
			index = 3,
			name = "wan",
			url = "/cgi-bin/luci/nradio/basic/wan",
			support = wan_support
		},
		wifi = {
			language = lng.translate("MenuWifi"),
			match = false,
			index = 4,
			name = "wifi",
			url = "/cgi-bin/luci/nradio/basic/wifi",
			support = wifi_support
		},
		client = {
			language = lng.translate("StatusClient"),
			match = false,
			index = 5,
			name = "client",
			url = "/cgi-bin/luci/nradio/system/client",
			support = default_support
		},
		advanced = {
			language = lng.translate("MenuAdvanced"),
			match = false,
			index = 6,
			name = "advanced",
			url = "/cgi-bin/luci/nradio/advanced",
			sub_menu = {},
			support = default_support
		}
	}
	local t_category = 'nradioadv'
	local t_cattree  = disp.node(t_category)
	local t_childs = disp.node_childs(t_cattree)
	local i, r
	local radio_menu_node = {}
	local wan_menu_node = {}
	local cattree  = disp.node("nradio")
	local count_cpe = count_cpe()
	if cattree and cattree.nodes['basic'] then
		if cattree.nodes['basic'].nodes['wifi'] then
			radio_menu_node = cattree.nodes['basic'].nodes['wifi']
		end
		if cattree.nodes['basic'].nodes['wan'] then
			wan_menu_node = cattree.nodes['basic'].nodes['wan']
		end
	end

	if radio_menu_node.nodes and radio_menu_node.nodes['advanced'] and radio_menu_node.nodes['advanced']._menu_selected then
		menu_info.wifi.match = true
	elseif radio_menu_node._menu_selected then
		menu_info.wifi.match = true
	end
	if wan_menu_node._menu_selected then
		menu_info.wan.match = true
	end

	if cattree.nodes['client']._menu_selected then
		menu_info.client.match = true
	end

	if cattree.nodes['status']._menu_selected then
		menu_info.index.match = true
	end
	if cattree.nodes['cellular'] and cattree.nodes['cellular']._menu_selected then
		local request = disp.context.requestpath
		local model_str,cpe_section = get_cellular_last(request[5])
		local mode = uci.cursor():get("network", cpe_section, "mode")
		if mode == "odu" or request[3] == "cpedata" then
			if count_cpe ~= 1 or request[3] == "cpedata" then
				menu_info.cellular.match = false
				menu_info.advanced.match = true
			else
				menu_info.cellular.match = true
			end
		else
			menu_info.cellular.match = true
		end		
	end

	if cattree.nodes['advanced']._menu_selected 
	or (cattree.nodes['ppsk'] and cattree.nodes['ppsk']._menu_selected) 
	or (cattree.nodes['cpestat'] and cattree.nodes['cpestat']._menu_selected) 
	or (cattree.nodes['mesh'] and cattree.nodes['mesh']._menu_selected ) 
	or (cattree.nodes['acl'] and cattree.nodes['acl']._menu_selected ) 
	or cattree.nodes['basic'].nodes['lan']._menu_selected 
	or t_cattree._menu_selected then
		menu_info.advanced.match = true
	end
	local menu_index = 0
	for i, r in ipairs(t_childs) do
		local t_nnode = t_cattree.nodes[r]
		local t_grandchildren = disp.node_childs(t_nnode)
		local x, y
		local t_count = 0
		local submenu = nil		
		if #t_grandchildren ~= 0 then
			local index = 0
			menu_index = menu_index+1
			for x, y in ipairs(t_grandchildren) do
				local tt_nnode = t_nnode.nodes[y]
				local t_href = util.pcdata(disp.build_url() .. t_category .. "/" .. r .. "/" .. y .. (tt_nnode.query and http.build_querystring(tt_nnode.query) or ""))
				local t_show = tt_nnode.show or false
				local t_title = util.pcdata(util.striptags(lng.translate(t_nnode.title)))
				local route = nil
				if tt_nnode.full then
					route = tt_nnode.full:gsub("/", ".")
				end
				if route and nixio.fs.access("/tmp/appcenter/luci/"..route) then
					t_show = false
				end
				if t_show then
					t_count = t_count + 1					
					index = index+1
					if t_count == 1 then
						submenu = {language=t_title,match = false,index = menu_index,name = r,url="",support=true,sub_menu={}}
						menu_info.advanced.sub_menu[r] = submenu
						if t_nnode._menu_selected 
						or (r == "network" and cattree.nodes['basic'].nodes['lan']._menu_selected) 
						or (r == "wireless" and (cattree.nodes['acl']._menu_selected 
						or (cattree.nodes['ppsk'] and cattree.nodes['ppsk']._menu_selected) 
						or (cattree.nodes['mesh'] and cattree.nodes['mesh']._menu_selected))) 
						or (r == "cellular" and ((cattree.nodes['cpestat'] and cattree.nodes['cpestat']._menu_selected) )) then
							submenu.match = true
						end
					end
					local tt_title = util.pcdata(util.striptags(lng.translate(tt_nnode.title)))
					local sub_sub_item = {language=tt_title,match = false,index = index,name = y,url=t_href,support=true}
					submenu.sub_menu[y] = sub_sub_item
					if tt_nnode._menu_selected
					 or (y == "lan" and cattree.nodes['basic'].nodes['lan']._menu_selected) 
					 or (y == "acl" and cattree.nodes['acl']._menu_selected) 
					 or (y == "ppsk" and (cattree.nodes['ppsk'] and cattree.nodes['ppsk']._menu_selected)) 
					 or (y == "mesh" and (cattree.nodes['mesh'] and cattree.nodes['mesh']._menu_selected)) 
					 or (y == "cpestat" and (cattree.nodes['cpestat'] and cattree.nodes['cpestat']._menu_selected)) then
						sub_sub_item.match = true
					end
				end				
			end
		end
	end
	local sort_menu_info = {}
	local index = 1
	for key,item in pairs(menu_info) do
		if item.support then
			if item.sub_menu then
				local sub_menu_info = {}
				local sub_index = 1
				for sub_key,sub_item in pairs(item.sub_menu) do
					if sub_item.support then
						local sub_sub_menu_info = {}
						local sub_sub_index = 1
						if sub_item.sub_menu then
							for sub_sub_key,sub_sub_item in pairs(sub_item.sub_menu) do
								if sub_sub_item.support then


									
									sub_sub_menu_info[sub_sub_index] = sub_sub_item
									sub_sub_index=sub_sub_index+1
								end
							end
							if #sub_sub_menu_info > 0 then
								table.sort(sub_sub_menu_info, function(a, b) return a.index < b.index end)
							end
							sub_item.sub_menu = sub_sub_menu_info
						end						

						sub_menu_info[sub_index] = sub_item
						sub_index=sub_index+1
					end
				end
				if #sub_menu_info > 0 then
					table.sort(sub_menu_info, function(a, b) return a.index < b.index end)
				end
				item.sub_menu = sub_menu_info
			end
			sort_menu_info[index] = item
			index=index+1
		end
	end
	if #sort_menu_info > 0 then
		table.sort(sort_menu_info, function(a, b) return a.index < b.index end)
	end

	return sort_menu_info
end

function get_sim_company(model,sim_id)
	local nr = require "luci.nradio"

	local isp_info = ""
	local cpestatus = util.ubus("infocd", "cpestatus")
	if cpestatus then
		if cpestatus.result and #cpestatus.result then
			for _,v in ipairs(cpestatus.result) do
				if v.status.name == model then
					if v.status.imsi and #v.status.imsi > 0 then
						isp_info = genarate_plmn_company(v.status.imsi:sub(1,5))
					end

					if isp_info == "none" then
						isp_info = ""
					end
				end
			end
		end
		return isp_info
	end
	return ""
end
function get_cellular_earfcn(model,sim_id)
	local nr = require "luci.nradio"
	local uci = uci:cursor()
	local return_info = {cfg={nr={EARFCN="",PCI="",BAND=""},lte={EARFCN="",PCI="",BAND=""}},status={MODE="",EARFCN="",PCI="",BAND="",SINR="",LAC="",CELL="",RSRP=""},neighbour={}}
	local isp_info = ""
	local cpecfg_info = {}
	if model and sim_id then
		local cpecfg_section=model.."sim"..sim_id
		cpecfg_info = uci:get_all("cpecfg", cpecfg_section) or {}
	end
	return_info.cfg.nr.EARFCN=cpecfg_info.earfcn5 or ""
	return_info.cfg.nr.PCI=cpecfg_info.pci5 or ""
	return_info.cfg.nr.BAND=cpecfg_info.band5 or ""
	return_info.cfg.lte.EARFCN=cpecfg_info.earfcn4 or ""
	return_info.cfg.lte.PCI=cpecfg_info.pci4 or ""
	return_info.cfg.lte.BAND=cpecfg_info.band4 or ""

	local cpestatus = util.ubus("infocd", "cpestatus")
	if cpestatus then
		if cpestatus.result and #cpestatus.result then
			for _,v in ipairs(cpestatus.result) do
				if v.status.name == model then
					if v.status.mode:match("NR") then
						local lac_info = v.status.tac
						if not lac_info or #lac_info == 0 then
							lac_info = v.status.lac or ""
						end
						return_info.status.MODE="5"
						return_info.status.EARFCN=v.status.earfcn or ""
						return_info.status.PCI=v.status.pci or ""
						return_info.status.BAND=v.status.band or ""
						return_info.status.SINR=v.status.sinr or ""
						return_info.status.LAC=lac_info
						return_info.status.CELL=v.status.cell or ""
						return_info.status.RSRP=v.status.rsrp or ""

					end
					if v.status.mode == "LTE" then
						local lac_info = v.status.tac
						if not lac_info or #lac_info == 0 then
							lac_info = v.status.lac or ""
						end
						return_info.status.MODE="4"
						return_info.status.EARFCN=v.status.earfcn or ""
						return_info.status.PCI=v.status.pci or ""
						return_info.status.BAND=v.status.band or ""
						return_info.status.SINR=v.status.sinr or ""
						return_info.status.LAC=lac_info
						return_info.status.CELL=v.status.cell or ""
						return_info.status.RSRP=v.status.rsrp or ""
					end
				end
			end
		end
	end
	neighbour = util.exec("cpetools.sh -i "..model.." -c neighbour")
	if neighbour and #neighbour > 0 then
		local info = cjson.decode(neighbour) or {}
		return_info.neighbour[#return_info.neighbour+1] = info["neighbour"] or {}
	end
	return return_info
end
function get_nrswitch_info()
	local uci  = require "luci.model.uci"
	local cur = uci.cursor()
	local ovlan = cur:get("network", "nrswitch", "ovlan") or ""
	local label = cur:get("network", "nrswitch", "label") or ""
	local networktype = cur:get("network", "globals", "net_prefer") or ""
	local nbcpe = cur:get("network", "globals", "nbcpe") or ""
	local result = {}
	if #networktype == 0 then
		if nbcpe == "1" then
			networktype="11"
		end
	end
	local port_num = 0
	local index = 0
	local port_arr = {}
	if #label > 0 then
		label = util.split(label, ' ')
	end
	local last_wan_port = -1
	for i = 1, #ovlan do
		local data=ovlan:sub(i, i)			
		if data:match("[WMLm]") then
			local port_info = {}
			port_num = port_num + 1
			port_info.port = i-1
			if (data == "W" or data == "M") and last_wan_port < i then
				last_wan_port = i - 1
			end
			index = index + 1
			local sort = index
			port_info.index = index
			if #label > 0 and index <= #label then
				if tonumber(label[index]) then
					sort = tonumber(label[index])
				end
				port_info.label = label[index]
			else
				port_info.label = index
			end
			port_info.type = data
			port_arr[tostring(sort)] = port_info
		end
	end
	result.networktype = networktype
	result.last_wan_port = last_wan_port
	result.port = port_arr
	return result
end
function save_lan_ip(ip)
	local diff = true
	local uci = uci:cursor()
	local lan_section = uci:get("network", "globals", "default_lan") or "lan"
	local ipv4addr = uci:get("network", lan_section, "ipaddr")

	if ip then
		if ip ~= ipv4addr then
			uci:set("network", lan_section, "ipaddr",ip)
			uci:commit("network")
			util.exec("/etc/init.d/network reload")
			ipv4addr = ip
			diff=true
		else
			diff=false
		end
	end

	if diff then
		if ipv4addr then
			local data = uci:get("dhcp", "@dnsmasq[0]", "address")
			local domain = uci:get("oem", "custom", "domain") or "nradio.cc"
			if data then
				for k,v in pairs(data) do
					if v:match(domain) then
						util.exec("uci del_list dhcp.@dnsmasq[0].address='" .. v .. "'")
						break
					end
				end
			end
			util.exec("uci add_list dhcp.@dnsmasq[0].address='/"..domain.."/" .. ipv4addr .. "'")
			util.exec("uci commit dhcp")
			util.exec("sync && sleep 1")
		end
		util.exec("/etc/init.d/dnsmasq reload")
		if fs.access("/usr/sbin/terminal_trackd") then
			fork_exec(function()
				if ipv4addr then
					util.exec("/etc/init.d/terminal_trackd restart >/dev/null 2>/dev/null")
					util.exec('iptables -t filter -F wifidog_servers')
					util.exec('iptables -t nat -F wifidog_servers')
					util.exec('iptables -t filter -A wifidog_servers -d '..ipv4addr..' -j ACCEPT')
					util.exec('iptables -t nat -A wifidog_servers -d '..ipv4addr..' -j ACCEPT')
				end
			end)
		end
		apply_guest()
	end
end

function kpcpectl_common(action,cpe_section,parameter_data,local_sync)
	local uci = uci:cursor()
	local return_val = nil
	local return_val_sync = nil
	if parameter_data and #parameter_data > 0 then
		nixio.syslog("err","kpcpe-ctl -i "..cpe_section.." -a "..action.." -p '"..parameter_data.."'")
		return_val = util.exec("kpcpe-ctl -i "..cpe_section.." -a "..action.." -p '"..parameter_data.."'")
		if local_sync then
			return_val_sync = util.exec("kpcpe-ctl -S -i "..cpe_section.." -a "..action.." -p '"..parameter_data.."'")
		end
	else
		nixio.syslog("err","kpcpe-ctl -i "..cpe_section.." -a "..action)
		return_val = util.exec("kpcpe-ctl -i "..cpe_section.." -a "..action)
		if local_sync then
			return_val_sync = util.exec("kpcpe-ctl -S -i "..cpe_section.." -a "..action)
		end
	end
	if return_val then
		nixio.syslog("err","return_val:"..return_val)
	end
	return return_val
end
function kpcpectl_sync(name)	
	local model_str,cpe_section = get_cellular_last(name)
	if #model_str == 0 and fs.access("/usr/sbin/kpcped")  then
		nixio.syslog("err","kpcpectl_sync")
		util.exec("ubus send kpcped.event")
	end
end
function app_write_cpesel(cpe_section,sim_section)
	local uci = uci:cursor()
	local is_nrfamily = check_nrfamily_if(cpe_section)
	local is_odu = check_odu_if(cpe_section)
	if is_nrfamily or is_odu then
		local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"
		local cur_mode = uci:get("cpesel", sim_section, "mode") or "0"
		local cur_adv = uci:get("cpesel", sim_section, "adv_sim") or "0"
		local cur_default = uci:get("cpesel", sim_section, "default")
		
		local parameter = {cur={},mode={},default={},adv_sim={}}
		local parameter_data =  nil
		parameter.cur[#parameter.cur+1] = tonumber(cur_sim)
		parameter.mode[#parameter.mode+1] = tonumber(cur_mode)
		parameter.adv_sim[#parameter.adv_sim+1] = tonumber(cur_adv)
		if cur_default then
			parameter.default[#parameter.default+1] = tonumber(cur_default)
		end

		parameter_data = cjson.encode(parameter)
		kpcpectl_common("cpesel",cpe_section,parameter_data,is_nrfamily)
	end
	kpcpectl_sync(cpe_section)
end
function app_write_cpecfg(cpe_section,sim_id,simcfg_section)
	local uci = uci:cursor()
	local is_nrfamily = check_nrfamily_if(cpe_section)
	local is_odu = check_odu_if(cpe_section)
	if is_nrfamily or is_odu then
		local mode = uci:get("cpecfg", simcfg_section, "mode") or ""
		local cpecfg_adv = uci:get_all("cpecfg", simcfg_section) or {}
		
		local parameter = {index="1",action=1,sim=tonumber(sim_id),mode="",adv={}}
		local parameter_data =  nil
		parameter.mode = mode
		parameter.adv = cpecfg_adv
		parameter_data = cjson.encode(parameter)
		kpcpectl_common("earfcn",cpe_section,parameter_data,is_nrfamily)
	end
	kpcpectl_sync(cpe_section)
end
function app_write_cpedata(cpe_section)
	local uci = uci:cursor()
	local is_nrfamily = check_nrfamily_if(cpe_section)
	local is_odu = check_odu_if(cpe_section)
	if is_nrfamily or is_odu then
		local cpecfg_adv = {}		
		local parameter = {index="1",action=1,adv={},type="all"}
		local parameter_data =  nil

		uci:foreach("cpecfg", "cpesim",
			function(s)
				if s[".name"]:match(cpe_section.."sim") then
					local sim_id = s[".name"]:match(cpe_section.."sim(%d*)")
					s["sim_id"] = sim_id
					cpecfg_adv[#cpecfg_adv+1]=s
				end
			end
		)

		parameter.adv = cpecfg_adv
		parameter_data = cjson.encode(parameter)
		kpcpectl_common("earfcn",cpe_section,parameter_data,is_nrfamily)
	end
end
function app_write_earfcn(cpe_section,sim_id,simcfg_section)
	local uci = uci:cursor()
	local is_nrfamily = check_nrfamily_if(cpe_section)
	local is_odu = check_odu_if(cpe_section)
	if is_nrfamily or is_odu then
		local earfreq_mode = uci:get("cpecfg", simcfg_section, "earfreq_mode") or ""
		local custom_freq = uci:get("cpecfg", simcfg_section, "custom_freq") or "0"
		local freq = uci:get("cpecfg", simcfg_section, "freq") or ""

		local earfcn5_mode = uci:get("cpecfg", simcfg_section, "earfcn5_mode") or ""
		local custom_earfcn5 = uci:get("cpecfg", simcfg_section, "custom_earfcn5") or "0"
		local earfcn5 = uci:get("cpecfg", simcfg_section, "earfcn5") or ""
		local pci5 = uci:get("cpecfg", simcfg_section, "pci5") or ""
		local band5 = uci:get("cpecfg", simcfg_section, "band5") or ""

		local earfcn4_mode = uci:get("cpecfg", simcfg_section, "earfcn4_mode") or ""
		local custom_earfcn4 = uci:get("cpecfg", simcfg_section, "custom_earfcn4") or "0"
		local earfcn4 = uci:get("cpecfg", simcfg_section, "earfcn4") or ""
		local pci4 = uci:get("cpecfg", simcfg_section, "pci4") or ""
		local band4 = uci:get("cpecfg", simcfg_section, "band4") or ""
		
		local parameter = {index="1",action=1,sim=tonumber(sim_id),band={},earfcns={}}
		local parameter_data =  nil

		parameter.band.freq = freq
		parameter.band.enabled = custom_freq
		parameter.earfreq_mode = earfreq_mode
		parameter.earfcns[#parameter.earfcns+1] = {enabled=custom_earfcn5,MODE="NR",EARFCN=earfcn5,PCI=pci5,BAND=band5,earfcn5_mode=earfcn5_mode}
		parameter.earfcns[#parameter.earfcns+1] = {enabled=custom_earfcn4,MODE="LTE",EARFCN=earfcn4,PCI=pci4,BAND=band4,earfcn4_mode=earfcn4_mode}
		parameter_data = cjson.encode(parameter)
		kpcpectl_common("earfcn",cpe_section,parameter_data,is_nrfamily)
	end
	kpcpectl_sync(cpe_section)
end
function sync_apn_cpecfg(cpe_section,max)
	local kpcpe_id = get_nrfamily_id(cpe_section)
	if kpcpe_id and #kpcpe_id > 0 then
		local cpecfg_file="kpcpe_"..kpcpe_id.."_cpecfg"
		local diff = false
		for i = 1, max do
			local each_cpecfg_section = cpe_section.."sim"..i
			local kpcpe_cpecfg_section = "cpesim"..i
			local each_apn_cfg = uci:get("cpecfg",each_cpecfg_section, "apn_cfg") or ""
			local each_apn_cfg2 = uci:get("cpecfg",each_cpecfg_section, "apn_cfg2") or ""

			local kpcpe_apn_cfg = uci:get(cpecfg_file,kpcpe_cpecfg_section, "apn_cfg") or ""
			local kpcpe_apn_cfg2 = uci:get(cpecfg_file,kpcpe_cpecfg_section, "apn_cfg2") or ""

			if each_apn_cfg ~= kpcpe_apn_cfg then
				if each_apn_cfg then
					uci:set(cpecfg_file,kpcpe_cpecfg_section, "cpesim")
					uci:set(cpecfg_file,kpcpe_cpecfg_section, "apn_cfg",each_apn_cfg)
				else
					uci:delete(cpecfg_file,kpcpe_cpecfg_section, "apn_cfg")
				end
				diff = true				
			end
			if each_apn_cfg2 ~= kpcpe_apn_cfg2 then
				if each_apn_cfg2 then
					uci:set(cpecfg_file,kpcpe_cpecfg_section, "cpesim")
					uci:set(cpecfg_file,kpcpe_cpecfg_section, "apn_cfg2",each_apn_cfg2)
				else
					uci:delete(cpecfg_file,kpcpe_cpecfg_section, "apn_cfg2")
				end
				diff = true				
			end
		end
		if diff then			
			uci:commit(cpecfg_file)
		end
	end
end
function reload_apn_used(name,action,cpecfg_section,from)
	local nr = require "luci.nradio"
	local uci  = require "luci.model.uci".cursor()
	local cellular_prefix,cellular_default = nr.get_cellular_prefix()
	local apn_cfg = ""
	local apn_cfg2 = ""

	if not name or #name == 0 then
		return
	end
	
	uci:foreach("cpesel", "cpesel",
		function(s)
			local model_str = s[".name"]:match("sim(%C+)") or ""
			local cpe_section = ""
			local sim_id = s["cur"] or "1"
			local max = tonumber(s["max"] or 1)
			if #model_str > 0 then
				cpe_section = cellular_prefix..model_str
			else
				cpe_section = cellular_default
			end

			for i = 1, max do
				local each_cpecfg_section = cpe_section.."sim"..i
				local each_apn_cfg = uci:get("cpecfg",each_cpecfg_section, "apn_cfg") or ""
				local each_apn_cfg2 = uci:get("cpecfg",each_cpecfg_section, "apn_cfg2") or ""

				if action == "del" and (not cpecfg_section or (each_cpecfg_section == cpecfg_section)) then
					if each_apn_cfg == name then
						uci:delete("cpecfg",each_cpecfg_section, "apn_cfg")
						util.exec("touch  /tmp/"..each_cpecfg_section.."_remove_apn")
					end
					if each_apn_cfg2 == name then
						uci:delete("cpecfg",each_cpecfg_section, "apn_cfg2")
						util.exec("touch  /tmp/"..each_cpecfg_section.."_remove_apn2")
					end
					uci:commit("cpecfg")
				end
				if i == tonumber(sim_id) then
					apn_cfg = each_apn_cfg
					apn_cfg2 = each_apn_cfg2
					if from ~= "NRFAMILY" and from ~= "LOCAL" then
						app_write_apn(cpe_section,s[".name"],each_cpecfg_section,name)						
					end
				end
			end
			if from ~= "NRFAMILY" and from ~= "LOCAL" then
				sync_apn_cpecfg(cpe_section,max)
			end
			if apn_cfg == name or apn_cfg2 == name then
				if apn_cfg2 == name and nr.support_dualdnn() then
					local custom_apn2_data = uci:get("apn", name, "custom_apn") or "0"
					if custom_apn2_data == "1" or s["mode"] == "0" then
						uci:set("network", "cpe1", "disabled","0")
					else
						uci:set("network", "cpe1", "disabled","1")
					end
					uci:commit("network")
					util.exec("/etc/init.d/network reload")
					if luci.nradio.get_platform() == "tdtech" then
						util.ubus("atserver", "set", {mod = "disconnect", idx = 2})
					end
				end
				util.exec("ifup "..cpe_section.." >/dev/null 2>&1")
			end
		end
	)
end
function app_write_apn(cpe_section,sim_section,simcfg_section,profile)
	local uci = uci:cursor()
	if check_nrfamily_if(cpe_section) then
		local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"
		local apn_cfg = uci:get("cpecfg", simcfg_section, "apn_cfg") or ""
		local kpcpe_id = get_nrfamily_id(cpe_section)
		local apn = ""
		local auth = ""
		local username = ""
		local password = ""
		local pdptype = ""
		local enabled = ""
		local apn_info = uci:get_all("kpcpe_"..kpcpe_id.."_apn", profile)
		local action="0"

		if kpcpe_id then
			apn_info = uci:get_all("kpcpe_"..kpcpe_id.."_apn", profile)
		else
			apn_info = uci:get_all("apn", profile)
		end
		if apn_info then
			apn = apn_info.apn or ""
			username = apn_info.username or ""
			auth = apn_info.auth or ""
			password = apn_info.password or ""
			pdptype = apn_info.pdptype or ""
			enabled = apn_info.custom_apn or ""
			action="1"
		end

		local parameter = {index="1",action=action,sim=tonumber(cur_sim),apn=apn,username=username,password=password,auth=auth,pdptype=pdptype,enabled=enabled,profile=profile,sim_profile=apn_cfg}
		local parameter_data =  nil
		parameter_data = cjson.encode(parameter)
		kpcpectl_common("apn",cpe_section,parameter_data)
	end
	kpcpectl_sync(cpe_section)
end
function app_write_sms(cpe_section,simid,simcfg_section)
	local uci = uci:cursor()
	if check_nrfamily_if(cpe_section) then
		local force_ims = uci:get("cpecfg", simcfg_section, "force_ims") or "0"
		local parameter = {index="1",enabled=force_ims,sim=tonumber(simid),action="modify"}
		local parameter_data =  nil
		parameter_data = cjson.encode(parameter)
		kpcpectl_common("sms",cpe_section,parameter_data)
	end
	kpcpectl_sync(cpe_section)
end
function app_scan_cellinfo(cpe_section,type,force)
	local parameter = {type=type,force=force}
	local parameter_data =  nil
	parameter_data = cjson.encode(parameter)
	return kpcpectl_common("neighbour",cpe_section,parameter_data)	
end

function app_sms_data(cpe_section,para_data)
	local uci = uci:cursor()
	local parameter_data =  nil
	parameter_data = cjson.encode(para_data)
	return kpcpectl_common("sms",cpe_section,parameter_data)
end

function set_n79_relate(name)
	local uci = uci.cursor()
	local model_str,cpe_section = get_cellular_last(name)
	local sim_section="sim"..model_str

	local cur_sim = uci:get("cpesel", sim_section, "cur") or "1"
	local cpecfg_section = cpe_section.."sim"..cur_sim
	local mode_info = uci:get("cpecfg", cpecfg_section, "mode") or ""
	local custom_freq_info = uci:get("cpecfg", cpecfg_section, "custom_freq") or ""		
	local earfreq_mode_info = uci:get("cpecfg", cpecfg_section, "earfreq_mode") or ""
	
	local nr_band_match = false
	local nr_earfcn_match = false

	local custom_earfcn5_info = uci:get("cpecfg", cpecfg_section, "custom_earfcn5") or ""
	local band5_info = uci:get("cpecfg", cpecfg_section, "band5") or ""
	
	if mode_info ~= "lte" and custom_earfcn5_info == "1" and band5_info == "79"  then
		nr_earfcn_match = true
		nixio.syslog("err","nr_earfcn_match match")
	end

	nixio.syslog("err","")

	if mode_info ~= "lte" and earfreq_mode_info == "band" and custom_freq_info == "1"  then
		local freq_info = uci:get("cpecfg", cpecfg_section, "freq") or ""
		local freq_info_arr = util.split(freq_info, ',')
		if freq_info_arr[1] then
			local freq_nr_arr = util.split(freq_info_arr[1], '-')
			if freq_nr_arr and #freq_nr_arr == 2 and freq_nr_arr[2] == "79" then
				nixio.syslog("err","nr_band_match match")
				nr_band_match = true
			end
		end
	end

	local target_channel = "149"
	local target_htmode = "VHT80"
	local channel = uci:get("cloudd","g1radio","channel_radio1")
	local htmode = uci:get("cloudd","g1radio","htmode_radio1")
	local channel_back = uci:get("cloudd","g1","channel_radio1_back")
	local htmode_back = uci:get("cloudd","g1","htmode_radio1_back")
	local change = false
	if nr_band_match or nr_earfcn_match then
		if channel ~= "wireless.radio1.channel="..target_channel or htmode ~= "wireless.radio1.htmode="..target_htmode then
			if channel then
				uci:set("cloudd","g1","channel_radio1_back",channel)
			end
			if htmode then
				uci:set("cloudd","g1","htmode_radio1_back",htmode)
			end
			uci:set("cloudd","g1radio","channel_radio1","wireless.radio1.channel="..target_channel)
			uci:set("cloudd","g1radio","htmode_radio1","wireless.radio1.htmode="..target_htmode)
			uci:commit("cloudd")
			change = true
		end
	else
		if (channel_back and channel ~= channel_back) or (htmode_back and htmode ~= htmode_back) then
			if channel_back then
				uci:set("cloudd","g1radio","channel_radio1",channel_back)
			end
			if htmode_back then
				uci:set("cloudd","g1radio","htmode_radio1",htmode_back)
			end
			uci:commit("cloudd")
			change = true
		end
	end
	if change then
		fork_exec("/usr/bin/lua /usr/lib/lua/cloudd/sync_cloudd.lua >/dev/null 2>&1")
	end
end
function deal_service(data)
	local uci = uci.cursor()
	local json_data = {code=-1}
	if data and data.name then
		json_data.name = data.name
		if not fs.access("/etc/init.d/".. data.name) then
			return json_data
		end
		json_data.code = 0
		local config = uci:get(data.name, "config")			
		local config2 = uci:get(data.name, "basic")
		if data.enabled then
			json_data.enabled = data.enabled
			if config then
				uci:set(data.name, "config","enable",data.enabled)
				uci:commit(data.name)
			end
			if config2 then
				uci:set(data.name, "basic","enabled",data.enabled)
				uci:commit(data.name)
			end
			if data.enabled == 1 then
				util.exec("/etc/init.d/".. data.name.." enable")
				fork_exec("sleep 2;/etc/init.d/".. data.name.." restart >/dev/null")
			else
				if not config and not config2 then
					util.exec("/etc/init.d/".. data.name.." disable")
				end
				fork_exec("sleep 2;/etc/init.d/".. data.name.." stop >/dev/null")
			end	
		else
			local enable_cfg = nil
			if config then
				enable_cfg = uci:get(data.name, "config","enable")
			end
			if config2 then
				enable_cfg = uci:get(data.name, "basic","enabled")
			end
			local info = util.exec("ls /etc/rc.d/ -all|awk -F' ' '{print $9}'|grep -e '^S[0-9]*"..data.name.."$'") or ""
			if info and #info > 0 then
				if (config or config2) and enable_cfg~= "1" then
					json_data.enabled = 0
				else
					json_data.enabled = 1
				end
				
			else
				json_data.enabled = 0
			end
		end
	end
	return json_data
end
function password_valid(pwd)
	if not pwd or type(pwd) ~= "string" or #pwd <= 0 then
		return false
	end
	local i = 1
	while true do
		local curByte = string.byte(pwd, i)
		if curByte < 33 or curByte > 126 or curByte == 92 or curByte == 34 or curByte == 39 then
			return false
		end

		i = i + 1
		if i > #pwd then
			break
		end
	end
	return true
	end
function set_password_info(pwd)
	local cur = uci:cursor()
	local ret = 0;
	local pwd_orig = ""

	if not pwd or #pwd <5 or #pwd > 64 then
		return 1
	end
	if not password_valid(pwd) then
		return 1
	end

	pwd_orig = cur:get("system","@system[0]","password")

	if pwd_orig == pwd then    
		return 2
	end
	cur:set("system","@system[0]","password",pwd)
	cur:commit("system")
	util.exec("rm /etc/passwd+ >/dev/null 2>&1;rm /etc/shadow+ >/dev/null 2>&1;")
	util.exec("(echo '"..pwd.."';sleep 1;echo '"..pwd.."') |passwd -a md5 'root' >/dev/null 2>&1")
	return ret
end
function is_low_cpu()
	local target = util.exec("cat /etc/openwrt_release|grep DISTRIB_TARGET|xargs printf")
	if target then 
		local info = target:match("%C+=(%C+)")
		if info and info:match("mt7628$") or info:match("mt7620$") then
			return true
		end
	end
	return false
end

function get_base_data(data)
	local uci = require "luci.model.uci".cursor()
	local index = data.index or "1"
	local cpe_index = 1
	local cpesel_name = "sim"
	local cpe_name=""
	local cpecfg_filename = "cpecfg"
	local cpesel_filename = "cpesel"
	local network_filename = "network"
	local base_data ={network_file=network_filename,cpecfg_file=cpecfg_filename,cpesel_file=cpesel_filename,cpecfg_name="",sim_diff=0,index=index,now_sim="",cpe_name=""}

	if data.from == "LOCAL" and data.device_id then
		base_data.cpecfg_file="kpcpe_"..data.device_id.."_"..cpecfg_filename
		base_data.cpesel_file="kpcpe_"..data.device_id.."_"..cpesel_filename
		base_data.network_file="kpcpe_"..data.device_id.."_"..network_filename
		base_data.only_save = true
		if not fs.access("/etc/config/".. base_data.cpecfg_file) then
			util.exec("touch /etc/config/".. base_data.cpecfg_file)
		end
		if not fs.access("/etc/config/".. base_data.cpesel_file) then
			util.exec("touch /etc/config/".. base_data.cpesel_file)
		end
	end

	if tonumber(index) > 1 then
		cpesel_name="sim"..(tonumber(index)-1)
	end	

	local now_sim = uci:get(base_data.cpesel_file, cpesel_name, "cur") or "1"
	if data.sim and (tonumber(data.sim) ~= tonumber(now_sim)) then
		base_data.sim_diff=1
	end
	base_data.now_sim = now_sim

	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" and (not s.share_channel or s.share_channel == s[".name"]) then
				if tonumber(index) == cpe_index then
					base_data.cpe_name=s[".name"]
					base_data.cpecfg_name=s[".name"].."sim"..tonumber(data.sim or base_data.now_sim)
				end
				cpe_index=cpe_index+1
			end
		end
	)
	return base_data
end

cellular_prefix,cellular_default = get_cellular_prefix()
