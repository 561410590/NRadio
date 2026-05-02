-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.cpe_upgrade", package.seeall)

function index()
	local nr = require "luci.nradio"		
	local hide_flag = false
	if nr.has_cpe() then
		hide_flag = true
	end
	page = entry({"nradio", "cellular", "upgrade"}, template("nradio_adv/cpe_upgrade"), _("Cellular Upgrade"), 50, true)
	page.icon = 'retweet-alt'
	page.show = hide_flag
	
	entry({"nradio", "cellular", "upgrade", "status"}, call("query_status"), nil, nil, true)
	entry({"nradio", "cellular", "upgrade", "check_size"}, call("check_size"), nil, nil, true)
	entry({"nradio", "cellular", "upgrade", "action"}, call("action_upgrade"), nil, nil, true)
	entry({"nradio", "cellular", "upgrade", "model"}, call("get_cellular_template"), nil, nil, true).leaf = true
end
function get_cellular_template()
	luci.nradio.get_cellular_template()
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

function query_status()
	local util = require "luci.util"
	local status = util.exec("cat /tmp/run/modem_upgrade") or "unknown"

	luci.nradio.luci_call_result({status = status})
end

function check_size()
	local http = require "luci.http"
	local util = require "luci.util"
	local size = http.formvalue("size") or "0"
	local sysinfo = util.ubus("system", "info") or { }
	local filestatus=0
	local meminfo = sysinfo.memory or {
			total = 0,
			free = 0,
			buffered = 0,
			shared = 0
	}
	local free_left = tonumber(meminfo.free)
	
	if free_left*0.8 > tonumber(size) then
		filestatus=1
	end

	luci.nradio.luci_call_result({filestatus = filestatus})
end

local function action_local_upgrade(upgrade_mode)
	local image_tmp = "/tmp/modem.img"

	if not file_deal(image_tmp,"image",1) then
		return nil
	end

	fork_exec("sleep 1; /usr/bin/modem_upgrade -m 0 -f %s" % {image_tmp})
	luci.template.render("nradio_adv/cpe_upgrade", {upgrade_mode=upgrade_mode,action=2})
end

local function action_ftp_upgrade(upgrade_mode)
	local http = require "luci.http"
	local nr = require "luci.nradio"
	local fs = require "nixio.fs"
	local url = http.formvalue("ftpurl") or ""
	local usr = http.formvalue("ftpusr") or ""
	local pwd = http.formvalue("ftppwd") or ""
	local dir = http.formvalue("ftpdir") or ""
	url = url:gsub("[;'\\\"]", "")
	usr = usr:gsub("[;'\\\"]", "")
	pwd = pwd:gsub("[;'\\\"]", "")
	dir = dir:gsub("[;'\\\"]", "")
	if url == "" or usr == "" or pwd == "" or dir == "" then
		os.execute("echo -n 'empty params' > /tmp/run/modem_upgrade")
		luci.template.render("nradio_adv/cpe_upgrade", {upgrade_mode=upgrade_mode,action=2, ftpurl=url, ftpusr=usr, ftppwd=pwd, ftpdir=dir})
		return
	end

	local image_tmp = "/tmp/tool_image.tar.gz"
	file_deal(image_tmp,"tool_image",1)
	if fs.access(image_tmp) then
		fork_exec("sleep 1; /usr/bin/modem_upgrade -m 1 -U '%s' -u '%s' -p '%s' -f '%s' -t %s" % {url, usr, pwd, dir,image_tmp})
	else
		fork_exec("sleep 1; /usr/bin/modem_upgrade -m 1 -U '%s' -u '%s' -p '%s' -f '%s'" % {url, usr, pwd, dir})
	end
	luci.template.render("nradio_adv/cpe_upgrade", {upgrade_mode=upgrade_mode,action=2, ftpurl=url, ftpusr=usr, ftppwd=pwd, ftpdir=dir})
end

function action_upgrade()
	local nr = require "luci.nradio"
	local http = require "luci.http"
	local util = require "luci.util"
	local fs = require "nixio.fs"

	local upgrade_mode = http.formvalue("upgrade_mode") or "1"
	if fs.access("/tmp/run/modem_upgrade") then
		util.exec("rm /tmp/run/modem_upgrade")
	end
	if fs.access("/tmp/run/modem_upgrade.log") then
		util.exec("rm /tmp/run/modem_upgrade.log")
	end
	if upgrade_mode == "0" then
		return action_local_upgrade(upgrade_mode)
	else
		return action_ftp_upgrade(upgrade_mode)
	end
end
