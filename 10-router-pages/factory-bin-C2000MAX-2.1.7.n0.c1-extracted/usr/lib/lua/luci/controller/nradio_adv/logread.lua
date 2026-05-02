-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.logread", package.seeall)

function index()
	page = entry({"nradioadv", "system", "logread"}, cbi("nradio_adv/syslog", {hideapplybtn = true, hidesavebtn = true, hideresetbtn = true}), _("System Log"), 40, true)
	page.icon = 'nradio-logread'
	page.show = true

	entry({"nradioadv", "system", "logread", "download"}, call("action_logdown"), nil, nil, true)
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

function action_logdown()
	local uci = require "luci.model.uci".cursor()
	local fs = require "nixio.fs"
	local nr = require "luci.nradio"
	local reader
	local client_ip = luci.http.getenv("REMOTE_ADDR") or ""
	local platform = nr.get_platform()
	local logfile = "messages*"

	nixio.syslog("err","WEB["..client_ip.."] log download")

	if platform == "tdtech" then
		os.execute("logread > /var/log/system.log")
		os.execute("cd /var/log && tar -czf /tmp/log.tar.gz *.log -C /var/log >/dev/null 2>&1")
	else
		if not fs.access("/var/log/messages") and not fs.access("/var/log/message") then
			os.execute("logread > /var/log/system.log")
			logfile=""
		elseif not fs.access("/var/log/messages") then
			logfile = "message*"		
		end
		os.execute("cd /var/log && tar -czf /tmp/log.tar.gz *.log* "..logfile.." >/dev/null 2>&1")
	end
	reader = ltn12_popen("cat /tmp/log.tar.gz")

	luci.http.header(
		'Content-Disposition', 'attachment; filename="log-%s.tar.gz"' %{
			os.date("%Y-%m-%d")
		})

	luci.http.prepare_content("application/x-targz")
	luci.ltn12.pump.all(reader, luci.http.write)
	fs.unlink("/tmp/log.tar.gz")
end
