-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.reset", package.seeall)
local uci = require "luci.model.uci".cursor()
local lan_section = uci:get("network", "globals", "default_lan") or "lan"
local client_ip = luci.http.getenv("REMOTE_ADDR") or ""
local function check_3rd_valid(image)
	local uci = require "luci.model.uci".cursor()
	local developer = uci:get("cloudd", "config", "developer") or "0"

	if developer ~= "1" then
		return false
	end

	return true
end

function index()
	entry({"admin", "system", "reset"},call("action_index"),_("Backup / Flash Firmware"), 45, true)
	entry({"admin", "system", "reset", "call"}, call("action_reset"), nil, nil, true)
	entry({"admin", "system", "reset", "backup"}, call("action_backup"), nil, nil, true)
	entry({"admin", "system", "reset", "restore"}, call("action_restore"), nil, nil, true)
	entry({"admin", "system", "reset", "upgrade"}, call("action_upgrade"), nil, nil, true)
	entry({"admin", "system", "reset", "upgrade_3rd_party"}, call("action_upgrade_3rd_party"), nil, nil, true)
	entry({"admin", "system", "reset", "switch_system"}, call("action_switch_system"), nil, nil, true)

	entry({"admin", "system", "reset", "rinfo"}, call("action_remote_info"), nil, nil, true)
	entry({"admin", "system", "reset", "rinfosize"}, call("action_remote_infosize"), nil, nil, true)	
	entry({"admin", "system", "reset", "rcheck"}, call("action_remote_check"), nil, nil, true)
	entry({"admin", "system", "reset", "rdownload"}, call("action_remote_download"), nil, nil, true)
	entry({"admin", "system", "reset", "rupgrade"}, call("action_remote_upgrade"), nil, nil, true)
	entry({"admin", "system", "reset", "rupgrade_async"}, call("action_remote_upgrade_async"), nil, nil, true)
	if luci.nradio.support_multi_system() then
		entry({"admin", "status", "Secondsystem"}, call("redirect_overview"), nil, nil, true).leaf = true
		entry({"admin", "system", "Secondsystem"}, call("redirect_overview"), nil, nil, true).leaf = true
	end
	page = entry({"nradioadv", "system", "reset"}, template("nradio_adv/reset"), _("UpgradeMenuTitle"), 10, true)
	page.icon = 'retweet-alt'
	page.show = true
end

function redirect_overview()
	luci.http.redirect(luci.dispatcher.build_url("nradio/system/overview"))
end
function ltn12_popen(command)
	local fdi, fdo = nixio.pipe()
	local pid = nixio.fork()

	if pid > 0 then
		fdo:close()
		local close
		return function()
			local buffer = fdi:read(2048)
			local wpid, stat = nixio.waitpid(pid, "nohang")
			if not close and wpid and stat == "exited" then
				close = true
			end

			if buffer and #buffer > 0 then
				return buffer
			elseif close then
				fdi:close()
				return nil
			end
		end
	elseif pid == 0 then
		nixio.dup(fdo, nixio.stdout)
		fdi:close()
		fdo:close()
		nixio.exec("/bin/sh", "-c", command)
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

		-- replace with target command
		nixio.exec("/bin/sh", "-c", command)
	end
end

function fork_call(func)
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

		if type(func) == "function" then
			func()
		end

		nixio.exec("/bin/echo", "done")
	end
end

function action_index()
	luci.template.render("nradio_adv/reset")
end

function action_reset()
	local uci = require "luci.model.uci".cursor()
	local dip = uci:get("network", lan_section, "def_ipaddr")

	nixio.syslog("err","WEB["..client_ip.."] reset")
	luci.template.render("nradio_adv/reset", {auto=1, dip=dip})
	fork_exec("sleep 1; echo y|firstboot && reboot")
end

function action_backup()
	local fs = require "nixio.fs"
	local is_quectel = fs.access("/bin/serial_atcmd") and true or false
	local reader
	nixio.syslog("err","WEB["..client_ip.."] backup")
	if is_quectel then
		os.execute("tar czvf /tmp/nradio_cfg.tar.gz -C /etc/config . >/dev/null 2>&1")
		reader = ltn12_popen("cat /tmp/nradio_cfg.tar.gz")
	else
		reader = ltn12_popen("sysupgrade --valid-tag --create-backup - 2>/dev/null")
	end

	luci.http.header(
		'Content-Disposition', 'attachment; filename="backup-%s.nr"' %{
			os.date("%Y-%m-%d")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
	if is_quectel then
		fs.unlink("/tmp/nradio_cfg.tar.gz")
	end
end

function action_restore()
	local fs = require "nixio.fs"
	local http = require "luci.http"
	local archive_tmp = "/tmp/restore.tar.gz"
	local is_quectel = fs.access("/bin/serial_atcmd") and true or false
	local fp
	nixio.syslog("err","WEB["..client_ip.."] restore")
	if not file_deal(archive_tmp,"archive",false) then
		return nil
	end

	local upload = http.formvalue("archive")
	if upload and #upload > 0 then
		local result
		if is_quectel then
			result = os.execute("tar xzvf %q -C /etc/config >/dev/null 2>&1" % archive_tmp)
		else
			result = os.execute("sysupgrade --valid-tag --restore-backup %q 2>/dev/null" % archive_tmp)
		end

		if  result == 0  then
			luci.template.render("nradio_adv/reset", { auto=1 })
			luci.sys.reboot()
			return
		end
	end
	fs.unlink(archive_tmp)
	luci.template.render("nradio_adv/reset", { auto=-1 })
end

function file_deal(filename,input_name,new_way)
	local http = require "luci.http"
	local fs = require "nixio.fs"
	local transport_file = nil
	if new_way then
		transport_file = filename
	end
	http.setfilehandler(
		function(meta, chunk, eof)
			if not fp and meta and meta.name == input_name then
				fp = io.open(filename, "w")
			end
			if fp and chunk then
				fp:write(chunk)
			end
			if fp and eof then
				fp:close()
			end
		end,transport_file
	)
	if not luci.dispatcher.test_post_security() then
		fs.unlink(filename)
		return nil
	end
	return true
end

function usock()
	local nixio = require "nixio"
	local nr = require "luci.nradio"
	local socket = nixio.socket("unix", "stream")
	local one = 1

	if not socket then
		nr.syslog("err", "create socket failed")
		return nil
	end

	-- TODO: fcntl set FD_CLOEXEC
	if not socket:setopt("socket", "reuseaddr", one) then
		nr.syslog("err", "setopt failed")
		return nil
	end

	if not socket:connect("/tmp/ota.unix", nil) then
		nr.syslog("err", "connect failed")
		return nil
	end

	return socket
end

function ota_write(socket)
	local nr = require "luci.nradio"
	local file = io.open("/tmp/firmware.img", "rb")
	local binary_data = file:read("*all")
	file:close()
	socket:send(binary_data)
end

local function action_quectel_ota(file_size, segment_size)
	local nr = require "luci.nradio"
	local util = require "luci.util"
	local ota_query
	local socket

	nr.syslog("info", "file size: "..file_size)

	if segment_size > 0 then
		nr.syslog("info", "ota download: size = "..file_size.." segment_size = "..segment_size)
		util.ubus("ota", "download", {url = "/tmp/ota.unix", type = 1, size = file_size, segment_size = segment_size})

		socket = usock()
		if not socket then
			return false
		end
		ota_write(socket)
		socket:close()
	end

	return true
end

local function quectel_ota_query()
	local nr = require "luci.nradio"
	local util = require "luci.util"
	local ota_query = util.ubus("ota", "query", {type = "1"})

	nr.syslog("info", "ota query response: "..ota_query.response)

	return (ota_query and ota_query.response or "failed")
end

function action_upgrade()
	local cl = require "luci.model.cloudd".init()
	local fs = require "nixio.fs"
	local os = require "os"
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local nr = require "luci.nradio"
	local keep = ""
	local dip = ""
	local device = cl.get_device(nil, "master")
	local platform = nr.get_platform()
	local image_tmp = "/tmp/firmware.img"
	local scount = device and device:get_slave_count() or 1
	local base = (scount > 1) and 2 or 1
	local force = ""
	local fp
	local fize_size = 0
	local send_size = 0
	local start = 0
	local ota
	local action
	local rst_disabled = uci:get("rst", "config", "rst_disabled") or "0"


	nixio.syslog("err","WEB["..client_ip.."] upgrade")
	if not file_deal(image_tmp,"image",1) then
		return nil
	end

	ota = http.formvalue("ota")
	action = http.formvalue("action") or ""

	nr.syslog("info", "ota: "..(ota and ota or "not found"))

	if not ota or action == "upgrade" then
		if ota then
			image_tmp = "/online/firmware.img"
		end
		if not fs.access(image_tmp) then
			luci.template.render("nradio_adv/reset", { auto=-1 })
			return
		end
		if platform ~= "quectel" then
			if os.execute("/sbin/sysupgrade -T %q &>/dev/null" %{ image_tmp }) ~= 0 then
				if not check_3rd_valid(image_tmp) then
					fs.unlink(image_tmp)
					if not ota then
						luci.template.render("nradio_adv/reset", { auto=-1 })
					else
						luci.nradio.luci_call_result({state = "failed"})
					end
					return
				else
					force = "-F"
				end
			end
			if (rst_disabled ~= "1") and (not http.formvalue("keep")) then
				keep = "-n"
				dip = uci:get("network", lan_section, "def_ipaddr")
			end

			if not ota then
				luci.template.render("nradio_adv/reset", { auto=2, dip=dip, base=base })
			else
				luci.nradio.luci_call_result({state = "upgrading"})
			end
			fork_exec("sleep 1; /sbin/sysupgrade %s %s %q" %{ force, keep, image_tmp })
		else
			if (rst_disabled ~= "1") and (not http.formvalue("keep")) then
				keep = "firstboot"
				dip = uci:get("network", lan_section, "def_ipaddr")
			else
				keep = "echo upgrade"
			end

			local image = "/etc/update/firmware.swu"
			os.execute("rm -fr "..image)
			os.execute("mkdir -p /etc/update")
			os.execute("cp -f "..image_tmp.." "..image)
	
			luci.template.render("nradio_adv/reset", { auto=2, dip=dip, base=base })
			fork_exec("sleep 1; rm -rf /tmp/luci*;%s; cpetools.sh -t 0 -c 'AT+QFOTADL=\"%s\"'" %{ keep, image })
		end
	else
		file_size = tonumber(http.formvalue("fileSize") or 0)
		send_size = tonumber(http.formvalue("sendSize") or 0)
		done = tonumber(http.formvalue("done") or 0)
		if ota == "quectel" then
			if not action_quectel_ota(file_size, send_size) then
				fs.unlink(image_tmp)
				luci.nradio.luci_call_result({state = "failed"})
			end
			fs.unlink(image_tmp)
			if send_size > 0 then
				local state = quectel_ota_query()
				if state == "success" then
					if (rst_disabled == "0") and (http.formvalue("keep")) then
						os.execute("tar czvf /NVM/oem_data/sysupgrade.tar.gz -C /etc/config . >/dev/null 2>&1")
					end
				elseif state == "failed" then
					os.execute("/etc/init.d/ledctrl start")
				end
				luci.nradio.luci_call_result({state = state})
			else
				os.execute("/etc/init.d/ledctrl stop")
				os.execute(". /etc/diag.sh;set_state upgrade")
				luci.nradio.luci_call_result({state = "starting"})
			end
		elseif ota == "tdtech" then
			if file_size > 0 and send_size == 0 then
				local util = require "luci.util"
				local free = util.exec("df|grep online|awk '{print $4}'") or 0
				if nr.with_battery() then
					local power = util.ubus("atserver", "get", {mod = "power"})
					if power and power.data and tonumber(power.data.power) < 50 then
						return luci.nradio.luci_call_result({state = "low battery"})
					end
				end
				if file_size > tonumber(free) * 1024 * 0.9 then
					os.execute("/sbin/cleanonline")
					return luci.nradio.luci_call_result({state = "low space"})
				end
			end
			if send_size == 0 then
				os.execute("rm -f /online/firmware.img")
			end
			local file = io.open(image_tmp, "rb")
			local data
			if file then
				data = file:read("*all")
				file:close()
				file = io.open("/online/firmware.img", "ab")
				file:write(data)
				file:close()
				fs.unlink(image_tmp)
			end
			if done == 1 then
				luci.nradio.luci_call_result({state = "upload done"})
			else
				luci.nradio.luci_call_result({state = "uploading"})
			end
		end
	end
end

function action_upgrade_3rd_party()
	local http = require "luci.http"
	local uci = require "luci.model.uci".cursor()
	local nr = require "luci.nradio"
	local dip = ""
	local image_tmp = "/tmp/firmware.img"

	nixio.syslog("err","WEB["..client_ip.."] upgrade third party")
	if not file_deal(image_tmp,"image_3rd_party",1) then
		return nil
	end

	dip = uci:get("network", lan_section, "def_ipaddr")

	if os.execute("sleep 1; /usr/bin/sysupgrade-opensource -f %q >/dev/null" %{ image_tmp }) == 0 then
		luci.template.render("nradio_adv/reset", { auto=3, dip=dip, base=1 })
	else
		luci.template.render("nradio_adv/reset", { auto=-1, dip=dip, base=1 })
	end
end

function action_remote_check()
	local capi = require "cloudd.api"
	nixio.syslog("err","WEB["..client_ip.."] remote check")
	return capi.cloudd_check_firmware()
end

function action_remote_info()
	local util = require "luci.util"
	local info = util.ubus("cloudd", "info") or {}
	local nr = require "luci.nradio"
	
	if info.state == 3 or info.state == 4 then
		local path = "/tmp/filexmit/"
		local platform = nr.get_platform()
		if platform == "tdtech" then
			path = "/online/filexmit/"
		end
		local image = path.."firmware.img"
		local line = util.exec("ls -all "..image)
		local bytes = line:match("%S+%s+%S+%s+%S+%s+%S+%s+(%S+)%s+%S+%s+%S+%s+%S+%s+%S+%s+")
		info.size = bytes
	end
	luci.nradio.luci_call_result(info)
end

function action_remote_infosize()
	local fs = require "nixio.fs"
	local util = require "luci.util"
	local info = util.ubus("cloudd", "info") or {}
	local nr = require "luci.nradio"
	local result = {code=-1,size=0}
	if info.url then
		result.code = 0
		local fw_url = info.url
		if not fs.access("/usr/bin/curl") then
			if fs.access("/etc/ssl/certs/ca-certificates.crt") then
				result.size = util.exec("wget --ca-certificate=/etc/ssl/certs/ca-certificates.crt -S --spider  "..fw_url.."2>&1 | grep -i \"Content-Length\" | cut -d' ' -f4|xargs -r printf")
			else
				result.size = util.exec("wget --no-check-certificate  "..fw_url.."2>&1 | grep -i \"Content-Length\" | cut -d' ' -f4|xargs -r printf")
			end			
		else			
			if fs.access("/etc/ssl/certs/ca-certificates.crt") then
				result.size = util.exec("curl --cacert /etc/ssl/certs/ca-certificates.crt -sI "..fw_url.." | grep -i \"Content-Length\" | awk '{print $2}'|xargs -r printf")
			else
				result.size = util.exec("curl -sI "..fw_url.." | grep -i \"Content-Length\" | awk '{print $2}'|xargs -r printf")
			end
		end
	end
	luci.nradio.luci_call_result(result)
end


function action_remote_download()
	local util = require "luci.util"
	local info = util.ubus("cloudd", "info") or {}
	local capi = require "cloudd.api"

	if info.state == 0 and info.code == 0 then
		fork_call(capi.cloudd_remote_download)
	end

	luci.nradio.syslog("err", "return")
	luci.nradio.luci_call_result(info)
end


function action_remote_upgrade_async()
	local cl = require "luci.model.cloudd".init()
	local capi = require "cloudd.api"
	local dip = uci:get("network", lan_section, "def_ipaddr")
	local device = cl.get_device(nil, "master")
	local scount = device and device:get_slave_count() or 1
	local base = (scount > 1) and 2 or 1
	local util = require "luci.util"
	local info = util.ubus("cloudd", "info") or {}

	if info.state == 4 then
		fork_call(capi.cloudd_remote_upgrade)
		luci.nradio.luci_call_result({code=0,dip=dip})
	else
		luci.nradio.luci_call_result({code=-1})
	end
end

function action_remote_upgrade()
	local cl = require "luci.model.cloudd".init()
	local capi = require "cloudd.api"
	local dip = ""
	local device = cl.get_device(nil, "master")
	local scount = device and device:get_slave_count() or 1
	local base = (scount > 1) and 2 or 1
	local util = require "luci.util"
	local info = util.ubus("cloudd", "info") or {}

	if info.state == 4 then
		if luci.nradio.with_battery() then
			local power = util.ubus("atserver", "get", {mod = "power"})
			if power and power.data and tonumber(power.data.power) < 50 then
				return template.render("nradio_adv/reset", { auto=-2})
			end
		end
		luci.template.render("nradio_adv/reset", { auto=2, dip=dip, base=base })
		fork_call(capi.cloudd_remote_upgrade)
	else
		luci.template.render("nradio_adv/reset")
	end
end

function action_switch_system()
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local dip = uci:get("network", lan_section, "def_ipaddr")
	local result = util.exec("cat /proc/mtd|grep ubi_2nd")

	nixio.syslog("err","WEB["..client_ip.."] switch system")
	luci.template.render("nradio_adv/reset", {auto=1, dip=dip})

	if result ~= "" then
		fork_exec("touch /mnt/app_data/boot_2nd_flag && cpetools.sh -d && sleep 1 && reboot")
	else
		fork_exec("ubenv -s boot_system -v 1 && cpetools.sh -d && sleep 1 && reboot")
	end
end
