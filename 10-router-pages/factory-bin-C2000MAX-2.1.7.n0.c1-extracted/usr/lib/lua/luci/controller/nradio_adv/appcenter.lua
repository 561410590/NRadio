module("luci.controller.nradio_adv.appcenter", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/appcenter") then
		return
	end

	page = entry({"nradioadv", "system", "appcenter"}, template("nradio_appcenter/appcenter"), _("AppCenterTitle"), 90, true)
	entry({"nradioadv", "system","appcenter", "list"}, call("action_app_list"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "install"}, call("action_app_install"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "uninstall"}, call("action_app_uninstall"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "close"}, call("action_app_close"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "open"}, call("action_app_open"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "update"}, call("action_app_update"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "check"}, call("action_app_check"), nil, nil, true).leaf = true
	entry({"nradioadv", "system","appcenter", "check_size"}, call("check_size"), nil, nil, true).leaf = true
	entry({"nradioadv", "system", "appcenter", "import"}, call("action_import"), nil, nil, true).leaf = true
	entry({"nradioadv", "system", "appcenter", "import_status"}, call("action_import_status"), nil, nil, true).leaf = true
	entry({"nradioadv", "system", "appcenter", "appstore"}, call("action_appstore"), nil, nil, true).leaf = true
	entry({"nradioadv", "system", "appcenter", "check_appstore"}, call("action_appstore_check"), nil, nil, true).leaf = true
	entry({"nradioadv", "system", "appcenter", "memory"}, call("action_get_memory"), nil, nil, true).leaf = true
	page.show = true
	page.icon = 'nradio-appcenter'
end

function action_app_list_data()
	local util = require "luci.util"
	local applist = util.ubus("appcenter", "list") or {parameter={applist={}}}
	return applist.parameter
end

function action_app_list()
	luci.nradio.luci_call_result(action_app_list_data())
end
local lng  = require "luci.i18n"

local appstore_code = {
	APPSTORE_OK=0,
	APPSTORE_ERROR_DATA=1,
	APPSTORE_ERROR_URL=2,
	APPSTORE_ERROR_MD5=3,
	APPSTORE_ERROR_SIZE=4,
	APPSTORE_ERROR_MD5_SAME=5,
	APPSTORE_ERROR_SPACE=6,
	APPSTORE_ERROR_DOWNLOAD=7,
	APPSTORE_ERROR_PLATFORM=8,
	APPSTORE_ERROR_UBUS=9,
	APPSTORE_ERROR_TIMEOUT=10,
	APPSTORE_ERROR_PACKAGE=11,
	APPSTORE_ERROR_BUSY=12,
	APPSTORE_PREPARE = 13,
	APPSTORE_WAIT = 14
}
local appstore_msg = {
	{msg=lng.translate("APPDealOK")},
	{msg=lng.translate("APPstoreErrorData")},
	{msg=lng.translate("APPstoreErrorURL")},
	{msg=lng.translate("APPstoreErrorMD5")},
	{msg=lng.translate("APPstoreErrorSize")},
	{msg=lng.translate("APPstoreErrorMD5Same")},
	{msg=lng.translate("APPstoreErrorSpace")},
	{msg=lng.translate("APPstoreErrorDownload")},
	{msg=lng.translate("APPstoreErrorPlatform")},
	{msg=lng.translate("APPstoreErrorUbus")},
	{msg=lng.translate("APPstoreErrorTimeout")},
	{msg=lng.translate("APPstoreErrorPackage")},
	{msg=lng.translate("APPstoreErrorBusy")},
	{msg=lng.translate("APPstoreUpdating")},
	{msg=lng.translate("APPstoreWait")}
}
local install_code = {
	APPCENTER_OK=0,
	APPCENTER_INSTALL_PREPARE=1,
	APPCENTER_REMOVE_PREPARE=2,
	APPCENTER_UPDATE_PREPARE=3,
	APPCENTER_ERROR_PARA=4,
	APPCENTER_ERROR_UBUS=5,
	APPCENTER_ERROR_MD5=6,
	APPCENTER_ERROR_PLATFORM=7,
	APPCENTER_ERROR_SPACE=8,
	APPCENTER_ERROR_NOTEXSIT=9,
	APPCENTER_ERROR_INSTALLED=10,
	APPCENTER_ERROR_REMOVED=11,
	APPCENTER_ERROR_DOWNLOAD=12,
	APPCENTER_ERROR_INSTALL=13,
	APPCENTER_ERROR_PACKAGE=14,
}
local install_msg = {
	{msg=lng.translate("APPDealOK")},
	{msg=lng.translate("APPDealInstalling")},
	{msg=lng.translate("APPDealRemoving")},
	{msg=lng.translate("APPDealUpdating")},
	{msg=lng.translate("APPDealErrorPARA")},
	{msg=lng.translate("APPDealErrorUbus")},
	{msg=lng.translate("APPDealErrorMD5")},
	{msg=lng.translate("APPDealErrorPlatform")},
	{msg=lng.translate("APPDealErrorSpace")},
	{msg=lng.translate("APPDealErrorExsit")},
	{msg=lng.translate("APPDealErrorInstalled")},
	{msg=lng.translate("APPDealErrorRemoved")},
	{msg=lng.translate("APPDealErrorDownload")},
	{msg=lng.translate("APPDealErrorInstall")},
	{msg=lng.translate("APPDealErrorPackage")},
}

local function get_overlay_free_memory()
    local util = require "luci.util"
    local cmd = [[ df | grep 'overlayfs:/overlay' | awk '{print$4}' ]]
    local exit, out = pcall(util.exec, cmd)
    if exit and out and #out > 0 then
        local kib = tonumber(out) or 0
        return kib * 1024
    end
    return 0
end

local function get_app_required_bytes(name)
    local util = require "luci.util"

	local bytes = 0
    local data = util.ubus("appcenter", "list") or { parameter = { applist = {} } }
    local plist = (data.parameter and data.parameter.applist) or {}

    for _, items in pairs(plist) do
        if items["name"] == name then
            if items["list"] and type(items["list"]) == "table" then
                for _, apps in pairs(items["list"]) do
                    local size = tonumber(apps["size"]) or 0
                    bytes = bytes + size
                end
            else
                bytes = tonumber(items["size"]) or 0
            end
            break
        end 
    end
    return bytes
end
--[
-- code 0 操作成功
-- code 1 安装中
-- code 2 卸载中
-- code 3 升级中
-- code 4 传参错误
-- code 5 ubus错误
-- code 6 包md5校验错误
-- code 7 平台校验错误
-- code 8 空间不足
-- code 9 app不存在
-- code 10 app已安装
-- code 11 app已卸载
-- code 12 包下载异常
-- code 13 包安装
-- code 14 包异常
--]

local operation_msg = {
	['install'] = lng.translate("APPInstallOK"),
	['uninstall'] = lng.translate("APPUninstallOK"),
	['update'] = lng.translate("APPUpdateOK"),
}

function action_app_core(name,action)
	local util = require "luci.util"

	local return_code = {code=install_code.APPCENTER_ERROR_PARA}
	if name and #name > 0 then
		nixio.syslog("err","appcenter "..action.." "..name)
		return_code = util.ubus("appcenter",action,{name=name}) or { code=install_code.APPCENTER_ERROR_UBUS }
		if not return_code.code then
			return_code.code = install_code.APPCENTER_ERROR_UBUS
		end
	end
	if return_code.code >=0 and return_code.code < #install_msg then
		if return_code.code == 0 then
			return_code.msg = operation_msg[action]
		else
			return_code.msg = install_msg[return_code.code+1].msg
		end
	end
	luci.nradio.luci_call_result(return_code)
end

function action_app_install()
	local http = require "luci.http"
	local name = http.formvalue("name")
    if name and #name > 0 then
        local free_memory = get_overlay_free_memory()
        local need_bytes = get_app_required_bytes(name)
        if free_memory <= 0 or need_bytes <= 0 then
            action_app_core(name,"install")
            return
        end
        if need_bytes > free_memory then
            luci.nradio.luci_call_result({
				code = install_code.APPCENTER_ERROR_SPACE,
				msg = install_msg[install_code.APPCENTER_ERROR_SPACE+1].msg
			})
            return
        end
    end
    action_app_core(name,"install")
end

function action_app_uninstall()
	local http = require "luci.http"
	local name = http.formvalue("name")
	action_app_core(name,"uninstall")
end

function action_app_open()
	local http = require "luci.http"
	local name = http.formvalue("name")
	action_app_core(name,"open")
end
function action_app_close()
	local http = require "luci.http"
	local name = http.formvalue("name")
	action_app_core(name,"close")
end

function action_app_update()
	local http = require "luci.http"
	local name = http.formvalue("name")
	action_app_core(name,"update")
end
function action_appstore()
	local util = require "luci.util"
	local return_code = {code=appstore_code.APPstoreErrorUbus}
	local cur_platform = util.exec("grep 'DISTRIB_ARCH' /etc/openwrt_release|xargs printf") or ""
	cur_platform = cur_platform:match("%C+=(%C+)")

	nixio.syslog("err","appstore check version["..cur_platform.."]")
	return_code = util.ubus("appcenter","appstore",{platform=cur_platform}) or { code=appstore_code.APPstoreErrorUbus }
	if not return_code.code then
		return_code.code = appstore_code.APPstoreErrorUbus
	end

	if return_code.code >=0 and return_code.code < #appstore_msg then
		return_code.msg = appstore_msg[return_code.code+1].msg
	end
	luci.nradio.luci_call_result(return_code)
end

function action_app_check()
	local http = require "luci.http"
	local fs = require "nixio.fs"
	local cjson = require "cjson"
	local return_code = {code=install_code.APPCENTER_ERROR_UBUS,msg=install_msg[install_code.APPCENTER_ERROR_UBUS+1].msg}
	local cache_file = "/tmp/infocd/cache/appcenter"
	local name = http.formvalue("name")
	local action = http.formvalue("action")
	local exsit = false
	if fs.access(cache_file) then
		local app_data = fs.readfile(cache_file)
		local app_json =  cjson.decode(app_data)
		if app_json and app_json.parameter and app_json.parameter.applist then
			for i,v in pairs(app_json.parameter.applist) do
				if v["name"] == name then
					exsit = true
					return_code.code = v["action_status"]
					return_code.msg = install_msg[return_code.code+1].msg

					if (return_code.code ~= install_code.APPCENTER_OK )
						and (return_code.code ~= install_code.APPCENTER_INSTALL_PREPARE)
						and (return_code.code ~= install_code.APPCENTER_REMOVE_PREPARE)
						and (return_code.code ~= install_code.APPCENTER_UPDATE_PREPARE)
					then
						for j,sub in pairs(v["list"]) do
							if sub["file_name"] then
								return_code.file_name = sub["file_name"]
							end
							if sub["action_status"] == install_code.APPCENTER_ERROR_PACKAGE then
								return_code.errro_detail = sub["errro_detail"]
								break
							end
						end
					elseif return_code.code == 0 then
						return_code.msg = operation_msg[action]
					end
					break
				end
			end
			if not exsit then
				return_code.code = install_code.APPCENTER_OK
				return_code.msg = operation_msg[action]
			end
		end
	end
	luci.nradio.luci_call_result(return_code)
end

function action_appstore_check()
	local http = require "luci.http"
	local fs = require "nixio.fs"
	local cjson = require "cjson"
	local return_code = {code=appstore_code.APPSTORE_ERROR_UBUS,msg=appstore_msg[appstore_code.APPSTORE_ERROR_UBUS+1].msg}
	local cache_file = "/tmp/infocd/cache/appcenter"
	if fs.access(cache_file) then
		local app_data = fs.readfile(cache_file)
		local app_json =  cjson.decode(app_data)
		if app_json and app_json.parameter and app_json.parameter.appstore_code then
			if app_json.parameter.appstore_code then
				return_code.code = app_json.parameter.appstore_code
				return_code.msg = appstore_msg[return_code.code+1].msg
			end
		end
	end
	luci.nradio.luci_call_result(return_code)
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

function file_deal(input_name)
	local http = require "luci.http"
	local fs = require "nixio.fs"
	local filename = ""
	http.setfilehandler(
		function(meta, chunk, eof)
			if not fp and meta and meta.name == input_name then
				filename = "/tmp/"..meta.file:gsub("[%(%)%[%] '&;]", "")
				fp = io.open(filename, "w")
			end
			if fp and chunk then
				fp:write(chunk)
			end
			if fp and eof then
				fp:close()
			end
		end
	)
	if not luci.dispatcher.test_post_security() then
		if #filename > 0 then
			fs.unlink(filename)
		end
		return nil,""
	end
	return true,filename
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
function action_import_status()
	local util = require "luci.util"
	local http = require "luci.http"
	local fs = require "nixio.fs"
	local filename = http.formvalue("filename")
	local return_code = {code=install_code.APPCENTER_ERROR_PARA}

	if not filename or not fs.access(filename) then
		return 
	end
	nixio.syslog("err","appcenter install import file "..filename)
	return_code = util.ubus("appcenter","local",{file=filename}) or { code=install_code.APPCENTER_ERROR_UBUS }
	
	if not return_code.code then
		return_code.code = install_code.APPCENTER_ERROR_UBUS
	end

	if return_code.code >=0 and return_code.code < #install_msg then
		if return_code.code == 0 then
			return_code.msg = operation_msg['install']
		else
			return_code.msg = install_msg[return_code.code+1].msg
		end
	end

	luci.nradio.luci_call_result(return_code)
end
function action_import()
	local util = require "luci.util"
	local result,filename = file_deal("image")
	if not result or not filename or #filename == 0 then
		luci.template.render("nradio_appcenter/appcenter",{import_result={code=1}})
		return 
	end

	nixio.syslog("err","appcenter local import "..filename)
	luci.template.render("nradio_appcenter/appcenter",{import_result={code=0,file_name=filename}})
end

function action_get_memory()
	local fs = require "nixio.fs"
	local util = require "luci.util"

	local total_memory, used_memory , tfcard = 0, 0, false

	if fs.access("/usr/lib/lua/luci/controller/nradio_adv/sd.lua") then
		tfcard = true
	end

	local cmd =[[  df | grep 'overlayfs:/overlay' | awk '{print$2}' ]]
	local exit, ret = pcall(util.exec, cmd)

	if exit and ret and #ret > 0 then
		total_memory = tonumber(ret) or 0
	end

	cmd =[[  df | grep 'overlayfs:/overlay' | awk '{print$3}' ]]
	exit, ret = pcall(util.exec, cmd)

	if exit and ret and #ret > 0 then
		used_memory = tonumber(ret) or 0
	end

	luci.nradio.luci_call_result({
		tfcard = tfcard,
		total_memory = total_memory,
		used_memory = used_memory,
	})
end
